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

## [[#工具脚本|脚本实现]]

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
## 工具脚本
```shell
#!/bin/bash

#===============================================================================
# 脚本名称: 03-rsync.sh
# 功能描述: 嵌入式设备配置文件自动备份和恢复工具
# 版本信息: 2.0
# 适用场景: 生产环境中的配置文件实时备份和灾难恢复
#===============================================================================

set -euo pipefail

#===============================================================================
# 全局变量
#===============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/rsync-backup.conf}"
LOG_FILE="${LOG_FILE:-/var/log/rsync-backup.log}"
PID_FILE="${PID_FILE:-/var/run/rsync-backup.pid}"
STATE_DIR="${STATE_DIR:-/var/lib/rsync-backup}"

# 默认配置（可被配置文件覆盖）
WATCH_DIR=""
BACKUP_DIR=""
BACKUP_TYPE="local"  # local 或 remote
REMOTE_USER=""
REMOTE_HOST=""
REMOTE_DIR=""
EXCLUDE_PATTERNS=()
LOG_LEVEL="INFO"  # DEBUG, INFO, WARN, ERROR
MAX_LOG_SIZE="10M"
DEBOUNCE_TIME=5  # 防抖时间（秒）
ENABLE_COMPRESSION=1
ENABLE_CHECKSUM=0
BACKUP_RETENTION_DAYS=30

# 运行时变量
LAST_SYNC_TIME=0
PENDING_SYNC=0
CLEANUP_DONE=0

#===============================================================================
# 日志函数
#===============================================================================
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # 日志级别过滤
    case "$LOG_LEVEL" in
        DEBUG) ;;
        INFO) [[ "$level" == "DEBUG" ]] && return ;;
        WARN) [[ "$level" =~ ^(DEBUG|INFO)$ ]] && return ;;
        ERROR) [[ "$level" != "ERROR" ]] && return ;;
    esac

    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"

    # 日志轮转
    if [ -f "$LOG_FILE" ]; then
        local log_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        local max_size=$(numfmt --from=iec "$MAX_LOG_SIZE" 2>/dev/null || echo 10485760)
        if [ "$log_size" -gt "$max_size" ]; then
            mv "$LOG_FILE" "${LOG_FILE}.old"
            touch "$LOG_FILE"
            log INFO "日志文件已轮转"
        fi
    fi
}

log_debug() { log DEBUG "$@"; }
log_info() { log INFO "$@"; }
log_warn() { log WARN "$@"; }
log_error() { log ERROR "$@"; }

#===============================================================================
# 错误处理
#===============================================================================
error_exit() {
    log_error "$1"
    cleanup
    exit 1
}

cleanup() {
    if [ "$CLEANUP_DONE" -eq 1 ]; then
        return
    fi
    CLEANUP_DONE=1

    log_info "正在清理资源..."

    # 删除PID文件
    if [ -f "$PID_FILE" ]; then
        rm -f "$PID_FILE"
    fi

    log_info "清理完成"
}

# 信号处理
trap 'error_exit "收到中断信号，正在退出..."' INT TERM
trap 'cleanup' EXIT

#===============================================================================
# 依赖检查
#===============================================================================
check_dependencies() {
    log_info "检查依赖..."

    local missing_deps=()

    # 检查必需命令
    for cmd in rsync inotifywait; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "缺少依赖: ${missing_deps[*]}"
        log_info "请安装: apt-get install rsync inotify-tools"
        return 1
    fi

    # 检查可选命令
    if [ "$BACKUP_TYPE" = "remote" ]; then
        if ! command -v ssh &> /dev/null; then
            log_error "远程备份需要 ssh 命令"
            return 1
        fi
    fi

    log_info "依赖检查通过"
    return 0
}

#===============================================================================
# 配置文件处理
#===============================================================================
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_warn "配置文件不存在: $CONFIG_FILE"
        return 1
    fi

    log_info "加载配置文件: $CONFIG_FILE"

    # 读取配置文件（忽略注释和空行）
    while IFS='=' read -r key value; do
        # 跳过注释和空行
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue

        # 去除前后空格
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        case "$key" in
            WATCH_DIR) WATCH_DIR="$value" ;;
            BACKUP_DIR) BACKUP_DIR="$value" ;;
            BACKUP_TYPE) BACKUP_TYPE="$value" ;;
            REMOTE_USER) REMOTE_USER="$value" ;;
            REMOTE_HOST) REMOTE_HOST="$value" ;;
            REMOTE_DIR) REMOTE_DIR="$value" ;;
            EXCLUDE_PATTERNS) IFS=',' read -ra EXCLUDE_PATTERNS <<< "$value" ;;
            LOG_LEVEL) LOG_LEVEL="$value" ;;
            MAX_LOG_SIZE) MAX_LOG_SIZE="$value" ;;
            DEBOUNCE_TIME) DEBOUNCE_TIME="$value" ;;
            ENABLE_COMPRESSION) ENABLE_COMPRESSION="$value" ;;
            ENABLE_CHECKSUM) ENABLE_CHECKSUM="$value" ;;
            BACKUP_RETENTION_DAYS) BACKUP_RETENTION_DAYS="$value" ;;
        esac
    done < "$CONFIG_FILE"

    return 0
}

validate_config() {
    log_info "验证配置..."

    # 检查必需配置
    if [ -z "$WATCH_DIR" ]; then
        log_error "未配置 WATCH_DIR"
        return 1
    fi

    if [ ! -d "$WATCH_DIR" ]; then
        log_error "监控目录不存在: $WATCH_DIR"
        return 1
    fi

    if [ -z "$BACKUP_DIR" ] && [ "$BACKUP_TYPE" = "local" ]; then
        log_error "本地备份模式需要配置 BACKUP_DIR"
        return 1
    fi

    if [ "$BACKUP_TYPE" = "remote" ]; then
        if [ -z "$REMOTE_USER" ] || [ -z "$REMOTE_HOST" ] || [ -z "$REMOTE_DIR" ]; then
            log_error "远程备份模式需要配置 REMOTE_USER, REMOTE_HOST, REMOTE_DIR"
            return 1
        fi
    fi

    # 验证备份类型
    if [[ ! "$BACKUP_TYPE" =~ ^(local|remote)$ ]]; then
        log_error "无效的备份类型: $BACKUP_TYPE (应为 local 或 remote)"
        return 1
    fi

    log_info "配置验证通过"
    return 0
}

generate_config_template() {
    local template_file="${1:-rsync-backup.conf.example}"

    cat > "$template_file" << 'EOF'
#===============================================================================
# rsync 备份配置文件
#===============================================================================

# 监控目录（必需）
WATCH_DIR=/etc/config

# 备份类型: local 或 remote
BACKUP_TYPE=local

#-------------------------------------------------------------------------------
# 本地备份配置
#-------------------------------------------------------------------------------
BACKUP_DIR=/backup/config

#-------------------------------------------------------------------------------
# 远程备份配置
#-------------------------------------------------------------------------------
REMOTE_USER=backup
REMOTE_HOST=192.168.1.100
REMOTE_DIR=/backup/device-config

#-------------------------------------------------------------------------------
# 排除模式（逗号分隔）
#-------------------------------------------------------------------------------
# 示例: EXCLUDE_PATTERNS=*.tmp,*.log,*.swp,.git
EXCLUDE_PATTERNS=

#-------------------------------------------------------------------------------
# 日志配置
#-------------------------------------------------------------------------------
LOG_LEVEL=INFO
MAX_LOG_SIZE=10M

#-------------------------------------------------------------------------------
# 同步配置
#-------------------------------------------------------------------------------
# 防抖时间（秒）- 文件变化后等待多久才执行同步
DEBOUNCE_TIME=5

# 启用压缩（1=启用，0=禁用）
ENABLE_COMPRESSION=1

# 启用校验和（1=启用，0=禁用）- 更安全但更慢
ENABLE_CHECKSUM=0

# 备份保留天数（仅用于清理旧备份）
BACKUP_RETENTION_DAYS=30
EOF

    echo "配置模板已生成: $template_file"
}

#===============================================================================
# 备份功能
#===============================================================================
prepare_backup_destination() {
    if [ "$BACKUP_TYPE" = "local" ]; then
        if [ ! -d "$BACKUP_DIR" ]; then
            log_info "创建备份目录: $BACKUP_DIR"
            mkdir -p "$BACKUP_DIR" || error_exit "无法创建备份目录"
        fi
    else
        # 验证远程连接
        log_info "验证远程连接: ${REMOTE_USER}@${REMOTE_HOST}"
        if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "${REMOTE_USER}@${REMOTE_HOST}" "exit" 2>/dev/null; then
            log_error "无法连接到远程主机，请检查:"
            log_error "1. SSH密钥是否已配置"
            log_error "2. 远程主机是否可达"
            log_error "3. 用户名和主机名是否正确"
            return 1
        fi

        # 创建远程目录
        log_info "创建远程备份目录: $REMOTE_DIR"
        ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p '$REMOTE_DIR'" || {
            log_error "无法创建远程备份目录"
            return 1
        }
    fi

    return 0
}

perform_sync() {
    local current_time=$(date +%s)

    # 防抖：如果距离上次同步时间太短，则延迟
    if [ $((current_time - LAST_SYNC_TIME)) -lt "$DEBOUNCE_TIME" ]; then
        log_debug "防抖中，标记待同步"
        PENDING_SYNC=1
        return 0
    fi

    LAST_SYNC_TIME=$current_time
    PENDING_SYNC=0

    log_info "开始同步: $WATCH_DIR"

    # 构建 rsync 选项
    local rsync_opts="-av --delete"

    if [ "$ENABLE_COMPRESSION" -eq 1 ]; then
        rsync_opts="$rsync_opts -z"
    fi

    if [ "$ENABLE_CHECKSUM" -eq 1 ]; then
        rsync_opts="$rsync_opts -c"
    fi

    # 添加排除模式
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [ -n "$pattern" ]; then
            rsync_opts="$rsync_opts --exclude='$pattern'"
        fi
    done

    # 执行同步
    local sync_cmd
    local destination

    if [ "$BACKUP_TYPE" = "local" ]; then
        destination="$BACKUP_DIR/"
        sync_cmd="rsync $rsync_opts '$WATCH_DIR/' '$destination'"
    else
        destination="${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/"
        sync_cmd="rsync $rsync_opts -e 'ssh -o ConnectTimeout=10' '$WATCH_DIR/' '$destination'"
    fi

    log_debug "执行命令: $sync_cmd"

    if eval "$sync_cmd" >> "$LOG_FILE" 2>&1; then
        log_info "同步成功"

        # 记录同步状态
        mkdir -p "$STATE_DIR"
        date '+%Y-%m-%d %H:%M:%S' > "${STATE_DIR}/last_sync"

        return 0
    else
        log_error "同步失败"
        return 1
    fi
}

#===============================================================================
# 恢复功能
#===============================================================================
perform_restore() {
    log_info "开始恢复配置文件..."

    # 安全检查
    if [ ! -d "$WATCH_DIR" ]; then
        log_error "目标目录不存在: $WATCH_DIR"
        return 1
    fi

    # 备份当前配置
    local backup_current="${WATCH_DIR}.before-restore.$(date +%Y%m%d-%H%M%S)"
    log_info "备份当前配置到: $backup_current"
    cp -a "$WATCH_DIR" "$backup_current" || {
        log_error "无法备份当前配置"
        return 1
    }

    # 构建 rsync 选项
    local rsync_opts="-av"

    if [ "$ENABLE_COMPRESSION" -eq 1 ]; then
        rsync_opts="$rsync_opts -z"
    fi

    # 执行恢复
    local restore_cmd
    local source

    if [ "$BACKUP_TYPE" = "local" ]; then
        if [ ! -d "$BACKUP_DIR" ]; then
            log_error "备份目录不存在: $BACKUP_DIR"
            return 1
        fi
        source="$BACKUP_DIR/"
        restore_cmd="rsync $rsync_opts '$source' '$WATCH_DIR/'"
    else
        source="${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/"
        restore_cmd="rsync $rsync_opts -e 'ssh -o ConnectTimeout=10' '$source' '$WATCH_DIR/'"
    fi

    log_info "从 $source 恢复到 $WATCH_DIR"
    log_debug "执行命令: $restore_cmd"

    if eval "$restore_cmd" >> "$LOG_FILE" 2>&1; then
        log_info "恢复成功"
        log_info "原配置已备份到: $backup_current"
        return 0
    else
        log_error "恢复失败，正在回滚..."
        rm -rf "$WATCH_DIR"
        mv "$backup_current" "$WATCH_DIR"
        log_info "已回滚到恢复前状态"
        return 1
    fi
}

#===============================================================================
# 监控功能
#===============================================================================
start_monitoring() {
    log_info "开始监控目录: $WATCH_DIR"

    # 首次同步
    log_info "执行初始同步..."
    perform_sync || log_warn "初始同步失败"

    # 监控文件变化
    log_info "启动文件监控..."

    inotifywait -m -r -e modify,create,delete,move "$WATCH_DIR" --format '%e %w%f' 2>/dev/null | \
    while read -r event file; do
        log_debug "检测到变化: $event $file"

        # 检查是否在排除列表中
        local excluded=0
        for pattern in "${EXCLUDE_PATTERNS[@]}"; do
            if [[ "$file" == *"$pattern"* ]]; then
                log_debug "忽略排除文件: $file"
                excluded=1
                break
            fi
        done

        if [ $excluded -eq 0 ]; then
            perform_sync
        fi

        # 处理待同步标记
        if [ "$PENDING_SYNC" -eq 1 ]; then
            sleep "$DEBOUNCE_TIME"
            perform_sync
        fi
    done
}

#===============================================================================
# 清理功能
#===============================================================================
cleanup_old_backups() {
    if [ "$BACKUP_RETENTION_DAYS" -le 0 ]; then
        log_info "备份保留策略未启用"
        return 0
    fi

    log_info "清理 ${BACKUP_RETENTION_DAYS} 天前的备份..."

    if [ "$BACKUP_TYPE" = "local" ]; then
        find "$BACKUP_DIR" -type f -mtime "+${BACKUP_RETENTION_DAYS}" -delete 2>/dev/null || true
        log_info "本地备份清理完成"
    else
        ssh "${REMOTE_USER}@${REMOTE_HOST}" \
            "find '$REMOTE_DIR' -type f -mtime +${BACKUP_RETENTION_DAYS} -delete" 2>/dev/null || true
        log_info "远程备份清理完成"
    fi
}

#===============================================================================
# 状态检查
#===============================================================================
show_status() {
    echo "=========================================="
    echo "rsync 备份服务状态"
    echo "=========================================="
    echo "配置文件: $CONFIG_FILE"
    echo "监控目录: $WATCH_DIR"
    echo "备份类型: $BACKUP_TYPE"

    if [ "$BACKUP_TYPE" = "local" ]; then
        echo "备份目录: $BACKUP_DIR"
    else
        echo "远程主机: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"
    fi

    echo "日志文件: $LOG_FILE"
    echo "PID文件: $PID_FILE"

    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "运行状态: 运行中 (PID: $pid)"
        else
            echo "运行状态: 已停止 (PID文件存在但进程不存在)"
        fi
    else
        echo "运行状态: 已停止"
    fi

    if [ -f "${STATE_DIR}/last_sync" ]; then
        echo "最后同步: $(cat "${STATE_DIR}/last_sync")"
    else
        echo "最后同步: 从未同步"
    fi

    echo "=========================================="
}

#===============================================================================
# PID管理
#===============================================================================
check_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

create_pid_file() {
    if check_running; then
        error_exit "服务已在运行 (PID: $(cat "$PID_FILE"))"
    fi

    echo $$ > "$PID_FILE"
}

#===============================================================================
# 主函数
#===============================================================================
show_usage() {
    cat << EOF
用法: $SCRIPT_NAME [选项] <命令>

命令:
    start       启动监控服务
    stop        停止监控服务
    status      显示服务状态
    sync        执行一次同步
    restore     从备份恢复配置
    cleanup     清理旧备份
    init        生成配置文件模板

选项:
    -c FILE     指定配置文件 (默认: $CONFIG_FILE)
    -h          显示此帮助信息

环境变量:
    CONFIG_FILE           配置文件路径
    LOG_FILE              日志文件路径
    PID_FILE              PID文件路径
    STATE_DIR             状态目录路径

示例:
    # 生成配置文件模板
    $SCRIPT_NAME init

    # 使用默认配置启动服务
    $SCRIPT_NAME start

    # 使用自定义配置文件
    $SCRIPT_NAME -c /etc/rsync-backup.conf start

    # 执行一次同步
    $SCRIPT_NAME sync

    # 从备份恢复
    $SCRIPT_NAME restore

EOF
}

main() {
    # 解析命令行参数
    while getopts "c:h" opt; do
        case $opt in
            c) CONFIG_FILE="$OPTARG" ;;
            h) show_usage; exit 0 ;;
            *) show_usage; exit 1 ;;
        esac
    done
    shift $((OPTIND-1))

    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi

    local command="$1"

    # init 命令不需要配置文件
    if [ "$command" = "init" ]; then
        generate_config_template "${2:-rsync-backup.conf.example}"
        exit 0
    fi

    # 其他命令需要加载配置
    load_config || error_exit "无法加载配置文件"
    validate_config || error_exit "配置验证失败"
    check_dependencies || error_exit "依赖检查失败"

    # 创建必要的目录
    mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$PID_FILE")" "$STATE_DIR"

    # 执行命令
    case "$command" in
        start)
            create_pid_file
            prepare_backup_destination || error_exit "备份目标准备失败"
            start_monitoring
            ;;
        stop)
            if [ -f "$PID_FILE" ]; then
                local pid=$(cat "$PID_FILE")
                if kill -0 "$pid" 2>/dev/null; then
                    log_info "停止服务 (PID: $pid)"
                    kill "$pid"
                    rm -f "$PID_FILE"
                    log_info "服务已停止"
                else
                    log_warn "进程不存在，删除PID文件"
                    rm -f "$PID_FILE"
                fi
            else
                log_warn "服务未运行"
            fi
            ;;
        status)
            show_status
            ;;
        sync)
            prepare_backup_destination || error_exit "备份目标准备失败"
            perform_sync || exit 1
            ;;
        restore)
            perform_restore || exit 1
            ;;
        cleanup)
            cleanup_old_backups
            ;;
        *)
            log_error "未知命令: $command"
            show_usage
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"

```

## 工具配置文件
``` bash
#===============================================================================
# rsync 备份配置文件
#===============================================================================

# 监控目录（必需）
WATCH_DIR=/etc/config

# 备份类型: local 或 remote
BACKUP_TYPE=local

#-------------------------------------------------------------------------------
# 本地备份配置
#-------------------------------------------------------------------------------
BACKUP_DIR=/backup/config

#-------------------------------------------------------------------------------
# 远程备份配置
#-------------------------------------------------------------------------------
REMOTE_USER=backup
REMOTE_HOST=192.168.1.100
REMOTE_DIR=/backup/device-config

#-------------------------------------------------------------------------------
# 排除模式（逗号分隔）
#-------------------------------------------------------------------------------
# 示例: EXCLUDE_PATTERNS=*.tmp,*.log,*.swp,.git
EXCLUDE_PATTERNS=

#-------------------------------------------------------------------------------
# 日志配置
#-------------------------------------------------------------------------------
LOG_LEVEL=INFO
MAX_LOG_SIZE=10M

#-------------------------------------------------------------------------------
# 同步配置
#-------------------------------------------------------------------------------
# 防抖时间（秒）- 文件变化后等待多久才执行同步
DEBOUNCE_TIME=5

# 启用压缩（1=启用，0=禁用）
ENABLE_COMPRESSION=1

# 启用校验和（1=启用，0=禁用）- 更安全但更慢
ENABLE_CHECKSUM=0

# 备份保留天数（仅用于清理旧备份）
BACKUP_RETENTION_DAYS=30
```