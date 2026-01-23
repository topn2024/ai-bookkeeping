#!/bin/bash

# 参数化语音导航测试日志监控脚本
# 用于实时查看应用日志，帮助调试

DEVICE_ID="PQYGK21318000143"
PACKAGE_NAME="com.example.ai_bookkeeping"

echo "=========================================="
echo "参数化语音导航 - 日志监控"
echo "=========================================="
echo "设备: $DEVICE_ID"
echo "包名: $PACKAGE_NAME"
echo "=========================================="
echo ""
echo "开始监控日志..."
echo "按 Ctrl+C 停止"
echo ""

# 清除旧日志
adb -s $DEVICE_ID logcat -c

# 监控关键日志
adb -s $DEVICE_ID logcat | grep -E \
  "SmartIntentRecognizer|BookkeepingOperationAdapter|VoiceCoordinator|VoiceNavigationExecutor|IntelligenceEngine" \
  --color=always
