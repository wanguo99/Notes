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