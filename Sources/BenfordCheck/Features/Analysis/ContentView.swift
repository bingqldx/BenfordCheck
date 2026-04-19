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
                    } else {
                        messageCard(
                            title: "没有可计算样本",
                            message: "这个表格里没有非零数值可以参与 Benford 检测，请检查是否整张表都是空白、文本或零值。",
                            tint: .orange
                        )
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
            .frame(maxWidth: .infinity, alignment: .leading)
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

            Text("一次导入一个表格，把整张数值矩阵作为一个整体进行检测。支持自动排除空白、缺失和非数值单元格。")
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                Button("选择文件") {
                    viewModel.presentImporter()
                }
                .buttonStyle(.borderedProminent)

                Text(viewModel.importedFileName.isEmpty ? "尚未选择文件" : "当前文件：\(viewModel.importedFileName)")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(viewModel.isDropTargeted ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                .overlay(dropZoneOverlay)
                .frame(height: 160)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(viewModel.isDropTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .onDrop(of: [.fileURL], isTargeted: $viewModel.isDropTargeted) { providers in
                    viewModel.handleDroppedProviders(providers)
                }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
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
            SummaryItem(title: "缺失单元格", value: "\(summary.missingCellCount)"),
            SummaryItem(title: "非数值单元格", value: "\(summary.nonNumericCellCount)"),
            SummaryItem(title: "数值单元格", value: "\(summary.numericCellCount)"),
            SummaryItem(title: "零值排除", value: "\(summary.zeroExcludedCount)"),
            SummaryItem(title: "Benford 样本数", value: "\(summary.benfordSampleCount)"),
            SummaryItem(title: "矩阵尺寸", value: "\(summary.rowCount) × \(summary.columnCount)"),
        ]

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text("检测摘要")
                    .font(.headline)
                Spacer()
                if let result = outcome.result {
                    statusBadge(result.status)
                } else {
                    statusBadgeText("无可用样本", color: .orange)
                }
            }

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
                HStack(spacing: 20) {
                    metricCallout(label: "MAD", value: number(result.mad, digits: 4))
                    metricCallout(label: "卡方", value: number(result.chiSquare, digits: 3))
                    metricCallout(label: "p 值", value: number(result.pValue, digits: 4))
                }

                if result.pValue < 0.05 {
                    Text("统计警示：卡方检验 p < 0.05，说明观测分布与 Benford 期望分布存在显著差异。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                    headerCell("Digit")
                    headerCell("Expected%")
                    headerCell("Observed%")
                    headerCell("Deviation%")
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
        number(value * 100, digits: 2) + "%"
    }

    private func signedPercent(_ value: Double) -> String {
        let formatted = number(abs(value) * 100, digits: 2) + "%"
        return value >= 0 ? "+\(formatted)" : "-\(formatted)"
    }

    private func number(_ value: Double, digits: Int) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(0 ... digits))
        )
    }
}

private struct SummaryItem: Identifiable {
    let title: String
    let value: String

    var id: String { title }
}
