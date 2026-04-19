import Foundation
import Testing
@testable import BenfordCheck

@Test func firstSignificantDigitHandlesDecimalsAndNegatives() {
    #expect(NumberParser.firstSignificantDigit(in: 1234) == 1)
    #expect(NumberParser.firstSignificantDigit(in: -0.045) == 4)
    #expect(NumberParser.firstSignificantDigit(in: 0.00072) == 7)
    #expect(NumberParser.firstSignificantDigit(in: 0) == nil)
}

@Test func classifyTreatsMissingAndZeroSeparately() {
    #expect(NumberParser.classify(" NA ") == .missing)
    #expect(NumberParser.classify("") == .missing)
    #expect(NumberParser.classify("0") == .numericZero)
    #expect(NumberParser.classify("hello") == .nonNumeric)
    #expect(NumberParser.classify("-203") == .numericNonZero(firstDigit: 2))
}

@Test func benfordAnalyzerProducesExpectedStatus() throws {
    let summary = ScanSummary(
        totalCellCount: 100,
        missingCellCount: 0,
        nonNumericCellCount: 0,
        numericCellCount: 90,
        zeroExcludedCount: 0,
        benfordSampleCount: 90,
        firstDigitCounts: [27, 16, 11, 9, 7, 6, 5, 5, 4],
        rowCount: 10,
        columnCount: 10
    )

    let result = try #require(BenfordAnalyzer.analyze(summary: summary))
    #expect(result.status == .conforms)
    #expect(result.pValue > 0.05)
}

@Test func progressVisibilityPolicyMatchesSpec() {
    #expect(!ProgressVisibilityPolicy.shouldReveal(elapsedSeconds: 2.9, progress: 0.1))
    #expect(!ProgressVisibilityPolicy.shouldReveal(elapsedSeconds: 3.1, progress: 0.5))
    #expect(ProgressVisibilityPolicy.shouldReveal(elapsedSeconds: 3.1, progress: 0.49))
}
