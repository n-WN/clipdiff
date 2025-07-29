#!/bin/bash

# clipdiff - 比较文件和剪贴板内容的工具
# 使用 difftastic 进行语法感知的差异展示

set -e

# 显示帮助信息
show_help() {
    cat << EOF
clipdiff - 比较文件和剪贴板内容

用法:
    clipdiff [选项] <文件路径>

选项:
    -h, --help          显示此帮助信息
    -r, --reverse       反转比较顺序（文件在左，剪贴板在右）
    -s, --side-by-side  强制使用并排显示模式
    -i, --inline        使用内联显示模式
    -c, --context N     显示 N 行上下文（默认: 3）
    -l, --language LANG 指定语言类型（如: python, javascript, json）
    --skip-unchanged    跳过未更改的内容

示例:
    clipdiff config.json                    # 比较 config.json 和剪贴板内容
    clipdiff -r script.py                   # 反转比较顺序
    clipdiff -l python clipboard_code.txt   # 指定语言类型为 Python

注意:
    需要先安装 difftastic: cargo install --locked difftastic
EOF
}

# 检测操作系统并获取剪贴板内容
get_clipboard() {
    if command -v pbpaste &> /dev/null; then
        # macOS
        pbpaste
    elif command -v xclip &> /dev/null; then
        # Linux with xclip
        xclip -selection clipboard -o
    elif command -v xsel &> /dev/null; then
        # Linux with xsel
        xsel --clipboard --output
    elif command -v wl-paste &> /dev/null; then
        # Wayland
        wl-paste
    elif command -v powershell.exe &> /dev/null; then
        # WSL
        powershell.exe -command "Get-Clipboard" | tr -d '\r'
    else
        echo "错误: 无法检测到剪贴板工具。请安装以下工具之一:" >&2
        echo "  - macOS: 系统自带 pbpaste" >&2
        echo "  - Linux (X11): xclip 或 xsel" >&2
        echo "  - Linux (Wayland): wl-clipboard" >&2
        echo "  - WSL: 确保可以访问 Windows 的 powershell.exe" >&2
        exit 1
    fi
}

# 检查 difftastic 是否安装
check_difftastic() {
    if ! command -v difft &> /dev/null; then
        echo "错误: 未找到 difftastic (difft)。" >&2
        echo "请先安装: cargo install --locked difftastic" >&2
        exit 1
    fi
}

# 主函数
main() {
    local file=""
    local reverse=false
    local difft_opts=()
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -r|--reverse)
                reverse=true
                shift
                ;;
            -s|--side-by-side)
                difft_opts+=("--display" "side-by-side")
                shift
                ;;
            -i|--inline)
                difft_opts+=("--display" "inline")
                shift
                ;;
            -c|--context)
                if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                    difft_opts+=("--context" "$2")
                    shift 2
                else
                    echo "错误: --context 需要一个数字参数" >&2
                    exit 1
                fi
                ;;
            -l|--language)
                if [[ -n "$2" ]]; then
                    difft_opts+=("--language" "$2")
                    shift 2
                else
                    echo "错误: --language 需要一个语言参数" >&2
                    exit 1
                fi
                ;;
            --skip-unchanged)
                difft_opts+=("--skip-unchanged")
                shift
                ;;
            -*)
                echo "错误: 未知选项: $1" >&2
                echo "使用 -h 或 --help 查看帮助" >&2
                exit 1
                ;;
            *)
                if [[ -z "$file" ]]; then
                    file="$1"
                else
                    echo "错误: 只能指定一个文件" >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # 检查是否指定了文件
    if [[ -z "$file" ]]; then
        echo "错误: 请指定要比较的文件" >&2
        echo "使用 -h 或 --help 查看帮助" >&2
        exit 1
    fi
    
    # 检查文件是否存在
    if [[ ! -f "$file" ]]; then
        echo "错误: 文件不存在: $file" >&2
        exit 1
    fi
    
    # 检查 difftastic 是否安装
    check_difftastic
    
    # 获取剪贴板内容
    echo "正在读取剪贴板内容..." >&2
    clipboard_content=$(get_clipboard)
    
    if [[ -z "$clipboard_content" ]]; then
        echo "警告: 剪贴板为空" >&2
    fi
    
    # 创建临时文件来存储剪贴板内容
    temp_file=$(mktemp)
    trap "rm -f $temp_file" EXIT
    
    echo "$clipboard_content" > "$temp_file"
    
    # 根据文件扩展名设置临时文件的扩展名（帮助 difftastic 识别语言）
    if [[ "$file" =~ \.[^.]+$ ]] && [[ -z "${difft_opts[@]}" || ! " ${difft_opts[@]} " =~ " --language " ]]; then
        ext="${file##*.}"
        temp_file_with_ext="${temp_file}.${ext}"
        mv "$temp_file" "$temp_file_with_ext"
        temp_file="$temp_file_with_ext"
    fi
    
    # 执行比较
    echo "正在比较文件和剪贴板内容..." >&2
    echo "" >&2
    
    if [[ "$reverse" == true ]]; then
        # 文件在左，剪贴板在右
        difft "${difft_opts[@]}" "$file" "$temp_file"
    else
        # 剪贴板在左，文件在右（默认）
        difft "${difft_opts[@]}" "$temp_file" "$file"
    fi
}

# 运行主函数
main "$@"
