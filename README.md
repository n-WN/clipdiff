# clipdiff - 剪贴板文件比较工具

专为优化 LLM 输出代码比较体验而设计的 Bash 脚本。当你从 LLM 复制代码时，可以快速与本地文件进行对比，精准识别差异并支持语法高亮显示。

<img width="1369" height="386" alt="image" src="https://github.com/user-attachments/assets/18d48724-7968-4687-b2da-21f2ae0ba2ed" />

## 功能特性

- **LLM 工作流优化**：专为从 Claude、ChatGPT 等 LLM 复制代码的场景设计
- **跨平台剪贴板**：支持 macOS、Linux、Windows WSL
- **智能语法高亮**：自动检测 difftastic，提供语法感知的差异显示
- **正确的比较顺序**：文件在左（原始），剪贴板在右（LLM 输出），符合 diff 惯例
- **快速差异定位**：跳过未更改内容，直接聚焦修改部分
- **多语言支持**：可手动指定编程语言优化显示效果

## 安装

1. 克隆或下载脚本
2. 赋予执行权限：
   ```bash
   chmod +x clipdiff.sh
   ```
3. 放到 SHELL 配置文件，方便全局使用（按需更改）：
   ```bash
   echo "alias clipdiff=\"$PWD/clipdiff.sh\"" >> ~/.zshrc
   ```

### 依赖项

- **必需**：任一剪贴板工具
  - macOS: `pbpaste`（系统自带）
  - Linux (X11): `xclip` 或 `xsel`
  - Linux (Wayland): `wl-clipboard`
  - Windows WSL: `powershell.exe`

- **可选**：difftastic（推荐用于语法高亮）
  ```bash
  cargo install --locked difftastic
  ```

## LLM 工作流示例

### 场景 1：快速验证 LLM 代码修改
```bash
# 1. 复制 LLM 输出的代码到剪贴板
# 2. 比较当前文件与 LLM 输出
./clipdiff.sh app.py

# 输出格式：文件(左) vs 剪贴板(右)
# 直观看到 LLM 对代码的修改
```

### 场景 2：批量文件更新
```bash
# 复制多段 LLM 输出，分别比较不同文件
./clipdiff.sh src/utils.py
./clipdiff.sh src/config.py
./clipdiff.sh tests/test_utils.py
```

### 场景 3：精确语法比较
```bash
# 当 LLM 输出包含语法错误时，指定语言类型获得更好的高亮
./clipdiff.sh -l javascript script.js
./clipdiff.sh -l rust main.rs
./clipdiff.sh -l yaml docker-compose.yml
```

## 使用方法

```bash
# 基本使用 - 比较文件与 LLM 输出（文件在左，剪贴板在右）
./clipdiff.sh current_file.py

# 高级选项
./clipdiff.sh -s -c 5 -l typescript component.tsx    # 并排显示，5行上下文
./clipdiff.sh --skip-unchanged --verbose config.json   # 跳过未更改，显示调试信息
./clipdiff.sh -r original.py                           # 反向比较（剪贴板在左，文件在右）
```

## 选项说明

| 选项 | 描述 |
|------|------|
| `-h, --help` | 显示帮助信息 |
| `-r, --reverse` | 反转比较顺序（剪贴板在左，文件在右） |
| `-s, --side-by-side` | 使用并排显示模式 |
| `-i, --inline` | 使用内联显示模式 |
| `-c, --context N` | 显示 N 行上下文（默认: 3） |
| `-l, --language LANG` | 指定语言类型 |
| `--skip-unchanged` | 跳过未更改的内容 |
| `-v, --verbose` | 显示详细调试信息 |

## 为什么专为 LLM 设计?

传统 diff 工具需要手动保存文件再进行比较，而 LLM 工作流中：

1. **高频对比**：每次对话都可能产生修改后的代码
2. **零文件操作**：直接从 LLM 复制代码，无需保存临时文件
3. **语法敏感**：需要准确识别 Python、JavaScript、YAML 等语言的语法差异
4. **快速反馈**：在 IDE 中一键比较，避免上下文切换

## 工作原理

1. **剪贴板读取**：自动检测系统剪贴板工具并读取内容
2. **智能扩展名**：根据文件类型创建带正确扩展名的临时文件，帮助 difftastic 识别语言
3. **差异显示**：使用 difftastic 进行语法感知差异展示，或回退到标准 diff
4. **自动清理**：比较完成后自动删除临时文件

## 与传统 diff 的对比

| 场景 | 传统 diff | clipdiff |
|------|-----------|----------|
| LLM 输出比较 | 需保存文件 → 运行 diff → 删除文件 | 复制 → 运行 clipdiff |
| 语言识别 | 需要手动指定 | 自动根据文件扩展名 |
| 多文件比较 | 需要多次保存 | 直接多次运行 |
| 语法高亮 | 无 | difftastic 支持 |

## 使用场景

### LLM 开发工作流
- **代码审查**：验证 LLM 生成的修改是否正确
- **重构验证**：确认 LLM 的重构没有破坏功能
- **配置更新**：检查 LLM 建议的配置更改
- **测试用例**：比较 LLM 生成的测试与现有测试

### 日常开发
- **代码对比**：快速比较本地代码与 LLM 建议
- **配置管理**：验证 LLM 建议的配置文件更改
- **文档同步**：检查 LLM 生成的文档更新

## 工作原理

1. 检测系统剪贴板工具并读取内容
2. 创建带正确扩展名的临时文件
3. 使用 difftastic（或 diff）进行差异比较
4. 自动清理临时文件

## 示例

假设你有一个配置文件 `config.json`，想比较它与剪贴板中的内容：

```bash
# 复制一些 JSON 到剪贴板，然后：
./clipdiff.sh config.json

# 结果将显示文件内容与剪贴板内容的差异
```

## 许可证

MIT License - 可自由使用、修改和分发。
