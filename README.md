<div align="center">

# BenfordCheck

Native macOS app for fast Benford law checks on spreadsheet-style datasets.

<p>
  <a href="https://github.com/bingqldx/BenfordCheck/releases">
    <img src="https://img.shields.io/github/v/release/bingqldx/BenfordCheck?display_name=tag&style=flat-square" alt="Latest release">
  </a>
  <img src="https://img.shields.io/badge/macOS-15%2B-111827?style=flat-square&logo=apple" alt="macOS 15+">
  <img src="https://img.shields.io/badge/Swift-6.3-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6.3">
  <img src="https://img.shields.io/badge/status-public%20preview-0ea5e9?style=flat-square" alt="Public preview">
</p>

<p>
  <a href="https://github.com/bingqldx/BenfordCheck/releases/download/v0.5.1/BenfordCheck-v0.5.1.dmg">Download DMG</a>
  ·
  <a href="https://github.com/bingqldx/BenfordCheck/releases">Releases</a>
  ·
  <a href="#本地开发">Build from Source</a>
</p>

</div>

BenfordCheck 用来回答一个很具体的问题：

> 这张表里的整体数值分布，是否接近 Benford 定律？

它会把导入文件中的整张数值矩阵作为一个总体一次性分析，不按列拆分；同时自动汇总缺失单元格、非数值单元格、零值排除数量和最终进入计算的样本数，并用图表直观展示 `1-9` 首位数字偏差。

## 为什么做这个工具

很多现成脚本和统计包本身没问题，但对非编程用户来说通常还有这些门槛：

- 要先清理表格格式
- 要自己决定哪些值要排除
- 要自己拼图表和结论
- 大文件时交互体验很差

BenfordCheck 的目标就是把这条链路压缩成一个原生 Mac 工具：

- 拖入文件
- 自动完成整体扫描
- 直接看到结论、偏差图和摘要统计

## 核心特性

| 能力 | 说明 |
| --- | --- |
| 表格输入 | 支持 `csv`、`tsv`、`txt`、`xlsx` |
| 整体分析 | 把整张矩阵作为一个总体分析，不按列拆分 |
| 异常兼容 | 自动处理空白、缺失、非数值单元格 |
| 统计输出 | 输出 `MAD`、卡方统计量、`p` 值和结论状态 |
| 可视化 | 提供 `1-9` 偏差柱状图和分布明细表 |
| 交互体验 | 支持拖拽导入、拖拽替换、延迟显示进度条 |
| 大文件方向 | 面向百 MB 级表格的可用性持续优化 |

## 工作方式

1. 导入一个表格文件。
2. 如果是多工作表 `xlsx`，先选择一个 sheet。
3. 应用扫描整张矩阵，统计缺失、非数值、零值排除和 Benford 样本数。
4. 对所有可用非零数值计算首位数字分布。
5. 输出结论、偏差图和明细表。

## 输入与统计规则

### 文件支持

- 支持：`csv`、`tsv`、`txt`、`xlsx`
- 暂不支持：老式 `.xls`

### 单元格分类

- 空白、空字符串、`NA`、`N/A`、`NULL`、`NaN` 会计入缺失
- 可解析的有限数值会计入数值单元格
- `0` 与 `-0` 不参与首位数字统计，会单独计入零值排除
- 表头、行名、普通文本和其他非数值内容会计入非数值单元格

### Benford 计算口径

- 默认对整张矩阵做一次总体分析
- `xlsx` 当前一次只分析一个工作表
- 负数按绝对值处理
- 小数与科学计数法支持
- 结果状态使用 `符合 / 边界 / 不符合`

## 下载与安装

### 当前发行版

- Release 页面：[BenfordCheck Releases](https://github.com/bingqldx/BenfordCheck/releases)
- 当前版本：[`v0.5.1`](https://github.com/bingqldx/BenfordCheck/releases/tag/v0.5.1)
- 直接下载：[BenfordCheck-v0.5.1.dmg](https://github.com/bingqldx/BenfordCheck/releases/download/v0.5.1/BenfordCheck-v0.5.1.dmg)

### 安装步骤

1. 下载 `DMG`
2. 打开镜像
3. 将 `BenfordCheck.app` 拖入 `Applications`

> 当前发布包尚未签名和 notarize，所以在其他 Mac 上首次打开时，Gatekeeper 可能会提示安全警告。

## 样本数据

仓库内已经包含一批用于手工验证的样本文件：

- [SampleData/README.md](SampleData/README.md)

这些样本覆盖了：

- 接近 Benford 的数据
- 明显偏离的数据
- 混合缺失值、文本和零值的数据
- 多工作表 `xlsx`
- 大体量 `csv`

## 本地开发

### 环境要求

- macOS 15+
- Xcode Command Line Tools
- Swift 6.3

### 常用命令

```bash
swift test
./script/build_and_run.sh
./script/build_and_run.sh --verify
./script/package_release_dmg.sh v0.5.1
```

## 项目结构

```text
Sources/BenfordCheck/App/                app entry
Sources/BenfordCheck/Features/Analysis/  UI and state
Sources/BenfordCheck/Core/               parsing, statistics, Benford logic
Tests/BenfordCheckTests/                 unit and integration tests
SampleData/                              manual test fixtures
script/                                  build and release scripts
```

## 测试覆盖

当前测试覆盖的关键路径包括：

- 首位数字提取
- Benford 判定逻辑
- `csv` / `tsv` 扫描
- `xlsx` 工作表选择与扫描
- 进度条显示策略

## 当前限制

- 暂不支持 `.xls`
- 暂不支持导出报告
- 暂不支持按列、按组或多工作表合并分析
- 当前分发包未签名、未 notarize

## 版本记录

- `v0.5.0`：UI 美学优化、图标接入、结果页层级收敛
- `v0.5.1`：加入 DMG 打包与 GitHub Release 发布链路
