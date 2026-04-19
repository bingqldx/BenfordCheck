import CoreXLSX
import Foundation

struct WorkbookInspector {
    func sheetNames(at fileURL: URL) throws -> [String] {
        guard let file = XLSXFile(filepath: fileURL.path) else {
            throw AnalysisError.workbookLoadFailed
        }
        guard let workbook = try file.parseWorkbooks().first else {
            throw AnalysisError.workbookMissing
        }

        let sheetPairs = try file.parseWorksheetPathsAndNames(workbook: workbook)
        let names = sheetPairs.enumerated().map { index, pair in
            pair.name ?? "Sheet \(index + 1)"
        }
        guard !names.isEmpty else {
            throw AnalysisError.noWorksheetAvailable
        }
        return names
    }
}

struct XLSXScanner: TabularScanner {
    func scan(
        request: AnalysisRequest,
        onProgress: @escaping @Sendable (ScanProgress) async -> Void
    ) async throws -> ScanSummary {
        guard let requestedSheetName = request.selectedSheetName else {
            throw AnalysisError.noWorksheetAvailable
        }

        await onProgress(.init(fraction: 0.05, stage: "打开 xlsx 文件"))

        guard let file = XLSXFile(filepath: request.fileURL.path) else {
            throw AnalysisError.workbookLoadFailed
        }

        await onProgress(.init(fraction: 0.15, stage: "解析工作簿"))

        guard let workbook = try file.parseWorkbooks().first else {
            throw AnalysisError.workbookMissing
        }

        let sharedStrings = try file.parseSharedStrings()
        let sheetPairs = try file.parseWorksheetPathsAndNames(workbook: workbook)
        guard !sheetPairs.isEmpty else {
            throw AnalysisError.noWorksheetAvailable
        }

        let resolvedSheet = sheetPairs.enumerated().first { index, pair in
            let name = pair.name ?? "Sheet \(index + 1)"
            return name == requestedSheetName
        }
        guard let resolvedSheet else {
            throw AnalysisError.worksheetMissing(requestedSheetName)
        }

        await onProgress(.init(fraction: 0.25, stage: "读取工作表"))

        let worksheet = try file.parseWorksheet(at: resolvedSheet.element.path)
        let rows = worksheet.data?.rows ?? []
        var accumulator = ScanAccumulator()

        if
            let dimensionReference = worksheet.dimension?.reference,
            let parsedRange = SpreadsheetAddressParser.parseRange(String(describing: dimensionReference))
        {
            accumulator.mergeDimension(start: parsedRange.start, end: parsedRange.end)
        }

        let denominator = max(rows.count, 1)
        for (index, row) in rows.enumerated() {
            for cell in row.cells {
                let rawReference = String(describing: cell.reference)
                guard let address = SpreadsheetAddressParser.parse(rawReference) else {
                    continue
                }

                let rawValue = resolveStringValue(for: cell, sharedStrings: sharedStrings)
                accumulator.registerCell(row: address.row, column: address.column, rawValue: rawValue)
            }

            let progress = 0.25 + (0.65 * Double(index + 1) / Double(denominator))
            await onProgress(.init(fraction: progress, stage: "正在扫描工作表"))
        }

        await onProgress(.init(fraction: 1, stage: "分析完成"))
        return accumulator.makeSummary()
    }

    private func resolveStringValue(for cell: Cell, sharedStrings: SharedStrings?) -> String {
        if let sharedStrings, let stringValue = cell.stringValue(sharedStrings) {
            return stringValue
        }

        if let inlineText = cell.inlineString?.text {
            return inlineText
        }

        return cell.value ?? ""
    }
}
