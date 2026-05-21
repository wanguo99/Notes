#!/bin/bash

# 备份脚本 - 支持文件和文件夹备份

BACKUP_HOME="$HOME/.my_backup"
CONFIG_DIR="$BACKUP_HOME/etc"
CONFIG_FILE="$CONFIG_DIR/config"
DEFAULT_BACKUP_DIR="$BACKUP_HOME/data"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[信息]${NC} $1"; }
print_success() { echo -e "${GREEN}[成功]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[警告]${NC} $1"; }
print_error() { echo -e "${RED}[错误]${NC} $1"; }

# 加载配置
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        return 0
    fi
    return 1
}

# 初始化配置
init_config() {
    print_info "检测到首次运行，开始初始化..."
    echo ""

    # 创建配置目录
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
        if [ $? -ne 0 ]; then
            print_error "无法创建配置目录: $CONFIG_DIR"
            exit 1
        fi
        print_success "配置目录已创建: $CONFIG_DIR"
    fi

    # 询问备份目录
    echo "请设置备份目录:"
    echo "  默认: $DEFAULT_BACKUP_DIR"
    read -p "使用默认目录? (Y/n): " use_default

    if [ -z "$use_default" ] || [ "$use_default" = "y" ] || [ "$use_default" = "Y" ]; then
        backup_dir="$DEFAULT_BACKUP_DIR"
    else
        read -p "请输入备份目录路径: " backup_dir
        backup_dir="${backup_dir/#\~/$HOME}"

        if [ -z "$backup_dir" ]; then
            print_warning "输入为空，使用默认目录"
            backup_dir="$DEFAULT_BACKUP_DIR"
        fi
    fi

    # 创建备份目录
    if [ ! -d "$backup_dir" ]; then
        mkdir -p "$backup_dir"
        if [ $? -ne 0 ]; then
            print_error "无法创建备份目录: $backup_dir"
            exit 1
        fi
        print_success "备份目录已创建: $backup_dir"
    else
        print_info "备份目录已存在: $backup_dir"
    fi

    # 保存配置
    echo "BACKUP_DIR=\"$backup_dir\"" > "$CONFIG_FILE"
    print_success "配置已保存"
    echo ""
}

# 执行备份
do_backup() {
    local source_path="$1"
    source_path="${source_path/#\~/$HOME}"

    if [ -z "$source_path" ]; then
        print_error "请指定要备份的文件或目录"
        return 1
    fi

    if [ ! -e "$source_path" ]; then
        print_error "路径不存在: $source_path"
        return 1
    fi

    # 确保备份目录存在
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        if [ $? -ne 0 ]; then
            print_error "无法创建备份目录: $BACKUP_DIR"
            return 1
        fi
    fi

    local basename=$(basename "$source_path")
    local backup_name="${basename}_${TIMESTAMP}"

    if [ -d "$source_path" ]; then
        # 备份目录
        backup_name="${backup_name}.tar.gz"
        local backup_path="$BACKUP_DIR/$backup_name"

        print_info "备份目录: $source_path"
        tar -czf "$backup_path" -C "$(dirname "$source_path")" "$basename" 2>/dev/null

        if [ $? -eq 0 ]; then
            local size=$(du -h "$backup_path" | cut -f1)
            print_success "备份完成! ($size)"
            echo "  → $backup_path"
        else
            print_error "备份失败"
            return 1
        fi
    else
        # 备份文件
        local backup_path="$BACKUP_DIR/$backup_name"

        print_info "备份文件: $source_path"
        cp "$source_path" "$backup_path"

        if [ $? -eq 0 ]; then
            local size=$(du -h "$backup_path" | cut -f1)
            print_success "备份完成! ($size)"
            echo "  → $backup_path"
        else
            print_error "备份失败"
            return 1
        fi
    fi
}

# 列出备份
list_backups() {
    if [ ! -d "$BACKUP_DIR" ]; then
        print_error "备份目录不存在: $BACKUP_DIR"
        return 1
    fi

    print_info "备份目录: $BACKUP_DIR"
    echo ""

    local count=$(ls -1 "$BACKUP_DIR" 2>/dev/null | wc -l)

    if [ $count -eq 0 ]; then
        print_warning "暂无备份文件"
    else
        ls -lht "$BACKUP_DIR" | tail -n +2 | awk '{printf "  %s %s %s  %5s  %s\n", $6, $7, $8, $5, $9}'
        echo ""
        local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
        print_info "共 $count 个文件，总大小: $total_size"
    fi
}

# 显示配置
show_config() {
    echo "配置信息:"
    echo "  配置文件: $CONFIG_FILE"
    echo "  备份目录: $BACKUP_DIR"

    if [ -d "$BACKUP_DIR" ]; then
        local count=$(ls -1 "$BACKUP_DIR" 2>/dev/null | wc -l)
        local size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
        echo ""
        echo "备份统计:"
        echo "  文件数: $count"
        echo "  总大小: $size"
    fi
}

# 修改配置
change_config() {
    print_info "当前备份目录: $BACKUP_DIR"
    read -p "输入新的备份目录 (留空保持不变): " new_dir

    if [ -z "$new_dir" ]; then
        print_info "配置未修改"
        return 0
    fi

    new_dir="${new_dir/#\~/$HOME}"

    if [ ! -d "$new_dir" ]; then
        read -p "目录不存在，是否创建? (y/n): " create
        if [ "$create" = "y" ] || [ "$create" = "Y" ]; then
            mkdir -p "$new_dir"
            if [ $? -ne 0 ]; then
                print_error "创建目录失败"
                return 1
            fi
        else
            return 1
        fi
    fi

    echo "BACKUP_DIR=\"$new_dir\"" > "$CONFIG_FILE"
    print_success "配置已更新: $new_dir"
}

# 显示帮助
show_help() {
    cat << EOF
用法: $0 [选项] [路径]

选项:
  -h, --help       显示帮助
  -c, --config     显示配置
  -s, --set        修改配置
  -l, --list       列出备份
  -b, --backup     备份文件/目录

示例:
  $0 file.txt              # 备份文件
  $0 /path/to/dir          # 备份目录
  $0 -b ~/documents        # 备份目录
  $0 -l                    # 列出所有备份
  $0 -s                    # 修改备份目录

配置: $CONFIG_FILE
EOF
}

# 主程序
main() {
    # 检查并初始化配置
    if [ ! -f "$CONFIG_FILE" ]; then
        init_config
    fi

    # 加载配置
    if ! load_config; then
        print_error "配置加载失败"
        exit 1
    fi

    # 无参数显示帮助
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    # 解析参数
    case "$1" in
        -h|--help)
            show_help
            ;;
        -c|--config)
            show_config
            ;;
        -s|--set)
            change_config
            ;;
        -l|--list)
            list_backups
            ;;
        -b|--backup)
            if [ -z "$2" ]; then
                print_error "请指定备份路径"
                exit 1
            fi
            do_backup "$2"
            ;;
        *)
            do_backup "$1"
            ;;
    esac
}

main "$@"
