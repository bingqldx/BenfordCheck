import Foundation

enum BenfordAnalyzer {
    static let expectedRatios: [Double] = (1...9).map { digit in
        log10(1 + (1 / Double(digit)))
    }

    static func analyze(summary: ScanSummary) -> BenfordAnalysisResult? {
        guard summary.benfordSampleCount > 0 else {
            return nil
        }

        let sampleCount = Double(summary.benfordSampleCount)
        let observedRatios = summary.firstDigitCounts.map { Double($0) / sampleCount }
        let deviations = zip(observedRatios, expectedRatios).map { observed, expected in
            observed - expected
        }
        let mad = zip(observedRatios, expectedRatios)
            .map { abs($0 - $1) }
            .reduce(0, +) / Double(expectedRatios.count)

        let chiSquare = zip(summary.firstDigitCounts, expectedRatios)
            .map { observed, expectedRatio in
                let expectedCount = sampleCount * expectedRatio
                let delta = Double(observed) - expectedCount
                return (delta * delta) / expectedCount
            }
            .reduce(0.0, +)

        let pValue = Statistics.chiSquareSurvivalFunction(value: chiSquare, degreesOfFreedom: 8)
        let status: BenfordStatus
        switch mad {
        case ...0.012:
            status = .conforms
        case ...0.015:
            status = .borderline
        default:
            status = .nonConforms
        }

        return BenfordAnalysisResult(
            expectedRatios: expectedRatios,
            observedRatios: observedRatios,
            deviations: deviations,
            mad: mad,
            chiSquare: chiSquare,
            pValue: pValue,
            status: status
        )
    }
}

enum Statistics {
    private static let lanczosCoefficients: [Double] = [
        676.5203681218851,
        -1259.1392167224028,
        771.3234287776531,
        -176.6150291621406,
        12.507343278686905,
        -0.13857109526572012,
        9.984369578019572e-6,
        1.5056327351493116e-7,
    ]

    static func chiSquareSurvivalFunction(value: Double, degreesOfFreedom: Int) -> Double {
        guard value >= 0, degreesOfFreedom > 0 else { return 1 }
        return regularizedGammaQ(shape: Double(degreesOfFreedom) / 2, x: value / 2)
    }

    static func regularizedGammaQ(shape: Double, x: Double) -> Double {
        guard shape > 0 else { return 1 }
        guard x > 0 else { return 1 }

        if x < shape + 1 {
            return 1 - regularizedGammaPSeries(shape: shape, x: x)
        }
        return regularizedGammaQContinuedFraction(shape: shape, x: x)
    }

    private static func regularizedGammaPSeries(shape: Double, x: Double) -> Double {
        let epsilon = 1e-12
        let maxIterations = 2000

        var sum = 1 / shape
        var term = sum
        var n = 1.0

        while n < Double(maxIterations) {
            term *= x / (shape + n)
            sum += term
            if abs(term) < abs(sum) * epsilon {
                break
            }
            n += 1
        }

        let logScale = -x + shape * log(x) - logGamma(shape)
        return exp(logScale) * sum
    }

    private static func regularizedGammaQContinuedFraction(shape: Double, x: Double) -> Double {
        let epsilon = 1e-12
        let tiny = 1e-30
        let maxIterations = 2000

        var b = x + 1 - shape
        var c = 1 / tiny
        var d = 1 / max(b, tiny)
        var h = d

        for iteration in 1...maxIterations {
            let i = Double(iteration)
            let an = -i * (i - shape)
            b += 2
            d = an * d + b
            if abs(d) < tiny { d = tiny }
            c = b + an / c
            if abs(c) < tiny { c = tiny }
            d = 1 / d
            let delta = d * c
            h *= delta
            if abs(delta - 1) < epsilon {
                break
            }
        }

        let logScale = -x + shape * log(x) - logGamma(shape)
        return exp(logScale) * h
    }

    private static func logGamma(_ value: Double) -> Double {
        if value < 0.5 {
            return log(.pi) - log(sin(.pi * value)) - logGamma(1 - value)
        }

        let adjusted = value - 1
        var x = 0.9999999999998099

        for (index, coefficient) in lanczosCoefficients.enumerated() {
            x += coefficient / (adjusted + Double(index) + 1)
        }

        let t = adjusted + Double(lanczosCoefficients.count) - 0.5
        return 0.5 * log(2 * .pi) + (adjusted + 0.5) * log(t) - t + log(x)
    }
}
