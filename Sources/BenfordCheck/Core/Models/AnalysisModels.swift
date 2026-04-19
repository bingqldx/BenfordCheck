import Foundation

enum AnalysisStatus: Equatable, Sendable {
    case idle
    case selectingFile
    case selectingSheet
    case scanning(progress: Double)
    case finished
    case failed(message: String)
}

enum SourceKind: Equatable, Sendable {
    case delimited(fileExtension: String, delimiter: String)
    case xlsx

    static func infer(from fileURL: URL) throws -> SourceKind {
        let fileExtension = fileURL.pathExtension.lowercased()
        switch fileExtension {
        case "csv":
            return .delimited(fileExtension: fileExtension, delimiter: ",")
        case "tsv":
            return .delimited(fileExtension: fileExtension, delimiter: "\t")
        case "txt":
            return .delimited(
                fileExtension: fileExtension,
                delimiter: try DelimiterDetector.detectDelimiter(in: fileURL)
            )
        case "xlsx":
            return .xlsx
        default:
            throw AnalysisError.unsupportedFileType(fileExtension.isEmpty ? fileURL.lastPathComponent : fileExtension)
        }
    }

    var delimiter: String? {
        switch self {
        case let .delimited(_, delimiter):
            return delimiter
        case .xlsx:
            return nil
        }
    }
}

struct AnalysisRequest: Sendable {
    let fileURL: URL
    let sourceKind: SourceKind
    let selectedSheetName: String?
}

struct ScanProgress: Sendable, Equatable {
    let fraction: Double
    let stage: String

    init(fraction: Double, stage: String) {
        self.fraction = min(max(fraction, 0), 1)
        self.stage = stage
    }
}

struct ScanSummary: Sendable, Equatable {
    let totalCellCount: Int
    let missingCellCount: Int
    let nonNumericCellCount: Int
    let numericCellCount: Int
    let zeroExcludedCount: Int
    let benfordSampleCount: Int
    let firstDigitCounts: [Int]
    let rowCount: Int
    let columnCount: Int
}

struct AnalysisOutcome: Sendable, Equatable {
    let summary: ScanSummary
    let result: BenfordAnalysisResult?
}

enum BenfordStatus: String, Sendable, Equatable {
    case conforms = "符合"
    case borderline = "边界"
    case nonConforms = "不符合"

    var badgeColorName: String {
        switch self {
        case .conforms:
            return "green"
        case .borderline:
            return "orange"
        case .nonConforms:
            return "red"
        }
    }
}

struct BenfordAnalysisResult: Sendable, Equatable {
    let expectedRatios: [Double]
    let observedRatios: [Double]
    let deviations: [Double]
    let mad: Double
    let chiSquare: Double
    let pValue: Double
    let status: BenfordStatus
}

struct DigitDeviationRow: Identifiable, Sendable, Equatable {
    let digit: Int
    let expectedRatio: Double
    let observedRatio: Double
    let deviation: Double

    var id: Int { digit }
}

enum AnalysisError: LocalizedError, Equatable {
    case unsupportedFileType(String)
    case invalidDelimitedConfiguration
    case cannotOpenFile(URL)
    case workbookLoadFailed
    case workbookMissing
    case worksheetMissing(String)
    case noWorksheetAvailable
    case dropLoadFailed
    case unreadableContent(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedFileType(fileType):
            return "暂不支持文件类型：\(fileType)。目前支持 csv、tsv、txt、xlsx。"
        case .invalidDelimitedConfiguration:
            return "文本表格的分隔符配置无效。"
        case let .cannotOpenFile(url):
            return "无法读取文件：\(url.lastPathComponent)。"
        case .workbookLoadFailed:
            return "无法打开 xlsx 文件。"
        case .workbookMissing:
            return "xlsx 文件里没有可读取的工作簿。"
        case let .worksheetMissing(name):
            return "没有找到工作表“\(name)”。"
        case .noWorksheetAvailable:
            return "这个 xlsx 文件里没有可分析的工作表。"
        case .dropLoadFailed:
            return "拖拽的文件无法读取，请改用文件选择。"
        case let .unreadableContent(message):
            return message
        }
    }
}

protocol TabularScanner: Sendable {
    func scan(
        request: AnalysisRequest,
        onProgress: @escaping @Sendable (ScanProgress) async -> Void
    ) async throws -> ScanSummary
}

struct ProgressVisibilityPolicy {
    static func shouldReveal(elapsedSeconds: TimeInterval, progress: Double) -> Bool {
        elapsedSeconds >= 3 && progress < 0.5
    }
}
