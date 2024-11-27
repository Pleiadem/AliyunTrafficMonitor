# AliyunTrafficMonitor

AliyunTrafficMonitor 是一个用于监控服务器网络流量的 Shell 脚本。当出站流量达到指定阈值时，它会通过 Telegram 发送通知，并在达到最大阈值时自动关机。

根据阿里云官方规则，CDT每月的免费的出站流量为200G，其中20G可用于国内。入站流量不限制。

本项目由[aliyun_traffic.sh](https://github.com/csznet/public-script)分叉而来，修复了流量统计不太准的问题，并且使用了[tg代理](https://github.com/Pleiadem/tg_proxy)，让国内服务器可以发送tg机器人信息。

## 功能

- 自动检测活跃的网络接口（排除本地回环和 Docker 接口）。
- 记录并累计流量数据以便每月重置。
- 通过 Telegram 代理发送流量警告通知。
- 当流量超过最大阈值时，自动关闭系统以保护资源和避免额外费用。

注意：此脚本仅在alpine linux中测试过，其他环境自行修改测试。

## 安装

1. 克隆此仓库到您的本地主机：

   ```bash
   git clone https://github.com/Pleiadem/AliyunTrafficMonitor.git
   cd AliyunTrafficMonitor

2. 确保脚本有执行权限：
   ```bash
   chmod +x traffic_monitor.sh

3. 确保在脚本中配置了正确的 Telegram URL。

## 使用方法

1. 手动运行脚本以测试是否正确配置：

   ```bash
   ./traffic_monitor.sh
   ```

2. 脚本会自动检查 cron 作业是否存在，如不存在，它会设置一个新的定时任务，每五分钟运行一次。您可以通过以下命令检查 cron 作业：

   ```bash
   crontab -l
   ```

## 原理

- **流量数据累计**: 脚本会检查所有活跃的网络接口，通过 `/proc/net/dev` 获取当前流量数据。
- **数据存储**: 使用文件保存当前月的流量累计值，以便在每次脚本运行时能够比较并更新流量。
- **通知和关机**: 当出站流量超过警告和关机阈值时，通过 Telegram 发送通知，达到最大阈值则执行关机命令。

## 待解决问题

- **关机时的持久化问题**: 目前脚本在计划关机时未考虑抓取未完成的持久化数据。
- **接口波动处理**: 脚本假设所有接口名称不变，接口状态不影响流量监控。
- **Telegram 代理失效**: 当代理失效或 URL 变更时需手动更新配置。

## 注意事项

- **权限**: 由于脚本需要执行系统关机命令，请确保使用具有 sudo 权限的用户运行，并在 sudoers 文件中配置无需密码验证。
- **计划任务**：强烈建议在托管此服务的机器上仔细审核计划任务配置。

## 贡献

如有其他改进建议，请发起 Pull Request 或提交 Issue。

## 授权

此项目MIT许可证授权。
```

使用此模板，您可以快速在 GitHub 上发布和维护 `AliyunTrafficMonitor` 项目，同时向用户介绍项目的功能原理和潜在问题，便于后续改进和维护。您还可以在项目主页中使用 README 中的内容来增强其可读性和用户友好性。
