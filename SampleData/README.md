# SampleData

这批样本是给 `BenfordCheck` 手工验收和演示用的，覆盖了正常拟合、明显偏离、缺失/文本混合、零值排除、科学计数法、多 sheet xlsx 和较大文本文件等场景。

## 文件说明

- `01-benford-like-small.csv`
  - 小型近似 Benford 样本。
  - 适合验证基本导入流程、摘要统计、图表渲染，以及“整体矩阵一起计算”。

- `02-non-benford-nine-heavy.csv`
  - 明显偏离 Benford，首位数字故意偏向 `8` 和 `9`。
  - 适合验证“明显不符合”的结果展示。

- `03-mixed-missing-text.tsv`
  - 含表头、行名、空白、`NA`、`NULL`、普通文本、零值、科学计数法。
  - 适合验证缺失单元格、非数值单元格、零值排除和样本计数。

- `04-zero-heavy-semicolon.txt`
  - 分号分隔的 `.txt` 文本表，零值比例很高。
  - 适合验证 `.txt` 分隔符自动识别和零值不参与 Benford 统计。

- `05-scientific-notation.csv`
  - 主要由负数、小数、科学计数法组成。
  - 适合验证首位有效数字提取逻辑。

- `06-multi-sheet-selection.xlsx`
  - 三个工作表，内容分别偏向文本说明、近似 Benford 和明显偏离。
  - 适合验证多 sheet 选择流程，以及“只分析所选 sheet”。

- `07-single-sheet-edge-cases.xlsx`
  - 单个 sheet，内部穿插空白、文本、零值、普通数值。
  - 适合验证 xlsx 的缺失/非数值/零值分类。

- `08-large-benford-like.csv`
  - 中等偏大的压力样本，用于观察大文件读取速度和进度条行为。
  - 适合验证长任务时 UI 是否仍然平稳。

## 建议手测顺序

1. 先用 `01` 和 `02` 验证“符合 / 不符合”的主结果。
2. 用 `03`、`04`、`05` 检查摘要统计与数值分类是否符合直觉。
3. 用 `06` 检查多 sheet 选择流程。
4. 最后用 `08` 观察大文件体验和进度展示。
