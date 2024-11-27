#!/bin/sh

# Telegram 通知配置
TELEGRAM_URL="https://your_server_ip/notify"

# 保存流量数据的文件
TRAFFIC_FILE="/var/tmp/network_traffic.dat"
CURRENT_MONTH=$(date +"%Y-%m")
SHUTDOWN_THRESHOLD=$((19 * 1024 * 1024 * 1024))  # 20GB 转换为字节
WARN_THRESHOLD_18GB=$((18 * 1024 * 1024 * 1024))  # 18GB 转换为字节
WARN_THRESHOLD_15GB=$((15 * 1024 * 1024 * 1024))  # 15GB 转换为字节

# 自动检测活跃的非回环、非Docker网络接口
INTERFACES=$(ls /sys/class/net | grep -vE "(lo|docker)")

# 如果流量文件不存在或月份不同，初始化流量文件
if [ ! -f $TRAFFIC_FILE ] || ! grep -q "$CURRENT_MONTH" $TRAFFIC_FILE; then
    initial_in=0
    initial_out=0

    # 获取当前各接口的进出流量数据
    for INTERFACE in $INTERFACES; do
        in_bytes=$(awk -v iface="$INTERFACE" '$1 ~ iface":" {print $2}' /proc/net/dev)
        out_bytes=$(awk -v iface="$INTERFACE" '$1 ~ iface":" {print $10}' /proc/net/dev)
        initial_in=$((initial_in + in_bytes))
        initial_out=$((initial_out + out_bytes))
    done

    # 初始化流量文件
    echo "$CURRENT_MONTH $initial_in $initial_out $initial_in $initial_out 0 0" > $TRAFFIC_FILE
fi

# 从流量文件读取数据
read saved_month saved_initial_in saved_initial_out saved_last_in saved_last_out monthly_in monthly_out < $TRAFFIC_FILE

# 获取当前流量
current_total_in=0
current_total_out=0

for INTERFACE in $INTERFACES; do
    in_bytes=$(awk -v iface="$INTERFACE" '$1 ~ iface":" {print $2}' /proc/net/dev)
    out_bytes=$(awk -v iface="$INTERFACE" '$1 ~ iface":" {print $10}' /proc/net/dev)
    current_total_in=$((current_total_in + in_bytes))
    current_total_out=$((current_total_out + out_bytes))
done

# 计算本月已用流量
if [ "$saved_month" = "$CURRENT_MONTH" ]; then
    delta_in=$((current_total_in - saved_last_in))
    delta_out=$((current_total_out - saved_last_out))

    monthly_in=$((monthly_in + delta_in))
    monthly_out=$((monthly_out + delta_out))
else
    monthly_in=$((current_total_in - saved_initial_in))
    monthly_out=$((current_total_out - saved_initial_out))
fi

# 根据不同的单位格式化流量
format_bytes() {
    local bytes=$1
    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes}B"
    elif [ "$bytes" -lt $((1024 * 1024)) ]; then
        printf "%.2fKB" "$(awk "BEGIN { print $bytes / 1024 }")"
    elif [ "$bytes" -lt $((1024 * 1024 * 1024)) ]; then
        printf "%.2fMB" "$(awk "BEGIN { print $bytes / (1024 * 1024) }")"
    else
        printf "%.2fGB" "$(awk "BEGIN { print $bytes / (1024 * 1024 * 1024) }")"
    fi
}

# 格式化后的流量
monthly_in_formatted=$(format_bytes $monthly_in)
monthly_out_formatted=$(format_bytes $monthly_out)

# 通知逻辑和关机
send_telegram_message() {
    local message="$1"
    curl -s -X POST "$TELEGRAM_URL" -H "Content-Type: application/json" -d "{\"message\":\"$message\"}"
}

if [ "$monthly_out" -ge "$SHUTDOWN_THRESHOLD" ]; then
    TELEGRAM_MSG="总出站流量已达到19GB, 系统即将关机...\n入站流量: $monthly_in_formatted\n出站流量: $monthly_out_formatted"
    send_telegram_message "$TELEGRAM_MSG"
    sudo shutdown -h now
elif [ "$monthly_out" -ge "$WARN_THRESHOLD_18GB" ]; then
    TELEGRAM_MSG="警告: 总出站流量已达到18GB\n入站流量: $monthly_in_formatted\n出站流量: $monthly_out_formatted"
    send_telegram_message "$TELEGRAM_MSG"
elif [ "$monthly_out" -ge "$WARN_THRESHOLD_15GB" ]; then
    TELEGRAM_MSG="注意: 总出站流量已达到15GB\n入站流量: $monthly_in_formatted\n出站流量: $monthly_out_formatted"
    send_telegram_message "$TELEGRAM_MSG"
fi

# 输出流量信息
echo "本月入站流量: $monthly_in_formatted"
echo "本月出站流量: $monthly_out_formatted"

# 更新流量数据文件
echo "$CURRENT_MONTH $saved_initial_in $saved_initial_out $current_total_in $current_total_out $monthly_in $monthly_out" > $TRAFFIC_FILE


# 检查并设置cron任务
# 定义脚本路径
SCRIPT_PATH="$(realpath "$0")"
CRON_CMD="*/5 * * * * $SCRIPT_PATH"
(crontab -l | grep -F "$CRON_CMD") || {
    (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
    if [ $? -ne 0 ]; then
        echo "无法添加定时任务：请以root用户或管理员权限运行此脚本。" >&2
    fi
}

echo "------------------------------"
