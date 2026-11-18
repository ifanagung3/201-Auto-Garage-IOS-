import SwiftUI
import UIKit

enum GarageColor {
    static let primary = Color(red: 1, green: 59 / 255, blue: 69 / 255)
    static let indigo = Color(red: 185 / 255, green: 28 / 255, blue: 44 / 255)
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 17 / 255, green: 21 / 255, blue: 28 / 255, alpha: 1)
            : UIColor(red: 246 / 255, green: 247 / 255, blue: 249 / 255, alpha: 1)
    })
    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 26 / 255, green: 32 / 255, blue: 41 / 255, alpha: 1)
            : .white
    })
    static let border = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 42 / 255, green: 49 / 255, blue: 60 / 255, alpha: 1)
            : UIColor(red: 229 / 255, green: 231 / 255, blue: 235 / 255, alpha: 1)
    })
    static let text = Color(uiColor: .label)
    static let secondary = Color(uiColor: .secondaryLabel)
    static let success = Color(red: 16 / 255, green: 185 / 255, blue: 129 / 255)
    static let warning = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)
    static let error = primary
    static let adminBackground = Color(red: 17 / 255, green: 21 / 255, blue: 28 / 255)
    static let adminSurface = Color(red: 26 / 255, green: 32 / 255, blue: 41 / 255)
    static let adminOrange = primary
    static let authBackground = Color(red: 11 / 255, green: 14 / 255, blue: 19 / 255)
    static let authInput = Color(red: 23 / 255, green: 28 / 255, blue: 36 / 255)
    static let authOutline = Color(red: 42 / 255, green: 49 / 255, blue: 60 / 255)
    static let authInk = Color(red: 242 / 255, green: 244 / 255, blue: 247 / 255)
    static let authMuted = Color(red: 156 / 255, green: 166 / 255, blue: 181 / 255)
}

struct GarageCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GarageColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(GarageColor.border, lineWidth: 1)
            }
    }
}

struct GaragePrimaryButton: View {
    let title: String
    var isLoading = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading { ProgressView().tint(.white) }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(.white)
            .background(GarageColor.primary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isLoading)
    }
}

struct GaragePageTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 24, weight: .bold)).foregroundStyle(GarageColor.text)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(GarageColor.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GarageStatusBadge: View {
    let status: String

    private var color: Color {
        switch status.lowercased() {
        case "selesai": GarageColor.success
        case "proses", "proses pengecekan", "sedang dikerjakan", "quality check": GarageColor.primary
        case "menunggu": GarageColor.warning
        case "dibatalkan": GarageColor.error
        default: GarageColor.secondary
        }
    }

    var body: some View {
        Text(status.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }
}
