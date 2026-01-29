# 版本 2.0.17+63 发布记录

**发布时间**: 2026-01-29 11:04
**发布状态**: ✅ 成功

## 📦 版本信息

- **版本号**: 2.0.17+63
- **APK大小**: 163.9 MB (171,868,884 bytes)
- **MD5**: 04a2eb712e2bddc4735147a1009dc892

## 🎯 更新内容

1. **修复版本显示问题**
   - 问题：应用内显示的版本号不正确（显示2.0.13而实际是2.0.16）
   - 原因：APK在build_info.dart更新之前构建
   - 解决：确保先更新build_info.dart再构建APK

2. **优化格式检测页面**
   - 移除硬编码的假数据预览
   - 集成WechatBillParser和AlipayBillParser
   - 显示真实的账单预览数据

3. **优化去重检测页面**
   - 使用专业的账单解析器代替简单CSV解析
   - 支持微信/支付宝账单的复杂格式
   - 显示真实的交易记录数量和去重结果

## 🚀 发布详情

### 服务器2 (主服务器) - 39.105.12.124
- ✅ 版本创建成功
- ✅ APK上传成功
- ✅ 版本发布成功
- ✅ 下载URL已修复为公网地址

### 下载URL
```
https://39.105.12.124/ai-bookkeeping/app-releases/android/2.0.17/app-release-63.apk
```

### API测试结果
```bash
curl "https://39.105.12.124/api/v1/app-upgrade/check?version_name=2.0.16&version_code=62&platform=android"

# 响应：
{
    "has_update": true,
    "is_force_update": false,
    "latest_version": {
        "version_name": "2.0.17",
        "version_code": 63,
        "download_url": "https://39.105.12.124/ai-bookkeeping/app-releases/android/2.0.17/app-release-63.apk?..."
    }
}
```

## 🔧 修复的技术问题

### 1. MinIO下载URL问题
**问题**: 生成的file_url指向127.0.0.1，客户端无法访问

**修复**:
```sql
UPDATE app_versions 
SET file_url = REPLACE(file_url, 'http://127.0.0.1:9000/', 'https://39.105.12.124/')
WHERE version_code = 63;
```

**长期方案**: 需要修改代码在生成URL时使用公网地址

### 2. 版本号显示问题
**问题**: BuildInfo在APK构建后更新，导致编译的代码还是旧版本

**修复**: 发布脚本现在会先更新build_info.dart，再构建APK

## 📱 测试建议

### 用户测试步骤
1. 在手机上打开应用（版本2.0.16）
2. 进入"设置" → "关于" → "检查更新"
3. 应该检测到新版本2.0.17
4. 点击"立即更新"下载并安装
5. 验证功能：
   - 格式检测页面显示真实数据
   - 去重检测页面显示实际交易数量

## 📊 相关提交

- `53cfbe3` - chore: 发布版本 2.0.17+63
- `6b71d7f` - docs: MinIO APK下载URL修复记录
- `657bee1` - chore: 发布版本 2.0.16+62
- `e74de95` - fix: 修复格式检测和去重检测页面的假数据问题

## 🔗 相关文档

- [MinIO URL修复记录](minio_url_fix.md)
- [备份功能完整修复记录](备份功能完整修复记录.md)

