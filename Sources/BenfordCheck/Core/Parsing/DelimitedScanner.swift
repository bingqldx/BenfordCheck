import CodableCSV
import Foundation

struct DelimitedScanner: TabularScanner {
    func scan(
        request: AnalysisRequest,
        onProgress: @escaping @Sendable (ScanProgress) async -> Void
    ) async throws -> ScanSummary {
        guard let delimiter = request.sourceKind.delimiter else {
            throw AnalysisError.invalidDelimitedConfiguration
        }
        guard let stream = CountingInputStream(url: request.fileURL) else {
            throw AnalysisError.cannotOpenFile(request.fileURL)
        }

        let totalBytes = try Int64(request.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        await onProgress(.init(fraction: 0.01, stage: "准备读取文本表格"))

        let reader = try CSVReader(input: stream) {
            $0.delimiters.field = Delimiter.Field(delimiter)!
            $0.headerStrategy = .none
            $0.presample = false
        }

        var accumulator = ScanAccumulator()
        var rowIndex = 0
        var lastReportedFraction = -1.0

        while let row = try reader.readRow() {
            rowIndex += 1
            accumulator.registerRow(rowIndex: rowIndex, values: row)

            if totalBytes > 0 {
                let fraction = min(0.95, Double(stream.bytesRead) / Double(totalBytes))
                if fraction - lastReportedFraction >= 0.01 || fraction >= 0.95 {
                    lastReportedFraction = fraction
                    await onProgress(.init(fraction: fraction, stage: "正在扫描文本表格"))
                }
            }
        }

        await onProgress(.init(fraction: 1, stage: "分析完成"))
        return accumulator.makeSummary()
    }
}

struct ScanAccumulator {
    private(set) var encounteredCellCount = 0
    private(set) var explicitMissingCount = 0
    private(set) var nonNumericCellCount = 0
    private(set) var numericCellCount = 0
    private(set) var zeroExcludedCount = 0
    private(set) var benfordSampleCount = 0
    private(set) var firstDigitCounts = Array(repeating: 0, count: 9)
    private(set) var minRow = Int.max
    private(set) var maxRow = 0
    private(set) var minColumn = Int.max
    private(set) var maxColumn = 0

    mutating func registerRow(rowIndex: Int, values: [String]) {
        guard !values.isEmpty else {
            updateBounds(row: rowIndex, column: 1)
            return
        }

        for (offset, value) in values.enumerated() {
            registerCell(row: rowIndex, column: offset + 1, rawValue: value)
        }
    }

    mutating func registerCell(row: Int, column: Int, rawValue: String) {
        encounteredCellCount += 1
        updateBounds(row: row, column: column)

        switch NumberParser.classify(rawValue) {
        case .missing:
            explicitMissingCount += 1
        case .nonNumeric:
            nonNumericCellCount += 1
        case let .numericNonZero(firstDigit):
            numericCellCount += 1
            benfordSampleCount += 1
            firstDigitCounts[firstDigit - 1] += 1
        case .numericZero:
            numericCellCount += 1
            zeroExcludedCount += 1
        }
    }

    mutating func updateBounds(row: Int, column: Int) {
        minRow = min(minRow, row)
        maxRow = max(maxRow, row)
        minColumn = min(minColumn, column)
        maxColumn = max(maxColumn, column)
    }

    mutating func mergeDimension(start: SpreadsheetAddress, end: SpreadsheetAddress) {
        minRow = min(minRow, start.row)
        maxRow = max(maxRow, end.row)
        minColumn = min(minColumn, start.column)
        maxColumn = max(maxColumn, end.column)
    }

    func makeSummary() -> ScanSummary {
        let rowCount = maxRow == 0 ? 0 : (maxRow - effectiveMinRow + 1)
        let columnCount = maxColumn == 0 ? 0 : (maxColumn - effectiveMinColumn + 1)
        let totalCellCount = rowCount * columnCount
        let impliedMissingCount = max(0, totalCellCount - encounteredCellCount)

        return ScanSummary(
            totalCellCount: totalCellCount,
            missingCellCount: explicitMissingCount + impliedMissingCount,
            nonNumericCellCount: nonNumericCellCount,
            numericCellCount: numericCellCount,
            zeroExcludedCount: zeroExcludedCount,
            benfordSampleCount: benfordSampleCount,
            firstDigitCounts: firstDigitCounts,
            rowCount: rowCount,
            columnCount: columnCount
        )
    }

    private var effectiveMinRow: Int {
        minRow == Int.max ? 1 : minRow
    }

    private var effectiveMinColumn: Int {
        minColumn == Int.max ? 1 : minColumn
    }
}
