import Foundation
import Testing
@testable import BenfordCheck

@Test func delimitedScannerCountsMissingNonNumericAndBenfordSamples() async throws {
    let csv = """
    label,a,b,c
    row1,1,2,
    row2,NA,hello,30
    row3,-4.5,0,7e2
    """

    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("csv")
    try csv.write(to: fileURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let request = AnalysisRequest(
        fileURL: fileURL,
        sourceKind: .delimited(fileExtension: "csv", delimiter: ","),
        selectedSheetName: nil
    )

    let summary = try await DelimitedScanner().scan(request: request) { _ in }

    #expect(summary.rowCount == 4)
    #expect(summary.columnCount == 4)
    #expect(summary.totalCellCount == 16)
    #expect(summary.missingCellCount == 2)
    #expect(summary.nonNumericCellCount == 8)
    #expect(summary.numericCellCount == 6)
    #expect(summary.zeroExcludedCount == 1)
    #expect(summary.benfordSampleCount == 5)
    #expect(summary.firstDigitCounts[0] == 1)
    #expect(summary.firstDigitCounts[1] == 1)
    #expect(summary.firstDigitCounts[2] == 1)
    #expect(summary.firstDigitCounts[3] == 1)
    #expect(summary.firstDigitCounts[6] == 1)
}

@Test func workbookInspectorFindsMultipleSheets() throws {
    let fileURL = try #require(Bundle.module.url(forResource: "multi-sheet", withExtension: "xlsx"))
    let names = try WorkbookInspector().sheetNames(at: fileURL)

    #expect(names == ["Sheet1", "Sheet2"])
}

@Test func xlsxScannerScansOnlySelectedWorksheet() async throws {
    let fileURL = try #require(Bundle.module.url(forResource: "multi-sheet", withExtension: "xlsx"))
    let request = AnalysisRequest(fileURL: fileURL, sourceKind: .xlsx, selectedSheetName: "Sheet2")

    let summary = try await XLSXScanner().scan(request: request) { _ in }

    #expect(summary.rowCount == 3)
    #expect(summary.columnCount == 3)
    #expect(summary.totalCellCount == 9)
    #expect(summary.missingCellCount == 4)
    #expect(summary.nonNumericCellCount == 2)
    #expect(summary.numericCellCount == 3)
    #expect(summary.zeroExcludedCount == 1)
    #expect(summary.benfordSampleCount == 2)
    #expect(summary.firstDigitCounts[0] == 1)
    #expect(summary.firstDigitCounts[4] == 1)
}
