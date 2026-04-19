import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class AnalysisViewModel {
    var status: AnalysisStatus = .idle
    var isImporterPresented = false
    var isDropTargeted = false
    var isProgressVisible = false
    var scanProgress = 0.0
    var scanStage = ""
    var importedFileName = ""
    var availableSheets: [String] = []
    var selectedSheetName = ""
    var outcome: AnalysisOutcome?

    var allowedContentTypes: [UTType] {
        ["csv", "tsv", "txt", "xlsx"].compactMap { UTType(filenameExtension: $0) }
    }

    private let workbookInspector = WorkbookInspector()
    private let delimitedScanner = DelimitedScanner()
    private let xlsxScanner = XLSXScanner()
    private var pendingRequest: AnalysisRequest?
    private var progressStartDate: Date?
    private var revealProgressTask: Task<Void, Never>?

    var digitRows: [DigitDeviationRow] {
        guard let result = outcome?.result else { return [] }
        return (1...9).map { digit in
            DigitDeviationRow(
                digit: digit,
                expectedRatio: result.expectedRatios[digit - 1],
                observedRatio: result.observedRatios[digit - 1],
                deviation: result.deviations[digit - 1]
            )
        }
    }

    func presentImporter() {
        status = .selectingFile
        isImporterPresented = true
    }

    func handleImporterResult(_ result: Result<URL, Error>) {
        switch result {
        case let .success(url):
            prepareImport(from: url)
        case let .failure(error):
            fail(with: error.localizedDescription)
        }
    }

    func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSURL.self) }) else {
            fail(with: AnalysisError.dropLoadFailed.localizedDescription)
            return false
        }

        provider.loadObject(ofClass: NSURL.self) { [weak self] item, _ in
            guard let self else { return }

            let resolvedURL: URL?
            if let url = item as? URL {
                resolvedURL = url
            } else if let nsURL = item as? NSURL {
                resolvedURL = nsURL as URL
            } else {
                resolvedURL = nil
            }

            guard let url = resolvedURL else {
                Task { @MainActor [weak self] in
                    self?.fail(with: AnalysisError.dropLoadFailed.localizedDescription)
                }
                return
            }

            Task { @MainActor [weak self] in
                self?.prepareImport(from: url)
            }
        }
        return true
    }

    func confirmSheetSelection() {
        guard let pendingRequest else { return }
        let request = AnalysisRequest(
            fileURL: pendingRequest.fileURL,
            sourceKind: pendingRequest.sourceKind,
            selectedSheetName: selectedSheetName
        )
        startAnalysis(using: request)
    }

    private func prepareImport(from url: URL) {
        importedFileName = url.lastPathComponent
        pendingRequest = nil
        availableSheets = []
        selectedSheetName = ""
        outcome = nil

        Task {
            do {
                let sourceKind = try SourceKind.infer(from: url)
                let request = AnalysisRequest(fileURL: url, sourceKind: sourceKind, selectedSheetName: nil)

                if case .xlsx = sourceKind {
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer {
                        if accessed {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }

                    let sheets = try workbookInspector.sheetNames(at: url)
                    if sheets.count == 1, let sheet = sheets.first {
                        startAnalysis(
                            using: AnalysisRequest(fileURL: url, sourceKind: sourceKind, selectedSheetName: sheet)
                        )
                    } else {
                        pendingRequest = request
                        availableSheets = sheets
                        selectedSheetName = sheets.first ?? ""
                        status = .selectingSheet
                    }
                } else {
                    startAnalysis(using: request)
                }
            } catch {
                fail(with: error.localizedDescription)
            }
        }
    }

    private func startAnalysis(using request: AnalysisRequest) {
        outcome = nil
        status = .scanning(progress: 0)
        scanProgress = 0
        scanStage = "准备分析"
        isProgressVisible = false
        progressStartDate = Date()
        revealProgressTask?.cancel()
        revealProgressTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                guard let self else { return }
                if case let .scanning(progress) = self.status,
                   ProgressVisibilityPolicy.shouldReveal(elapsedSeconds: 3, progress: progress) {
                    self.isProgressVisible = true
                }
            }
        }

        let scanner = scanner(for: request.sourceKind)
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let accessed = request.fileURL.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    request.fileURL.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let summary = try await scanner.scan(request: request) { [weak self] progress in
                    await self?.receiveProgress(progress)
                }
                let result = BenfordAnalyzer.analyze(summary: summary)
                await MainActor.run {
                    self.revealProgressTask?.cancel()
                    self.availableSheets = []
                    self.pendingRequest = nil
                    self.outcome = AnalysisOutcome(summary: summary, result: result)
                    self.status = .finished
                    self.isProgressVisible = false
                    self.scanProgress = 1
                    self.scanStage = summary.benfordSampleCount == 0 ? "没有可计算的非零数值" : "分析完成"
                }
            } catch {
                await MainActor.run {
                    self.fail(with: error.localizedDescription)
                }
            }
        }
    }

    private func scanner(for sourceKind: SourceKind) -> any TabularScanner {
        switch sourceKind {
        case .xlsx:
            return xlsxScanner
        case .delimited:
            return delimitedScanner
        }
    }

    private func receiveProgress(_ progress: ScanProgress) {
        scanProgress = progress.fraction
        scanStage = progress.stage
        status = .scanning(progress: progress.fraction)

        if isProgressVisible {
            return
        }

        if let progressStartDate {
            let elapsed = Date().timeIntervalSince(progressStartDate)
            if ProgressVisibilityPolicy.shouldReveal(elapsedSeconds: elapsed, progress: progress.fraction) {
                isProgressVisible = true
            }
        }
    }

    private func fail(with message: String) {
        revealProgressTask?.cancel()
        isProgressVisible = false
        outcome = nil
        availableSheets = []
        pendingRequest = nil
        status = .failed(message: message)
        scanStage = ""
        scanProgress = 0
    }
}
