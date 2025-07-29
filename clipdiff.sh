#!/bin/bash

# clipdiff - 比较文件和剪贴板内容的工具
# 使用 difftastic 或 diff 进行差异展示

# 默认设置
context=3
display_mode=""
language=""
reverse=0
skip_unchanged=0
verbose=0

# 显示帮助
show_help() {
    cat << EOF
clipdiff - 比较文件和剪贴板内容

用法:
    clipdiff [选项] <文件路径>

选项:
    -h, --help          显示帮助信息
    -r, --reverse       反转比较顺序（剪贴板在左，文件在右）
    -s, --side-by-side  使用并排显示模式
    -i, --inline        使用内联显示模式
    -c, --context N     显示 N 行上下文（默认: $context）
    -l, --language LANG 指定语言类型（如: python, javascript, json）
    --skip-unchanged    跳过未更改的内容
    -v, --verbose       显示详细调试信息

示例:
    clipdiff config.json                    # 比较文件和剪贴板内容（文件在左，剪贴板在右）
    clipdiff -r script.py                   # 反转比较顺序（剪贴板在左，文件在右）
    clipdiff -l python clipboard_code.txt   # 指定语言类型为 Python

注意:
    需要先安装 difftastic: cargo install --locked difftastic
    如果 difftastic 未安装，将自动回退到普通 diff
EOF
}

# 获取剪贴板内容
get_clipboard() {
    if command -v pbpaste >/dev/null 2>&1; then
        pbpaste
    elif command -v xclip >/dev/null 2>&1; then
        xclip -selection clipboard -o
    elif command -v xsel >/dev/null 2>&1; then
        xsel --clipboard --output
    elif command -v wl-paste >/dev/null 2>&1; then
        wl-paste
    elif command -v powershell.exe >/dev/null 2>&1; then
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

# 主函数
main() {
    local file=""
    local reverse=0
    local context=3
    local display_mode=""
    local language=""
    local skip_unchanged=0
    local verbose=0
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -r|--reverse)
                reverse=1
                shift
                ;;
            -s|--side-by-side)
                display_mode="side-by-side"
                shift
                ;;
            -i|--inline)
                display_mode="inline"
                shift
                ;;
            -c|--context)
                if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                    context="$2"
                    shift 2
                else
                    echo "错误: --context 需要一个数字参数" >&2
                    exit 1
                fi
                ;;
            -l|--language)
                if [[ -n "$2" ]]; then
                    language="$2"
                    shift 2
                else
                    echo "错误: --language 需要一个语言参数" >&2
                    exit 1
                fi
                ;;
            --skip-unchanged)
                skip_unchanged=1
                shift
                ;;
            -v|--verbose)
                verbose=1
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
    
    # 获取剪贴板内容
    [[ "$verbose" == "1" ]] && echo "正在读取剪贴板内容..." >&2
    clipboard_content=$(get_clipboard)
    
    if [[ -z "$clipboard_content" ]]; then
        echo "警告: 剪贴板为空" >&2
    fi
    
    # 创建临时文件来存储剪贴板内容
    local extension=""
    if [[ "$file" =~ \.[^.]+$ ]]; then
        extension="${file##*.}"
    fi
    
    local temp_file
    if [[ -n "$extension" ]]; then
        temp_file=$(mktemp --suffix=".$extension" 2>/dev/null || mktemp)
    else
        temp_file=$(mktemp)
    fi
    
    # 清理临时文件
    trap "rm -f '$temp_file'" EXIT
    echo "$clipboard_content" > "$temp_file"
    
    [[ "$verbose" == "1" ]] && echo "创建临时文件: $temp_file" >&2
    
    # 检查 difftastic 是否安装
    local diff_cmd
    local diff_opts=()
    
    if command -v difft >/dev/null 2>&1; then
        diff_cmd="difft"
        [[ -n "$display_mode" ]] && diff_opts+=("--display" "$display_mode")
        diff_opts+=("--context" "$context")
        [[ "$skip_unchanged" -eq 1 ]] && diff_opts+=("--skip-unchanged")
        [[ -n "$language" ]] && diff_opts+=("--language" "$language")
        [[ "$verbose" == "1" ]] && echo "使用 difftastic 进行比较..." >&2
    else
        diff_cmd="diff"
        diff_opts=("-u" "-L" "clipboard" "-L" "$(basename "$file")")
        [[ "$verbose" == "1" ]] && echo "使用 diff 进行比较（difftastic 未安装）..." >&2
    fi
    
    # 执行比较
    [[ "$verbose" == "1" ]] && echo "正在比较文件和剪贴板内容..." >&2
    
    if [[ "$reverse" -eq 1 ]]; then
        # 剪贴板在左，文件在右（反向）
        "$diff_cmd" "${diff_opts[@]}" "$temp_file" "$file"
    else
        # 文件在左，剪贴板在右（默认）
        "$diff_cmd" "${diff_opts[@]}" "$file" "$temp_file"
    fi
}

main "$@"