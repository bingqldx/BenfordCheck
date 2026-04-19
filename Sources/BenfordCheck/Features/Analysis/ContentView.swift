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
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(red: 0.95, green: 0.97, blue: 0.99),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(viewModel.isDropTargeted ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
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
        .background(cardBackground)
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
        .background(cardBackground)
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
                        Text("检测结论")
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
                    GridItem(.adaptive(minimum: 150), spacing: 12),
                ],
                spacing: 12
            ) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(item.value)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
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
        .background(cardBackground)
    }

    private func chartSection(result: BenfordAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("1-9 偏差柱状图")
                .font(.headline)

            Chart {
                ForEach(viewModel.digitRows) { row in
                    BarMark(
                        x: .value("首位数字", String(row.digit)),
                        y: .value("偏差百分点", row.deviation * 100)
                    )
                    .foregroundStyle(row.deviation >= 0 ? Color(red: 0.18, green: 0.58, blue: 0.38) : Color(red: 0.86, green: 0.31, blue: 0.28))
                    .cornerRadius(4)
                }
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Color.secondary.opacity(0.4))
            }
            .chartXAxisLabel("首位数字")
            .chartYAxisLabel("偏差（百分点）")
            .chartOverlay { _ in }
            .frame(height: 260)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.02))
            )

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    headerCell("首位数字")
                    headerCell("理论占比")
                    headerCell("实际占比")
                    headerCell("偏差")
                }
                ForEach(viewModel.digitRows) { row in
                    GridRow {
                        bodyCell("\(row.digit)")
                        bodyCell(percent(row.expectedRatio))
                        bodyCell(percent(row.observedRatio))
                        bodyCell(signedPercent(row.deviation))
                    }
                }
            }
        }
        .padding(20)
        .background(cardBackground)
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
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
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
        .background(cardBackground)
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

    private var cardBackground: some ShapeStyle {
        .regularMaterial
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
                .fill(viewModel.isDropTargeted ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                .overlay(dropZoneOverlay)
                .frame(height: 160)
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

                Button("更换文件") {
                    viewModel.presentImporter()
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 8) {
                featureTag("整体矩阵一次计算")
                featureTag("导入后自动更新结果")
                featureTag("支持拖拽替换")
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.primary.opacity(0.04))
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

    private func featureTag(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.06), in: Capsule())
            .foregroundStyle(.secondary)
    }

    private func conclusionPresentation(for outcome: AnalysisOutcome) -> ConclusionPresentation {
        guard let result = outcome.result else {
            return ConclusionPresentation(
                title: "没有可用于 Benford 检测的非零数值",
                message: "这张表已经完成摘要统计，但没有可参与 Benford 计算的非零数值，因此当前不能给出“符合 / 不符合”的统计结论。",
                tint: .orange,
                badgeText: "无可用样本"
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
                badgeText: "符合"
            )
        case .borderline:
            return ConclusionPresentation(
                title: "当前结果处于边界状态",
                message: "\(stats) 当前样本接近阈值，建议结合业务背景和数据来源一起复核。\(chiSquareMessage)",
                tint: .orange,
                badgeText: "边界"
            )
        case .nonConforms:
            return ConclusionPresentation(
                title: "整体偏离 Benford 定律",
                message: "\(stats) 当前样本与理论分布差异较大，建议进一步检查数据来源、口径和异常值。\(chiSquareMessage)",
                tint: .red,
                badgeText: "不符合"
            )
        }
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
}
