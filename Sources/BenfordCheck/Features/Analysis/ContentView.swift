import Charts
import Observation
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var viewModel: AnalysisViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroSection

                if case let .failed(message) = viewModel.status {
                    messageCard(title: "出错了", message: message, tint: .red)
                }

                if case .selectingSheet = viewModel.status {
                    sheetSelectionSection
                }

                if viewModel.isProgressVisible {
                    progressSection
                }

                if let outcome = viewModel.outcome {
                    summarySection(outcome: outcome)
                    if let result = outcome.result {
                        chartSection(result: result)
                    }
                } else if case .idle = viewModel.status {
                    messageCard(
                        title: "准备开始",
                        message: "导入 csv、tsv、txt 或 xlsx 文件后，应用会把整个矩阵作为一个总体进行 Benford 检测，并汇总缺失、非数值、零值排除和最终样本量。",
                        tint: .blue
                    )
                }
            }
            .padding(24)
            .frame(maxWidth: 1120, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color(nsColor: .windowBackgroundColor),
                        Color(red: 0.96, green: 0.97, blue: 0.99),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(width: 420, height: 420)
                    .blur(radius: 110)
                    .offset(x: -320, y: -280)

                Circle()
                    .fill(Color.green.opacity(0.06))
                    .frame(width: 360, height: 360)
                    .blur(radius: 120)
                    .offset(x: 320, y: 420)
            }
            .ignoresSafeArea()
        )
        .fileImporter(
            isPresented: $viewModel.isImporterPresented,
            allowedContentTypes: viewModel.allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                if let first = urls.first {
                    viewModel.handleImporterResult(.success(first))
                }
            case let .failure(error):
                viewModel.handleImporterResult(.failure(error))
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("分析面板", systemImage: "waveform.path.ecg.rectangle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Benford 定律快速检测")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text(heroSubtitle)
                .foregroundStyle(.secondary)

            if usesCompactImporter {
                compactImporterPanel
            } else {
                expandedImporterPanel
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            surfacePanel(cornerRadius: 32, tint: Color.accentColor.opacity(0.08))
        }
        .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .onDrop(of: [.fileURL], isTargeted: $viewModel.isDropTargeted) { providers in
            viewModel.handleDroppedProviders(providers)
        }
    }

    private var sheetSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择要分析的工作表")
                .font(.headline)

            Picker("工作表", selection: $viewModel.selectedSheetName) {
                ForEach(viewModel.availableSheets, id: \.self) { sheetName in
                    Text(sheetName).tag(sheetName)
                }
            }
            .pickerStyle(.menu)

            Button("开始分析") {
                viewModel.confirmSheetSelection()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .background {
            surfacePanel(cornerRadius: 28, tint: Color.primary.opacity(0.04))
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分析进度")
                .font(.headline)
            ProgressView(value: viewModel.scanProgress) {
                Text(viewModel.scanStage)
            } currentValueLabel: {
                Text(percent(viewModel.scanProgress))
                    .monospacedDigit()
            }
            Text("只有在 3 秒后进度仍低于 50% 时才会展示进度条，避免短任务界面闪烁。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background {
            surfacePanel(cornerRadius: 28, tint: Color.primary.opacity(0.04))
        }
    }

    private func summarySection(outcome: AnalysisOutcome) -> some View {
        let summary = outcome.summary
        let items = [
            SummaryItem(title: "缺失单元格", value: formattedCount(summary.missingCellCount)),
            SummaryItem(title: "非数值单元格", value: formattedCount(summary.nonNumericCellCount)),
            SummaryItem(title: "数值单元格", value: formattedCount(summary.numericCellCount)),
            SummaryItem(title: "零值排除", value: formattedCount(summary.zeroExcludedCount)),
            SummaryItem(title: "Benford 样本数", value: formattedCount(summary.benfordSampleCount)),
            SummaryItem(title: "矩阵尺寸", value: "\(formattedCount(summary.rowCount)) × \(formattedCount(summary.columnCount))"),
        ]
        let conclusion = conclusionPresentation(for: outcome)

        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("检测结论", systemImage: conclusion.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(conclusion.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(conclusion.tint)
                        Text(conclusion.message)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 16)
                    statusBadgeText(conclusion.badgeText, color: conclusion.tint)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(conclusion.tint.opacity(0.08))
            )

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 160), spacing: 14),
                ],
                spacing: 14
            ) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(item.value)
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background {
                        insetTile(tint: .primary.opacity(0.03))
                    }
                }
            }

            if let result = outcome.result {
                HStack(spacing: 12) {
                    metricCallout(label: "MAD", value: fixedNumber(result.mad, digits: 4))
                    metricCallout(label: "卡方统计量", value: fixedNumber(result.chiSquare, digits: 3))
                    metricCallout(label: "p 值", value: fixedNumber(result.pValue, digits: 4))
                }
            }
        }
        .padding(20)
        .background {
            surfacePanel(cornerRadius: 30)
        }
    }

    private func chartSection(result: BenfordAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label("偏差分布", systemImage: "chart.bar.xaxis")
                    .font(.headline)

                Spacer(minLength: 16)

                Text("图表和明细共用同一组 1-9 首位数字分布")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) {
                    chartVisualizationPanel
                        .frame(minWidth: 500, idealWidth: 560)

                    subtleDivider(vertical: true)

                    distributionTablePanel
                        .frame(minWidth: 320, idealWidth: 340)
                }

                VStack(alignment: .leading, spacing: 18) {
                    chartVisualizationPanel
                    subtleDivider()
                    distributionTablePanel
                }
            }
        }
        .padding(20)
        .background {
            surfacePanel(cornerRadius: 30)
        }
    }

    private func statusBadge(_ status: BenfordStatus) -> some View {
        statusBadgeText(status.rawValue, color: color(for: status))
    }

    private func statusBadgeText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }

    private func color(for status: BenfordStatus) -> Color {
        switch status {
        case .conforms:
            return .green
        case .borderline:
            return .orange
        case .nonConforms:
            return .red
        }
    }

    private func metricCallout(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            insetTile(tint: .primary.opacity(0.02))
        }
    }

    private func messageCard(title: String, message: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(tint)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background {
            surfacePanel(cornerRadius: 28, tint: tint.opacity(0.06))
        }
    }

    private func headerCell(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bodyCell(_ text: String) -> some View {
        Text(text)
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dropZoneOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "tablecells.badge.ellipsis")
                .font(.system(size: 30))
                .foregroundStyle(Color.accentColor)
            Text("把表格拖到这里也可以")
                .font(.headline)
            Text("支持 .csv / .tsv / .txt / .xlsx")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private func percent(_ value: Double) -> String {
        fixedNumber(value * 100, digits: 2) + "%"
    }

    private func signedPercent(_ value: Double) -> String {
        let formatted = fixedNumber(abs(value) * 100, digits: 2) + "%"
        return value >= 0 ? "+\(formatted)" : "-\(formatted)"
    }

    private func fixedNumber(_ value: Double, digits: Int) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(digits ... digits))
        )
    }

    private func formattedCount(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    private var usesCompactImporter: Bool {
        !viewModel.importedFileName.isEmpty
    }

    private var heroSubtitle: String {
        usesCompactImporter
            ? "当前结果始终基于整张矩阵一次性计算，不按列拆分。你也可以直接拖入新文件覆盖当前结果。"
            : "一次导入一个表格，把整张数值矩阵作为一个整体进行检测。支持自动排除空白、缺失和非数值单元格。"
    }

    private var expandedImporterPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Button("选择文件") {
                    viewModel.presentImporter()
                }
                .buttonStyle(.borderedProminent)

                Text("尚未选择文件")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(viewModel.isDropTargeted ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.03))
                .overlay(dropZoneOverlay)
                .frame(height: 160)
                .shadow(color: viewModel.isDropTargeted ? Color.accentColor.opacity(0.12) : .clear, radius: 18, y: 8)
        }
    }

    private var compactImporterPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 48, height: 48)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("当前文件")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(viewModel.importedFileName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(compactImporterCaption)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 16)

                VStack(spacing: 8) {
                    Button {
                        viewModel.presentImporter()
                    } label: {
                        Text("更换文件")
                            .frame(width: compactImporterActionWidth)
                    }
                    .buttonStyle(.borderedProminent)

                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc")
                        Text("也可拖拽替换")
                    }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(viewModel.isDropTargeted ? Color.accentColor : .secondary)
                        .frame(width: compactImporterActionWidth)
                        .padding(.vertical, 6)
                        .background(
                            (viewModel.isDropTargeted ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04)),
                            in: Capsule()
                        )
                }
                .frame(width: compactImporterActionWidth)
            }

            HStack(spacing: 8) {
                featureTag("整体矩阵一次计算")
                featureTag("导入后自动更新结果")
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private var compactImporterCaption: String {
        if let outcome = viewModel.outcome {
            return "已扫描 \(formattedCount(outcome.summary.totalCellCount)) 个单元格，Benford 样本 \(formattedCount(outcome.summary.benfordSampleCount)) 个。"
        }

        switch viewModel.status {
        case .selectingSheet:
            return "这是一个多工作表 xlsx，请先选择要分析的工作表。"
        case .scanning:
            return viewModel.scanStage.isEmpty ? "正在分析整张矩阵，请稍候。" : viewModel.scanStage
        case .failed:
            return "你可以直接更换文件继续分析。"
        default:
            return "会把整张矩阵作为一个整体分析，不按列拆分。"
        }
    }

    private var compactImporterActionWidth: CGFloat {
        148
    }

    private func featureTag(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05), in: Capsule())
            .foregroundStyle(.secondary)
    }

    private func conclusionPresentation(for outcome: AnalysisOutcome) -> ConclusionPresentation {
        guard let result = outcome.result else {
            return ConclusionPresentation(
                title: "没有可用于 Benford 检测的非零数值",
                message: "这张表已经完成摘要统计，但没有可参与 Benford 计算的非零数值，因此当前不能给出“符合 / 不符合”的统计结论。",
                tint: .orange,
                badgeText: "无可用样本",
                symbol: "exclamationmark.circle"
            )
        }

        let stats = "MAD \(fixedNumber(result.mad, digits: 4))，卡方统计量 \(fixedNumber(result.chiSquare, digits: 3))，p 值 \(fixedNumber(result.pValue, digits: 4))。"
        let chiSquareMessage = result.pValue < 0.05 ? "卡方检验给出了统计警示。" : "卡方检验未提示显著异常。"

        switch result.status {
        case .conforms:
            return ConclusionPresentation(
                title: "整体符合 Benford 定律",
                message: "\(stats) 当前样本的首位数字分布与理论分布非常接近，\(chiSquareMessage)",
                tint: .green,
                badgeText: "符合",
                symbol: "checkmark.seal"
            )
        case .borderline:
            return ConclusionPresentation(
                title: "当前结果处于边界状态",
                message: "\(stats) 当前样本接近阈值，建议结合业务背景和数据来源一起复核。\(chiSquareMessage)",
                tint: .orange,
                badgeText: "边界",
                symbol: "exclamationmark.triangle"
            )
        case .nonConforms:
            return ConclusionPresentation(
                title: "整体偏离 Benford 定律",
                message: "\(stats) 当前样本与理论分布差异较大，建议进一步检查数据来源、口径和异常值。\(chiSquareMessage)",
                tint: .red,
                badgeText: "不符合",
                symbol: "xmark.octagon"
            )
        }
    }

    private var chartVisualizationPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("1-9 偏差柱状图")
                    .font(.subheadline.weight(.semibold))
                Text("纵轴展示的是实际占比减去理论占比后的百分点差值。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(viewModel.digitRows) { row in
                    BarMark(
                        x: .value("首位数字", String(row.digit)),
                        y: .value("偏差百分点", row.deviation * 100)
                    )
                    .foregroundStyle(row.deviation >= 0 ? Color(red: 0.16, green: 0.56, blue: 0.38) : Color(red: 0.80, green: 0.30, blue: 0.28))
                    .cornerRadius(6)
                }

                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Color.secondary.opacity(0.55))
            }
            .chartXAxisLabel("首位数字")
            .chartYAxisLabel("偏差（百分点）")
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6, dash: [3, 3]))
                        .foregroundStyle(Color.secondary.opacity(0.18))
                    AxisValueLabel()
                }
            }
            .frame(height: 310)
        }
    }

    private var distributionTablePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("分布明细")
                    .font(.subheadline.weight(.semibold))
                Text("用明细表快速核对每个首位数字的理论占比、实际占比和偏差。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                tableHeaderCell("首位数字")
                tableHeaderCell("理论占比")
                tableHeaderCell("实际占比")
                tableHeaderCell("偏差")
            }

            VStack(spacing: 6) {
                ForEach(Array(viewModel.digitRows.enumerated()), id: \.element.id) { index, row in
                    distributionRow(row, index: index)
                }
            }
        }
    }

    private func surfacePanel(cornerRadius: CGFloat, tint: Color = .clear) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 18, y: 10)
    }

    private func insetTile(tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.regularMaterial)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(tint)
            }
    }

    private func tableHeaderCell(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
    }

    private func distributionRow(_ row: DigitDeviationRow, index: Int) -> some View {
        HStack(spacing: 0) {
            distributionCell("\(row.digit)")
            distributionCell(percent(row.expectedRatio))
            distributionCell(percent(row.observedRatio))
            distributionCell(signedPercent(row.deviation), emphasis: row.deviation >= 0 ? .positive : .negative)
        }
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(index.isMultiple(of: 2) ? Color.primary.opacity(0.05) : Color.primary.opacity(0.022))
        )
    }

    private func distributionCell(_ text: String, emphasis: CellEmphasis = .normal) -> some View {
        Text(text)
            .font(.system(.body, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(emphasis.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
    }

    private func subtleDivider(vertical: Bool = false) -> some View {
        Capsule()
            .fill(Color.primary.opacity(0.07))
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
            .frame(maxHeight: vertical ? .infinity : nil)
            .padding(vertical ? .vertical : .horizontal, 2)
    }
}

private struct SummaryItem: Identifiable {
    let title: String
    let value: String

    var id: String { title }
}

private struct ConclusionPresentation {
    let title: String
    let message: String
    let tint: Color
    let badgeText: String
    let symbol: String
}

private enum CellEmphasis {
    case normal
    case positive
    case negative

    var color: Color {
        switch self {
        case .normal:
            return .primary
        case .positive:
            return Color(red: 0.16, green: 0.56, blue: 0.38)
        case .negative:
            return Color(red: 0.78, green: 0.31, blue: 0.29)
        }
    }
}
