import Foundation

struct GarageEstimateInput {
    let category: String
    let year: Int
    let kilometer: Int
    let replaceEngineOil: Bool
    let replaceFilter: Bool
    let replaceBrakePad: Bool
    let replaceSparkPlugs: Bool
}

struct GarageEstimate {
    let estimatedCost: Int
    let minCost: Int
    let maxCost: Int
    let laborCost: Int
    let sparepartCost: Int
    let durationMinutes: Int
}

private indirect enum EstimateTree {
    case leaf(Double)
    case split(Int, Double, EstimateTree, EstimateTree)

    func predict(_ features: [Double]) -> Double {
        switch self {
        case .leaf(let value):
            value
        case .split(let feature, let threshold, let left, let right):
            features[feature] <= threshold ? left.predict(features) : right.predict(features)
        }
    }
}

enum GarageEstimator {
    static let categories = [
        "Servis Rutin", "Tune Up", "AC Service", "Ganti Ban", "Kaki-kaki", "Overhaul Mesin",
    ]

    private static let trees: [EstimateTree] = [
        .split(0, 1.5, .split(1, 2, .leaf(150_000), .leaf(220_000)), .split(0, 3.5, .leaf(350_000), .leaf(550_000))),
        .split(3, 50_000, .split(2, 5, .leaf(140_000), .leaf(190_000)), .split(2, 8, .leaf(280_000), .leaf(420_000))),
        .split(0, 2.5, .split(2, 4, .leaf(160_000), .leaf(240_000)), .split(3, 80_000, .leaf(400_000), .leaf(620_000))),
        .split(4, 0.5, .split(0, 1.5, .leaf(130_000), .leaf(300_000)), .split(5, 0.5, .leaf(310_000), .leaf(480_000))),
        .split(6, 0.5, .split(0, 3.5, .leaf(200_000), .leaf(500_000)), .split(3, 60_000, .leaf(370_000), .leaf(550_000))),
        .split(2, 7, .split(0, 1.5, .leaf(145_000), .leaf(270_000)), .split(0, 4.5, .leaf(360_000), .leaf(700_000))),
        .split(3, 30_000, .leaf(155_000), .split(3, 100_000, .leaf(290_000), .leaf(530_000))),
        .split(0, 0.5, .split(3, 40_000, .leaf(135_000), .leaf(175_000)), .split(0, 4.5, .leaf(320_000), .leaf(650_000))),
        .split(7, 0.5, .split(4, 0.5, .leaf(170_000), .leaf(340_000)), .split(6, 0.5, .leaf(380_000), .leaf(520_000))),
        .split(0, 3.5, .split(4, 0.5, .leaf(160_000), .leaf(310_000)), .split(5, 0.5, .leaf(490_000), .leaf(680_000))),
        .split(2, 10, .split(6, 0.5, .leaf(195_000), .leaf(395_000)), .split(0, 2.5, .leaf(310_000), .leaf(720_000))),
        .split(3, 70_000, .split(2, 6, .leaf(165_000), .leaf(255_000)), .split(0, 2.5, .leaf(330_000), .leaf(610_000))),
        .split(0, 4.5, .split(0, 1.5, .leaf(155_000), .leaf(295_000)), .leaf(780_000)),
        .split(3, 55_000, .split(2, 3, .leaf(140_000), .leaf(210_000)), .split(2, 9, .leaf(350_000), .leaf(570_000))),
        .split(4, 0.5, .split(7, 0.5, .leaf(148_000), .leaf(268_000)), .split(6, 0.5, .leaf(320_000), .leaf(490_000))),
    ]

    static func predict(_ input: GarageEstimateInput) -> GarageEstimate {
        let categoryIndex = Double(categories.firstIndex(of: input.category) ?? 0)
        let ageYears = Double(min(max(Calendar.current.component(.year, from: Date()) - input.year, 0), 30))
        let features: [Double] = [
            categoryIndex, 0, ageYears, Double(max(input.kilometer, 0)),
            input.replaceEngineOil ? 1 : 0,
            input.replaceFilter ? 1 : 0,
            input.replaceBrakePad ? 1 : 0,
            input.replaceSparkPlugs ? 1 : 0,
        ]
        let forestAverage = trees.map { $0.predict(features) }.reduce(0, +) / Double(trees.count)

        let laborCost: Int
        let durationMinutes: Int
        switch input.category {
        case "Tune Up": (laborCost, durationMinutes) = (150_000, 90)
        case "AC Service": (laborCost, durationMinutes) = (120_000, 60)
        case "Ganti Ban": (laborCost, durationMinutes) = (50_000, 30)
        case "Kaki-kaki": (laborCost, durationMinutes) = (250_000, 120)
        case "Overhaul Mesin": (laborCost, durationMinutes) = (800_000, 300)
        default: (laborCost, durationMinutes) = (75_000, 45)
        }

        let sparepartCost = (input.replaceEngineOil ? 180_000 : 0)
            + (input.replaceFilter ? 65_000 : 0)
            + (input.replaceBrakePad ? 220_000 : 0)
            + (input.replaceSparkPlugs ? 120_000 : 0)
        let estimate = Int(((forestAverage + Double(laborCost + sparepartCost)) / 5_000).rounded()) * 5_000
        let minimum = Int((Double(estimate) * 0.9 / 5_000).rounded()) * 5_000
        let maximum = Int((Double(estimate) * 1.1 / 5_000).rounded()) * 5_000

        return GarageEstimate(
            estimatedCost: estimate,
            minCost: minimum,
            maxCost: maximum,
            laborCost: laborCost,
            sparepartCost: sparepartCost,
            durationMinutes: durationMinutes
        )
    }
}
