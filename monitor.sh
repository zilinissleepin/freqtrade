#!/bin/bash

LOG_FILE="/home/zilin/freqtrade/user_data/logs/freqtrade_production.log"
TELEGRAM_BOT_TOKEN="6124545364:AAFIKAOm-LVW0ZBN8uFXp4Ygs1-VKinwSfI"
TELEGRAM_CHAT_ID="-4187100419"

# 检查最后一次写入日志的时间
LAST_LOG_TIME=$(stat -c %Y "$LOG_FILE")
CURRENT_TIME=$(date +%s)
DIFF=$((CURRENT_TIME - LAST_LOG_TIME))

# 如果超过10分钟没有新日志，发送告警
if [ $DIFF -gt 600 ]; then
    MESSAGE="⚠️ FreqTrade 可能已停止运行！最后日志时间：$((DIFF/60))分钟前"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="${MESSAGE}"

    # 尝试重启服务
    # sudo systemctl restart freqtrade
fi