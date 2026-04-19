import Foundation

enum CellClassification: Equatable {
    case missing
    case nonNumeric
    case numericNonZero(firstDigit: Int)
    case numericZero
}

enum NumberParser {
    private static let missingTokens: Set<String> = [
        "na",
        "n/a",
        "nan",
        "null",
    ]

    static func classify(_ rawValue: String) -> CellClassification {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .missing
        }

        if missingTokens.contains(trimmed.lowercased()) {
            return .missing
        }

        guard let number = Double(trimmed), number.isFinite else {
            return .nonNumeric
        }

        if number == 0 {
            return .numericZero
        }

        guard let firstDigit = firstSignificantDigit(in: number) else {
            return .nonNumeric
        }

        return .numericNonZero(firstDigit: firstDigit)
    }

    static func firstSignificantDigit(in value: Double) -> Int? {
        guard value.isFinite, value != 0 else {
            return nil
        }

        var magnitude = abs(value)
        while magnitude >= 10 {
            magnitude /= 10
        }
        while magnitude > 0 && magnitude < 1 {
            magnitude *= 10
        }

        let digit = Int(magnitude.rounded(.down))
        return (1...9).contains(digit) ? digit : nil
    }
}

enum DelimiterDetector {
    static func detectDelimiter(in fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        let sample = String(decoding: data.prefix(8192), as: UTF8.self)
        let candidates = [",", "\t", ";"]
        let best = candidates.max { lhs, rhs in
            sample.components(separatedBy: lhs).count < sample.components(separatedBy: rhs).count
        }
        return best ?? ","
    }
}

struct SpreadsheetAddress: Equatable {
    let row: Int
    let column: Int
}

enum SpreadsheetAddressParser {
    static func parse(_ rawReference: String) -> SpreadsheetAddress? {
        let cleaned = rawReference
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else {
            return nil
        }

        let letters = cleaned.prefix { $0.isLetter }
        let digits = cleaned.dropFirst(letters.count)

        guard
            !letters.isEmpty,
            let row = Int(digits),
            row > 0
        else {
            return nil
        }

        let column = letters.uppercased().reduce(0) { partial, character in
            let scalar = Int(character.unicodeScalars.first!.value) - 64
            return partial * 26 + scalar
        }

        return column > 0 ? SpreadsheetAddress(row: row, column: column) : nil
    }

    static func parseRange(_ rawReference: String) -> (start: SpreadsheetAddress, end: SpreadsheetAddress)? {
        let pieces = rawReference.split(separator: ":").map(String.init)
        guard
            let start = parse(pieces.first ?? ""),
            let end = parse(pieces.last ?? "")
        else {
            return nil
        }
        return (start: start, end: end)
    }
}
