#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
软件著作权源代码自动提取工具
自动提取前30页和后30页源代码，每页50行
"""

import os
import sys

def extract_code_pages(file_list, output_file, start_page=1, max_pages=30):
    """
    提取代码到输出文件

    Args:
        file_list: 文件路径列表
        output_file: 输出文件路径
        start_page: 起始页码
        max_pages: 最大页数
    """
    page = start_page
    lines_per_page = 50

    with open(output_file, 'w', encoding='utf-8') as out:
        for file_path in file_list:
            if page > max_pages:
                break

            if not os.path.exists(file_path):
                print(f"警告：文件不存在 {file_path}")
                continue

            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
            except Exception as e:
                print(f"错误：无法读取文件 {file_path}: {e}")
                continue

            # 按每50行一页分割
            line_index = 0
            while line_index < len(lines) and page <= max_pages:
                # 写入页头
                out.write("=" * 80 + "\n")
                out.write(f"{'第' + str(page) + '页':^78}\n")
                out.write("=" * 80 + "\n")
                out.write(f"// 文件: {file_path}\n")
                if line_index > 0:
                    out.write("// （续上页）\n")
                out.write("\n")

                # 写入代码（最多50行）
                chunk = lines[line_index:line_index + lines_per_page]
                for line in chunk:
                    out.write(line)

                # 如果不足50行，补充空行说明
                if len(chunk) < lines_per_page:
                    out.write("\n")
                    out.write(f"// 文件结束，共 {len(chunk)} 行\n")

                out.write("\n")

                line_index += lines_per_page
                page += 1

    return page

# 前30页文件列表（展示核心功能和入口）
front_files = [
    "app/lib/main.dart",
    "app/lib/services/learning/ocr_learning_service.dart",
    "app/lib/services/learning/voice_intent_learning_service.dart",
    "app/lib/services/ai_advice_service.dart",
    "app/lib/services/voice_context_service.dart",
    "app/lib/services/voice_config_service.dart",
    "app/lib/services/adaptive_budget_service.dart",
    "app/lib/services/trend_prediction_service.dart",
]

# 后30页文件列表（展示创新算法和后端实现）
back_files = [
    "app/lib/services/budget_money_age_integration.dart",
    "app/lib/services/family_offline_sync_service.dart",
    "app/lib/services/encryption_service.dart",
    "server/app/main.py",
    "server/app/core/config.py",
    "server/app/core/security.py",
    "server/app/core/database.py",
]

if __name__ == "__main__":
    print("软件著作权源代码自动提取工具")
    print("=" * 80)

    # 提取前30页
    print("\n正在提取前30页源代码...")
    front_output = "软著源代码-前30页.txt"
    try:
        final_page = extract_code_pages(front_files, front_output, 1, 30)
        print(f"✓ 前30页提取完成，共 {final_page - 1} 页")
        print(f"  输出文件: {front_output}")
    except Exception as e:
        print(f"✗ 前30页提取失败: {e}")

    # 提取后30页
    print("\n正在提取后30页源代码...")
    back_output = "软著源代码-后30页.txt"
    try:
        final_page = extract_code_pages(back_files, back_output, 1, 30)
        print(f"✓ 后30页提取完成，共 {final_page - 1} 页")
        print(f"  输出文件: {back_output}")
    except Exception as e:
        print(f"✗ 后30页提取失败: {e}")

    print("\n" + "=" * 80)
    print("提取完成！")
    print("\n请检查生成的文件：")
    print(f"  - {front_output}")
    print(f"  - {back_output}")
    print("\n注意事项：")
    print("  1. 请检查每页是否为50行代码")
    print("  2. 请检查页码标注是否正确")
    print("  3. 请检查文件路径是否完整")
    print("  4. 请删除任何敏感信息（API密钥、密码等）")
    print("  5. 如果页数不足30页，请添加更多文件到文件列表")
