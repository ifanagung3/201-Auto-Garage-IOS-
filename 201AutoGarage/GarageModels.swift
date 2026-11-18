import Foundation
import FirebaseFirestore

private func garageText(_ value: Any?) -> String? {
    if let text = value as? String { return text }
    if let number = value as? NSNumber { return number.stringValue }
    if let date = value as? Date {
        return ISO8601DateFormatter().string(from: date)
    }
    return nil
}

private func garageInt(_ value: Any?) -> Int? {
    switch value {
    case let int as Int:
        return int
    case let int64 as Int64:
        return Int(exactly: int64)
    case let uint as UInt:
        return Int(exactly: uint)
    case let number as NSNumber:
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return nil
        }
        if let integer = Int(number.stringValue) {
            return integer
        }
        return Int(exactly: number.doubleValue)
    case let text as String:
        return Int(text)
    default:
        return nil
    }
}

private func garageDate(_ value: Any?) -> Date? {
    if let stamp = value as? Timestamp { return stamp.dateValue() }
    if let date = value as? Date { return date }
    if let text = value as? String {
        let iso = ISO8601DateFormatter()
        if let parsed = iso.date(from: text) { return parsed }
        let alternate = DateFormatter()
        alternate.locale = Locale(identifier: "en_US_POSIX")
        alternate.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let parsed = alternate.date(from: text) { return parsed }
    }
    return nil
}

private func garageDateString(_ value: Any?) -> String? {
    if let date = garageDate(value) {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
    return garageText(value)
}

struct GarageService: Identifiable, Hashable {
    let title: String
    let description: String
    let priceLabel: String
    let basePrice: Int
    let group: String
    let icon: String
    let priceNote: String?
    let estimationCategory: String?
    let options: [String]

    init(title: String, description: String, priceLabel: String, basePrice: Int,
         group: String, icon: String, priceNote: String? = nil,
         estimationCategory: String? = nil, options: [String] = []) {
        self.title = title
        self.description = description
        self.priceLabel = priceLabel
        self.basePrice = basePrice
        self.group = group
        self.icon = icon
        self.priceNote = priceNote
        self.estimationCategory = estimationCategory
        self.options = options
    }

    var id: String { title }
    var price: Int { basePrice }

    static let catalog = [
        GarageService(title: "Servis Berkala", description: "Tune-up, pembersihan throttle body, pemeriksaan 40 titik dan sistem rem.", priceLabel: "Rp 350.000", basePrice: 350_000, group: "Servis Rutin", icon: "wrench.and.screwdriver.fill", estimationCategory: "Servis Rutin", options: []),
        GarageService(title: "Ganti Oli Mesin & Transmisi", description: "Pilihan oli sesuai spesifikasi kendaraan dan penggantian filter oli.", priceLabel: "Rp 150.000 (jasa)", basePrice: 150_000, group: "Servis Rutin", icon: "drop.fill", priceNote: "Harga jasa; oli dan filter mengikuti pilihan kendaraan.", estimationCategory: "Servis Rutin", options: []),
        GarageService(title: "Overhaul Mesin (Turun Mesin)", description: "Pemeriksaan ruang bakar, skir klep, packing, piston dan komponen mesin.", priceLabel: "Rp 2.500.000", basePrice: 2_500_000, group: "Servis Rutin", icon: "gearshape.2.fill", priceNote: "Harga awal; kebutuhan suku cadang ditentukan setelah pemeriksaan.", estimationCategory: "Overhaul Mesin", options: []),
        GarageService(title: "Perawatan Sistem Rem & Understeel", description: "Pemeriksaan rem, kampas, bushing arm dan shock absorber.", priceLabel: "Rp 200.000", basePrice: 200_000, group: "Servis Rutin", icon: "car.side.rear.open.fill", priceNote: "Harga awal; suku cadang dapat dikenakan biaya terpisah.", estimationCategory: "Kaki-kaki", options: []),
        GarageService(title: "AC Service", description: "Pembersihan dan pengisian freon AC.", priceLabel: "Rp 200.000", basePrice: 200_000, group: "Servis Rutin", icon: "snowflake", estimationCategory: "AC Service", options: []),
        GarageService(title: "Tune Up", description: "Pembersihan mesin dan penyetelan performa.", priceLabel: "Rp 300.000", basePrice: 300_000, group: "Servis Rutin", icon: "slider.horizontal.3", estimationCategory: "Tune Up", options: []),
        GarageService(title: "Ganti Ban", description: "Penggantian dan balancing ban mobil.", priceLabel: "Rp 400.000", basePrice: 400_000, group: "Servis Rutin", icon: "circle.dotted", estimationCategory: "Ganti Ban", options: []),
        GarageService(title: "Tuning ECU & Remap Stage 1 / 2", description: "Optimasi kurva torsi dan tenaga; dyno baseline termasuk.", priceLabel: "Rp 800.000–2.500.000", basePrice: 800_000, group: "Performa & Diesel", icon: "cpu", priceNote: "Harga akhir mengikuti kendaraan dan pilihan stage.", options: ["Stage 1", "Stage 2"]),
        GarageService(title: "Purging Diesel & Kalibrasi Injektor", description: "Pembersihan deposit solar common rail tanpa bongkar mesin.", priceLabel: "Rp 450.000", basePrice: 450_000, group: "Performa & Diesel", icon: "drop.degreesign.fill"),
        GarageService(title: "Pemasangan Downpipe Stainless 304", description: "Pilihan PnP untuk Innova, Fortuner dan Pajero; konfirmasi kecocokan kendaraan.", priceLabel: "Rp 1.450.000", basePrice: 1_450_000, group: "Performa & Diesel", icon: "wind"),
    ]
}

struct GarageBooking: Identifiable, Hashable {
    let id: String
    let userId: String
    let customerName: String
    let customerPhone: String
    let service: String
    let serviceOption: String?
    let date: String
    let time: String
    let price: Int
    let vehicle: String
    let vehiclePlate: String
    let vehicleYear: Int
    let vehicleKilometer: Int
    let note: String
    let status: String
    let estimate: Int?
    let progressStep: Int
    let createdAt: Date?

    init?(id: String, data: [String: Any]) {
        guard let service = garageText(data["serviceName"]) ?? garageText(data["service"]) else { return nil }
        self.id = id
        userId = garageText(data["userId"]) ?? ""
        customerName = garageText(data["userName"]) ?? garageText(data["customerName"]) ?? ""
        customerPhone = garageText(data["userPhone"]) ?? ""
        self.service = service
        serviceOption = garageText(data["serviceOption"]) ?? garageText(data["option"])
        date = garageDateString(data["bookingDate"]) ?? garageText(data["date"]) ?? ""
        time = (garageText(data["bookingTime"]) ?? garageText(data["time"]) ?? "").replacingOccurrences(of: " WIB", with: "")
        let cost = garageInt(data["estimatedCost"]) ?? garageInt(data["price"]) ?? 0
        price = cost
        estimate = garageInt(data["estimate"])
        vehicle = garageText(data["vehicleName"]) ?? garageText(data["vehicle"]) ?? ""
        vehiclePlate = garageText(data["vehiclePlat"]) ?? garageText(data["vehiclePlate"]) ?? ""
        vehicleYear = garageInt(data["vehicleYear"]) ?? 0
        vehicleKilometer = garageInt(data["vehicleKm"]) ?? garageInt(data["vehicleKilometer"]) ?? 0
        note = garageText(data["notes"]) ?? garageText(data["note"]) ?? ""
        status = garageText(data["status"]) ?? "Menunggu"
        progressStep = min(max(garageInt(data["currentStep"]) ?? garageInt(data["progressStep"]) ?? 1, 0), 5)
        createdAt = garageDate(data["createdAt"])
    }

    var legacySortDate: Date? { garageDate(date) }

    var isActive: Bool { !["Selesai", "Dibatalkan", "selesai", "dibatalkan"].contains(status) }
    var isHistory: Bool { !isActive }
}

struct GarageVehicle: Identifiable, Hashable {
    let id: String
    var brand: String
    var model: String
    var plate: String
    var year: Int
    var kilometer: Int
    let userId: String

    var title: String { "\(brand) \(model)" }
    var fullName: String { "\(brand) \(model) (\(year))" }

    init?(id: String, data: [String: Any]) {
        guard let brand = garageText(data["brand"]) ?? garageText(data["brandName"]),
              let plate = garageText(data["platNumber"]) ?? garageText(data["plate"]) else { return nil }
        self.id = id
        self.brand = brand
        model = garageText(data["model"]) ?? ""
        self.plate = plate
        year = garageInt(data["year"]) ?? 2020
        kilometer = garageInt(data["kilometer"]) ?? garageInt(data["km"]) ?? 0
        userId = garageText(data["userId"]) ?? ""
    }
}

struct GarageAddress: Identifiable, Hashable {
    let id: String
    let label: String
    let fullAddress: String

    init?(id: String, data: [String: Any]) {
        guard let label = garageText(data["label"]),
              let fullAddress = garageText(data["fullAddress"]) ?? garageText(data["address"]) else { return nil }
        self.id = id
        self.label = label
        self.fullAddress = fullAddress
    }
}

struct GaragePromo: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let code: String
    let discount: String
    let expiry: String
    let isActive: Bool

    init?(id: String, data: [String: Any]) {
        guard let title = garageText(data["title"]) else { return nil }
        self.id = id
        self.title = title
        description = garageText(data["description"]) ?? ""
        code = garageText(data["code"]) ?? ""
        discount = garageText(data["discount"]) ?? ""
        expiry = garageText(data["expiry"]) ?? ""
        isActive = data["isActive"] as? Bool ?? (data["active"] as? Bool) ?? true
    }
}

struct GarageNotification: Identifiable, Hashable {
    let id: String
    let userId: String
    let title: String
    let message: String
    let createdAt: Date
    let category: String
    let isRead: Bool

    init(id: String, data: [String: Any]) {
        self.id = id
        userId = garageText(data["userId"]) ?? ""
        title = garageText(data["title"]) ?? ""
        message = garageText(data["message"]) ?? ""
        createdAt = garageDate(data["createdAt"]) ?? .distantPast
        category = garageText(data["category"]) ?? "Info"
        isRead = (data["isRead"] as? Bool) ?? (data["read"] as? Bool) ?? false
    }
}

enum CustomerTab: Hashable {
    case home, status, history, account
}

enum AdminTab: Hashable {
    case dashboard, bookings, services, more
}

func rupiah(_ amount: Int) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "id_ID")
    formatter.numberStyle = .currency
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: amount)) ?? "Rp \(amount)"
}

func bookingDate(_ value: String) -> String {
    let input = ISO8601DateFormatter()
    guard let date = input.date(from: value) else { return value }
    let output = DateFormatter()
    output.locale = Locale(identifier: "id_ID")
    output.dateStyle = .long
    return output.string(from: date)
}
