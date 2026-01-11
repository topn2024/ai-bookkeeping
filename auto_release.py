#!/usr/bin/env python3
"""
一键式自动发布脚本

自动完成：
1. 清理和构建APK
2. 生成增量补丁（如果有旧版本）
3. 登录管理后台
4. 创建版本记录
5. 上传APK到MinIO
6. 上传Patch到MinIO（如果有）
7. 发布版本

用法:
    python3 auto_release.py --version 2.0.3 --code 43
    python3 auto_release.py --version 2.0.3 --code 43 --previous-version 2.0.2 --previous-code 42
    python3 auto_release.py --help
"""

import argparse
import hashlib
import io
import os
import sys
import json
import subprocess
import requests
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict

# 添加颜色输出
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    END = '\033[0m'
    BOLD = '\033[1m'

def print_header(text: str):
    """打印标题"""
    print(f"\n{Colors.HEADER}{Colors.BOLD}{'=' * 60}{Colors.END}")
    print(f"{Colors.HEADER}{Colors.BOLD}{text}{Colors.END}")
    print(f"{Colors.HEADER}{Colors.BOLD}{'=' * 60}{Colors.END}\n")

def print_step(step: str, text: str):
    """打印步骤"""
    print(f"{Colors.CYAN}{Colors.BOLD}[{step}]{Colors.END} {text}")

def print_success(text: str):
    """打印成功信息"""
    print(f"{Colors.GREEN}✓ {text}{Colors.END}")

def print_error(text: str):
    """打印错误信息"""
    print(f"{Colors.RED}✗ {text}{Colors.END}")

def print_warning(text: str):
    """打印警告信息"""
    print(f"{Colors.YELLOW}⚠ {text}{Colors.END}")

def calculate_md5(file_path: str) -> str:
    """计算文件MD5"""
    md5 = hashlib.md5()
    with open(file_path, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            md5.update(chunk)
    return md5.hexdigest()

def format_size(size_bytes: int) -> str:
    """格式化文件大小"""
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.1f} MB"
    else:
        return f"{size_bytes / (1024 * 1024 * 1024):.2f} GB"

def run_command(cmd: list, cwd: str = None, shell: bool = False) -> bool:
    """运行命令"""
    try:
        if shell:
            cmd = ' '.join(cmd)
        result = subprocess.run(
            cmd,
            cwd=cwd,
            shell=shell,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        return True
    except subprocess.CalledProcessError as e:
        print_error(f"命令执行失败: {e.stderr}")
        return False

def build_apk(project_root: Path) -> Optional[Path]:
    """构建APK"""
    print_step("步骤 1/7", "构建Android APK")

    app_dir = project_root / "app"
    if not app_dir.exists():
        print_error(f"找不到app目录: {app_dir}")
        return None

    # 清理
    print("  清理之前的构建...")
    if not run_command(["flutter", "clean"], cwd=str(app_dir)):
        return None

    # 获取依赖
    print("  获取依赖...")
    if not run_command(["flutter", "pub", "get"], cwd=str(app_dir)):
        return None

    # 构建
    print("  构建release APK（这可能需要几分钟）...")
    if not run_command(["flutter", "build", "apk", "--release"], cwd=str(app_dir)):
        return None

    # 查找APK
    apk_path = app_dir / "build/app/outputs/flutter-apk/app-release.apk"
    if not apk_path.exists():
        print_error(f"找不到APK文件: {apk_path}")
        return None

    size = apk_path.stat().st_size
    print_success(f"APK构建成功: {apk_path}")
    print(f"    大小: {format_size(size)}")

    return apk_path

def generate_patch(old_apk: Path, new_apk: Path, output_dir: Path) -> Optional[Dict]:
    """生成增量补丁"""
    print_step("步骤 2/7", "生成增量补丁")

    try:
        import bsdiff4
    except ImportError:
        print_warning("bsdiff4未安装，跳过补丁生成")
        print("  提示: pip install bsdiff4")
        return None

    if not old_apk.exists():
        print_warning(f"旧版本APK不存在，跳过补丁生成: {old_apk}")
        return None

    print(f"  基础版本: {old_apk}")
    print(f"  目标版本: {new_apk}")

    try:
        with open(old_apk, 'rb') as f:
            old_data = f.read()
        with open(new_apk, 'rb') as f:
            new_data = f.read()

        patch_data = bsdiff4.diff(old_data, new_data)

        patch_path = output_dir / "update.patch"
        with open(patch_path, 'wb') as f:
            f.write(patch_data)

        patch_size = len(patch_data)
        new_size = len(new_data)
        savings = (1 - patch_size / new_size) * 100

        print_success(f"补丁生成成功: {patch_path}")
        print(f"    大小: {format_size(patch_size)} (节省 {savings:.1f}%)")

        return {
            'path': patch_path,
            'size': patch_size,
            'md5': calculate_md5(str(patch_path))
        }
    except Exception as e:
        print_error(f"补丁生成失败: {e}")
        return None

def login_admin(base_url: str, username: str, password: str) -> Optional[str]:
    """登录管理后台"""
    print_step("步骤 3/7", "登录管理后台")

    try:
        response = requests.post(
            f"{base_url}/admin/auth/login",
            json={
                "username": username,
                "password": password
            },
            timeout=30
        )

        if response.status_code == 200:
            data = response.json()
            token = data.get('access_token')
            print_success("登录成功")
            return token
        else:
            print_error(f"登录失败: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print_error(f"登录失败: {e}")
        return None

def create_version(base_url: str, token: str, version_name: str, version_code: int,
                  release_notes: str, is_force_update: bool) -> Optional[str]:
    """创建版本记录"""
    print_step("步骤 4/7", "创建版本记录")

    try:
        response = requests.post(
            f"{base_url}/admin/app-versions",
            json={
                "version_name": version_name,
                "version_code": version_code,
                "platform": "android",
                "release_notes": release_notes,
                "is_force_update": is_force_update
            },
            headers={"Authorization": f"Bearer {token}"},
            timeout=30
        )

        if response.status_code == 200:
            data = response.json()
            version_id = data.get('id')
            print_success(f"版本创建成功: {version_name}+{version_code}")
            print(f"    版本ID: {version_id}")
            return version_id
        else:
            print_error(f"版本创建失败: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print_error(f"版本创建失败: {e}")
        return None

def upload_apk(base_url: str, token: str, version_id: str, apk_path: Path) -> bool:
    """上传APK"""
    print_step("步骤 5/7", "上传APK到MinIO")

    try:
        with open(apk_path, 'rb') as f:
            files = {'file': ('app-release.apk', f, 'application/vnd.android.package-archive')}
            response = requests.post(
                f"{base_url}/admin/app-versions/{version_id}/upload-apk",
                files=files,
                headers={"Authorization": f"Bearer {token}"},
                timeout=300  # 5分钟超时
            )

        if response.status_code == 200:
            data = response.json()
            print_success("APK上传成功")
            print(f"    URL: {data.get('url')}")
            print(f"    大小: {data.get('size_formatted')}")
            print(f"    MD5: {data.get('md5')}")
            return True
        else:
            print_error(f"APK上传失败: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print_error(f"APK上传失败: {e}")
        return False

def upload_patch(base_url: str, token: str, version_id: str, patch_path: Path,
                patch_from_version: str, patch_from_code: int) -> bool:
    """上传Patch"""
    print_step("步骤 6/7", "上传增量补丁到MinIO")

    try:
        with open(patch_path, 'rb') as f:
            files = {'file': ('update.patch', f, 'application/octet-stream')}
            data = {
                'patch_from_version': patch_from_version,
                'patch_from_code': patch_from_code
            }
            response = requests.post(
                f"{base_url}/admin/app-versions/{version_id}/upload-patch",
                files=files,
                data=data,
                headers={"Authorization": f"Bearer {token}"},
                timeout=300  # 5分钟超时
            )

        if response.status_code == 200:
            data = response.json()
            print_success("补丁上传成功")
            print(f"    URL: {data.get('url')}")
            print(f"    大小: {data.get('size_formatted')}")
            print(f"    基础版本: {data.get('patch_from_version')}+{data.get('patch_from_code')}")
            return True
        else:
            print_error(f"补丁上传失败: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print_error(f"补丁上传失败: {e}")
        return False

def publish_version(base_url: str, token: str, version_id: str) -> bool:
    """发布版本"""
    print_step("步骤 7/7", "发布版本")

    try:
        response = requests.post(
            f"{base_url}/admin/app-versions/{version_id}/publish",
            headers={"Authorization": f"Bearer {token}"},
            timeout=30
        )

        if response.status_code == 200:
            data = response.json()
            print_success(f"版本发布成功: {data.get('version')}")
            print(f"    发布时间: {data.get('published_at')}")
            return True
        else:
            print_error(f"版本发布失败: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print_error(f"版本发布失败: {e}")
        return False

def load_env_file(env_path: Path) -> Dict[str, str]:
    """加载.env文件"""
    env_vars = {}
    if env_path.exists():
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    env_vars[key.strip()] = value.strip()
    return env_vars

def main():
    parser = argparse.ArgumentParser(description='一键式自动发布APK到服务器')
    parser.add_argument('--version', '-v', required=True, help='版本名称，例如：2.0.3')
    parser.add_argument('--code', '-c', type=int, required=True, help='版本号，例如：43')
    parser.add_argument('--previous-version', help='上一个版本名称（用于生成补丁），例如：2.0.2')
    parser.add_argument('--previous-code', type=int, help='上一个版本号（用于生成补丁），例如：42')
    parser.add_argument('--base-url', default='http://localhost:8000', help='服务器地址')
    parser.add_argument('--admin-user', default='admin', help='管理员用户名')
    parser.add_argument('--admin-password', help='管理员密码（不提供则提示输入）')
    parser.add_argument('--force-update', action='store_true', help='强制更新标志')
    parser.add_argument('--release-notes', help='更新说明（或文件路径）')
    parser.add_argument('--no-build', action='store_true', help='跳过构建，使用已有的APK')

    args = parser.parse_args()

    # 项目根目录
    project_root = Path(__file__).parent

    print_header("🚀 AI智能记账 - 一键式自动发布")
    print(f"版本: {args.version} (Build {args.code})")
    print(f"服务器: {args.base_url}")
    print()

    # 准备临时目录
    temp_dir = project_root / "temp_release"
    temp_dir.mkdir(exist_ok=True)

    # 1. 构建APK
    if args.no_build:
        print_step("步骤 1/7", "使用已有APK（跳过构建）")
        apk_path = project_root / "app/build/app/outputs/flutter-apk/app-release.apk"
        if not apk_path.exists():
            print_error(f"找不到APK: {apk_path}")
            sys.exit(1)
        print_success(f"使用APK: {apk_path}")
    else:
        apk_path = build_apk(project_root)
        if not apk_path:
            print_error("APK构建失败")
            sys.exit(1)

    # 2. 生成补丁（可选）
    patch_info = None
    if args.previous_version and args.previous_code:
        old_apk = project_root / "dist" / f"ai_bookkeeping_{args.previous_version}.apk"
        patch_info = generate_patch(old_apk, apk_path, temp_dir)
    else:
        print_step("步骤 2/7", "跳过补丁生成（未提供旧版本）")

    # 获取管理员密码
    admin_password = args.admin_password
    if not admin_password:
        # 尝试从环境变量读取
        import getpass
        admin_password = getpass.getpass("请输入管理员密码: ")

    # 3. 登录
    token = login_admin(args.base_url, args.admin_user, admin_password)
    if not token:
        print_error("登录失败")
        sys.exit(1)

    # 准备更新说明
    release_notes = args.release_notes or f"版本 {args.version} 更新"
    if release_notes and os.path.exists(release_notes):
        with open(release_notes, 'r', encoding='utf-8') as f:
            release_notes = f.read()

    # 4. 创建版本
    version_id = create_version(
        args.base_url, token, args.version, args.code,
        release_notes, args.force_update
    )
    if not version_id:
        print_error("版本创建失败")
        sys.exit(1)

    # 5. 上传APK
    if not upload_apk(args.base_url, token, version_id, apk_path):
        print_error("APK上传失败")
        sys.exit(1)

    # 6. 上传补丁（可选）
    if patch_info and args.previous_version and args.previous_code:
        if not upload_patch(
            args.base_url, token, version_id, patch_info['path'],
            args.previous_version, args.previous_code
        ):
            print_warning("补丁上传失败，但继续发布流程")
    else:
        print_step("步骤 6/7", "跳过补丁上传")

    # 7. 发布版本
    if not publish_version(args.base_url, token, version_id):
        print_error("版本发布失败")
        sys.exit(1)

    # 清理临时文件
    import shutil
    if temp_dir.exists():
        shutil.rmtree(temp_dir)

    print_header("✅ 发布完成！")
    print(f"版本 {args.version}+{args.code} 已成功发布")
    print()
    print("用户可以通过应用内更新功能获取新版本")
    print()

if __name__ == '__main__':
    main()
