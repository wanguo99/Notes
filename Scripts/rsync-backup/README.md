# rsync 备份工具使用文档

## 概述

`03-rsync.sh` 是一个生产环境级别的配置文件自动备份和恢复工具，专为嵌入式设备设计。它使用 `inotify` 实时监控文件变化，并通过 `rsync` 进行增量备份。

## 主要特性

- ✅ **实时监控**: 基于 inotify 的文件变化监控
- ✅ **增量备份**: 使用 rsync 只传输变化的部分
- ✅ **本地/远程备份**: 支持本地目录和远程 SSH 备份
- ✅ **配置文件驱动**: 无需修改脚本，通过配置文件管理
- ✅ **完善的日志**: 多级别日志、自动轮转
- ✅ **错误处理**: 完整的错误处理和信号捕获
- ✅ **防抖机制**: 避免频繁变化导致的过度同步
- ✅ **灾难恢复**: 一键从备份恢复配置
- ✅ **自动清理**: 定期清理过期备份

## 快速开始

### 1. 生成配置文件

```bash
./03-rsync.sh init
```

这将生成 `rsync-backup.conf.example` 配置模板。

### 2. 编辑配置文件

```bash
cp rsync-backup.conf.example rsync-backup.conf
vim rsync-backup.conf
```

### 3. 启动监控服务

```bash
./03-rsync.sh start
```

## 命令说明

### 基本命令

```bash
# 启动监控服务（前台运行）
./03-rsync.sh start

# 停止监控服务
./03-rsync.sh stop

# 查看服务状态
./03-rsync.sh status

# 执行一次同步（不启动监控）
./03-rsync.sh sync

# 从备份恢复配置
./03-rsync.sh restore

# 清理旧备份
./03-rsync.sh cleanup

# 生成配置文件模板
./03-rsync.sh init
```

### 使用自定义配置文件

```bash
./03-rsync.sh -c /etc/rsync-backup.conf start
```

## 配置说明

### 基本配置

```bash
# 监控目录（必需）
WATCH_DIR=/etc/config

# 备份类型: local 或 remote
BACKUP_TYPE=local
```

### 本地备份配置

```bash
BACKUP_TYPE=local
BACKUP_DIR=/backup/config
```

### 远程备份配置

```bash
BACKUP_TYPE=remote
REMOTE_USER=backup
REMOTE_HOST=192.168.1.100
REMOTE_DIR=/backup/device-config
```

**注意**: 远程备份需要配置 SSH 密钥认证：

```bash
# 在嵌入式设备上生成密钥
ssh-keygen -t rsa -b 2048 -N "" -f ~/.ssh/id_rsa

# 复制公钥到备份服务器
ssh-copy-id backup@192.168.1.100
```

### 排除模式

```bash
# 排除临时文件、日志文件等
EXCLUDE_PATTERNS=*.tmp,*.log,*.swp,.git,*.bak
```

### 日志配置

```bash
# 日志级别: DEBUG, INFO, WARN, ERROR
LOG_LEVEL=INFO

# 日志文件最大大小
MAX_LOG_SIZE=10M
```

### 同步配置

```bash
# 防抖时间（秒）- 文件变化后等待多久才执行同步
DEBOUNCE_TIME=5

# 启用压缩（1=启用，0=禁用）
ENABLE_COMPRESSION=1

# 启用校验和（1=启用，0=禁用）- 更安全但更慢
ENABLE_CHECKSUM=0

# 备份保留天数
BACKUP_RETENTION_DAYS=30
```

## 使用场景

### 场景 1: 嵌入式设备配置文件备份

**需求**: IMX6ULL 设备的 `/etc/config` 目录需要实时备份到远程服务器

**配置**:
```bash
WATCH_DIR=/etc/config
BACKUP_TYPE=remote
REMOTE_USER=backup
REMOTE_HOST=192.168.1.100
REMOTE_DIR=/backup/imx6ull-001
ENABLE_COMPRESSION=1
DEBOUNCE_TIME=10
```

**启动**:
```bash
# 前台运行（调试）
./03-rsync.sh start

# 后台运行（生产环境）
nohup ./03-rsync.sh start > /dev/null 2>&1 &
```

### 场景 2: 本地配置文件备份

**需求**: 将 `/etc/network` 配置备份到本地 SD 卡

**配置**:
```bash
WATCH_DIR=/etc/network
BACKUP_TYPE=local
BACKUP_DIR=/mnt/sdcard/backup/network
ENABLE_COMPRESSION=0
DEBOUNCE_TIME=5
```

### 场景 3: 灾难恢复

**需求**: 设备配置损坏，需要从备份恢复

**操作**:
```bash
# 1. 停止监控服务（如果正在运行）
./03-rsync.sh stop

# 2. 从备份恢复
./03-rsync.sh restore

# 3. 验证恢复结果
ls -la /etc/config

# 4. 重新启动监控
./03-rsync.sh start
```

**注意**: 恢复前会自动备份当前配置到 `.before-restore.YYYYMMDD-HHMMSS` 目录。

### 场景 4: 定期清理旧备份

**需求**: 每周清理 30 天前的备份

**配置**:
```bash
BACKUP_RETENTION_DAYS=30
```

**手动清理**:
```bash
./03-rsync.sh cleanup
```

**自动清理（cron）**:
```bash
# 每周日凌晨 2 点清理
0 2 * * 0 /path/to/03-rsync.sh cleanup >> /var/log/rsync-cleanup.log 2>&1
```

## 环境变量

可以通过环境变量覆盖默认路径：

```bash
# 配置文件路径
export CONFIG_FILE=/etc/rsync-backup.conf

# 日志文件路径
export LOG_FILE=/var/log/rsync-backup.log

# PID 文件路径
export PID_FILE=/var/run/rsync-backup.pid

# 状态目录路径
export STATE_DIR=/var/lib/rsync-backup

# 启动服务
./03-rsync.sh start
```

## 系统集成

### systemd 服务（推荐）

创建 `/etc/systemd/system/rsync-backup.service`:

```ini
[Unit]
Description=rsync Backup Service
After=network.target

[Service]
Type=simple
User=root
Environment="CONFIG_FILE=/etc/rsync-backup.conf"
ExecStart=/usr/local/bin/03-rsync.sh start
ExecStop=/usr/local/bin/03-rsync.sh stop
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

启用服务:
```bash
sudo systemctl daemon-reload
sudo systemctl enable rsync-backup
sudo systemctl start rsync-backup
sudo systemctl status rsync-backup
```

### init.d 脚本（传统系统）

创建 `/etc/init.d/rsync-backup`:

```bash
#!/bin/sh
### BEGIN INIT INFO
# Provides:          rsync-backup
# Required-Start:    $network $remote_fs
# Required-Stop:     $network $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: rsync backup service
### END INIT INFO

SCRIPT=/usr/local/bin/03-rsync.sh
CONFIG=/etc/rsync-backup.conf

case "$1" in
    start)
        $SCRIPT -c $CONFIG start
        ;;
    stop)
        $SCRIPT -c $CONFIG stop
        ;;
    status)
        $SCRIPT -c $CONFIG status
        ;;
    restart)
        $SCRIPT -c $CONFIG stop
        sleep 2
        $SCRIPT -c $CONFIG start
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac

exit 0
```

启用服务:
```bash
sudo chmod +x /etc/init.d/rsync-backup
sudo update-rc.d rsync-backup defaults
sudo service rsync-backup start
```

## 故障排查

### 问题 1: 服务无法启动

**症状**: 执行 `start` 命令后立即退出

**排查步骤**:
```bash
# 1. 检查配置文件
./03-rsync.sh -c rsync-backup.conf status

# 2. 查看日志
tail -f /var/log/rsync-backup.log

# 3. 检查依赖
which rsync inotifywait

# 4. 验证目录权限
ls -ld /etc/config /backup
```

### 问题 2: 远程备份失败

**症状**: 日志显示 "无法连接到远程主机"

**排查步骤**:
```bash
# 1. 测试 SSH 连接
ssh backup@192.168.1.100 "echo OK"

# 2. 检查 SSH 密钥
ls -la ~/.ssh/id_rsa*

# 3. 测试 rsync
rsync -av /tmp/test backup@192.168.1.100:/tmp/

# 4. 检查防火墙
sudo iptables -L -n | grep 22
```

### 问题 3: 同步频率过高

**症状**: 日志显示频繁同步，系统负载高

**解决方案**:
```bash
# 增加防抖时间
DEBOUNCE_TIME=30

# 添加排除模式
EXCLUDE_PATTERNS=*.tmp,*.log,*.swp,.git
```

### 问题 4: 日志文件过大

**症状**: 日志文件占用大量磁盘空间

**解决方案**:
```bash
# 1. 调整日志级别
LOG_LEVEL=WARN

# 2. 减小日志文件大小限制
MAX_LOG_SIZE=5M

# 3. 手动清理旧日志
rm -f /var/log/rsync-backup.log.old
```

### 问题 5: 恢复失败

**症状**: 执行 `restore` 命令后配置未恢复

**排查步骤**:
```bash
# 1. 检查备份是否存在
ls -la /backup/config

# 2. 检查目标目录权限
ls -ld /etc/config

# 3. 查看详细日志
LOG_LEVEL=DEBUG ./03-rsync.sh restore

# 4. 手动恢复
rsync -av /backup/config/ /etc/config/
```

## 性能优化

### 嵌入式设备优化

```bash
# 1. 禁用校验和（减少 CPU 使用）
ENABLE_CHECKSUM=0

# 2. 增加防抖时间（减少同步频率）
DEBOUNCE_TIME=30

# 3. 启用压缩（减少网络传输）
ENABLE_COMPRESSION=1

# 4. 排除不必要的文件
EXCLUDE_PATTERNS=*.tmp,*.log,*.swp,.git,*.bak,*.cache
```

### 网络不稳定环境

```bash
# 1. 使用本地备份作为缓冲
BACKUP_TYPE=local
BACKUP_DIR=/tmp/backup

# 2. 定期手动同步到远程
0 */6 * * * rsync -avz /tmp/backup/ backup@server:/backup/
```

## 安全建议

1. **SSH 密钥管理**
   - 使用专用的备份用户
   - 限制 SSH 密钥权限: `chmod 600 ~/.ssh/id_rsa`
   - 定期轮换密钥

2. **备份加密**
   ```bash
   # 使用 rsync + ssh 自动加密传输
   BACKUP_TYPE=remote
   ```

3. **访问控制**
   ```bash
   # 限制脚本执行权限
   chmod 750 03-rsync.sh
   chown root:backup 03-rsync.sh
   ```

4. **日志审计**
   ```bash
   # 定期检查日志
   grep ERROR /var/log/rsync-backup.log
   ```

## 最佳实践

1. **测试恢复流程**: 定期测试备份恢复，确保备份可用
2. **监控备份状态**: 使用 `status` 命令或监控系统检查备份状态
3. **多重备份**: 同时配置本地和远程备份
4. **版本控制**: 结合 Git 管理配置文件变更历史
5. **文档化**: 记录配置变更原因和恢复步骤

## 常见问题

**Q: 如何在后台运行服务？**

A: 使用 `nohup` 或 systemd 服务：
```bash
nohup ./03-rsync.sh start > /dev/null 2>&1 &
```

**Q: 如何备份多个目录？**

A: 为每个目录创建独立的配置文件和服务实例：
```bash
./03-rsync.sh -c config1.conf start &
./03-rsync.sh -c config2.conf start &
```

**Q: 如何验证备份完整性？**

A: 启用校验和模式：
```bash
ENABLE_CHECKSUM=1
```

**Q: 如何减少网络带宽使用？**

A: 启用压缩并增加防抖时间：
```bash
ENABLE_COMPRESSION=1
DEBOUNCE_TIME=60
```

## 技术支持

如有问题或建议，请查看：
- 日志文件: `/var/log/rsync-backup.log`
- 项目文档: `Documents/LinuxBasis/`
- 相关脚本: `Scripts/05-ubuntuInit.sh`

## 更新日志

### v2.0 (2024)
- ✅ 完全重写，生产环境就绪
- ✅ 添加配置文件支持
- ✅ 完善的错误处理和日志系统
- ✅ 支持本地和远程备份
- ✅ 添加恢复和清理功能
- ✅ 优化嵌入式设备性能

### v1.0 (旧版本)
- 基础的文件监控和同步功能
