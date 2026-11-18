import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn
import UIKit

struct GarageCustomer: Identifiable {
    let id: String
    let name: String
    let email: String
    let phone: String
    let role: String

    init?(id: String, data: [String: Any]) {
        guard let email = data["email"] as? String else { return nil }
        self.id = id
        name = data["name"] as? String ?? "Pelanggan"
        self.email = email
        phone = data["phone"] as? String ?? "-"
        role = data["role"] as? String ?? "user"
    }
}

@MainActor
final class GarageStore: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var role = "user"
    @Published private(set) var displayName = ""
    @Published private(set) var phone = ""
    @Published private(set) var address = ""
    @Published private(set) var profileCompleted = true
    @Published private(set) var bookings: [GarageBooking] = []
    @Published private(set) var vehicles: [GarageVehicle] = []
    @Published private(set) var addresses: [GarageAddress] = []
    @Published private(set) var promos: [GaragePromo] = []
    @Published private(set) var notifications: [GarageNotification] = []
    @Published private(set) var customers: [GarageCustomer] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isResolvingUser = false
    @Published private(set) var hasProfileLoadError = false
    @Published var errorMessage: String?

    private struct Session: Equatable {
        let uid: String
        let id = UUID()
    }

    private var session: Session?
    private var sessionTask: Task<Void, Error>?
    private var authListener: AuthStateDidChangeListenerHandle?
    private var bookingListener: ListenerRegistration?
    private var notificationListener: ListenerRegistration?
    private var authenticationOperation: UUID?
    private var pendingSignUpName: String?
    private var loadingOperations: Set<UUID> = []
    private var activeBookingOperation: UUID?
    private var completedBookingIDs: Set<String> = []

    var isFirebaseConfigured: Bool { FirebaseApp.app() != nil }
    var isAdmin: Bool { role == "admin" }

    init() {
        guard isFirebaseConfigured else { return }
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.handleAuthStateChange(user) }
        }
    }

    func signIn(email: String, password: String) async throws {
        try ensureFirebase()
        let operation = try beginAuthentication()
        defer { finishAuthentication(operation) }
        _ = try await Auth.auth().signIn(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                         password: password)
    }

    func signInAsAdmin(email: String, password: String) async throws {
        try ensureFirebase()
        let operation = try beginAuthentication()
        defer { finishAuthentication(operation) }
        let credential = try await Auth.auth().signIn(
            withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password
        )
        let signedInUser = credential.user
        do {
            let document = try await Firestore.firestore().collection("users").document(signedInUser.uid)
                .getDocument(source: .server)
            guard Auth.auth().currentUser?.uid == signedInUser.uid else { throw CancellationError() }
            guard document.data()?["role"] as? String == "admin" else {
                throw GarageStoreError.adminAccessRequired
            }
        } catch let signInError {
            if Auth.auth().currentUser?.uid == signedInUser.uid {
                do {
                    try signOut()
                } catch {
                    throw GarageStoreError.adminSignOutFailed(error.localizedDescription)
                }
            }
            throw signInError
        }
    }

    func signUp(name: String, email: String, password: String) async throws {
        try ensureFirebase()
        let operation = try beginAuthentication()
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingSignUpName = cleanName
        defer {
            pendingSignUpName = nil
            // Auth may already have created the account even if its profile update failed.
            // Resolve that account once suppression is released so it remains recoverable.
            if let currentUser = Auth.auth().currentUser, user?.uid != currentUser.uid {
                _ = startSession(for: currentUser, initialName: cleanName)
            }
            finishAuthentication(operation)
        }
        let credential = try await Auth.auth().createUser(
            withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password
        )
        let profileChange = credential.user.createProfileChangeRequest()
        profileChange.displayName = cleanName
        try await profileChange.commitChanges()
        guard Auth.auth().currentUser?.uid == credential.user.uid else { throw CancellationError() }
        if let task = startSession(for: credential.user, initialName: cleanName) {
            try await task.value
        }
    }

    func signInWithGoogle() async throws {
        try ensureFirebase()
        guard !GarageFirebaseBackend.useEmulators else {
            throw GarageStoreError.googleSignInUnavailableInEmulator
        }
        guard let clientID = FirebaseApp.app()?.options.clientID, !clientID.isEmpty else {
            throw GarageStoreError.missingGoogleConfiguration
        }
        let callbackScheme = clientID.split(separator: ".").reversed().joined(separator: ".")
        let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        let schemes = urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        guard schemes.contains(callbackScheme) else { throw GarageStoreError.missingGoogleConfiguration }
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let presenter = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            throw GarageStoreError.missingPresentationContext
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let operation = try beginAuthentication()
        defer { finishAuthentication(operation) }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let idToken = result.user.idToken?.tokenString else {
            throw GarageStoreError.missingGoogleToken
        }
        let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                       accessToken: result.user.accessToken.tokenString)
        _ = try await Auth.auth().signIn(with: credential)
    }

    func resetPassword(email: String) async throws {
        try ensureFirebase()
        try await Auth.auth().sendPasswordReset(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func resendVerificationEmail() async throws {
        let currentSession = try signedInSession()
        guard let user, !user.isEmailVerified else { return }
        try await user.sendEmailVerification()
        try requireCurrentSession(currentSession)
    }

    func signOut() throws {
        try ensureFirebase()
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        _ = startSession(for: nil)
    }

    func retryProfileLoad() async {
        guard let user, Auth.auth().currentUser?.uid == user.uid else { return }
        let initialName = displayName.isEmpty ? user.displayName : displayName
        let task = startSession(for: user, initialName: initialName)
        _ = try? await task?.value
    }

    func updateProfile(name: String, phone: String, address: String) async throws {
        let currentSession = try signedInSession()
        guard let user else { throw GarageStoreError.notSignedIn }
        let operation = beginLoading()
        defer { finishLoading(operation) }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        try await Firestore.firestore().collection("users").document(currentSession.uid).updateData([
            "name": cleanName,
            "phone": cleanPhone,
            "address": cleanAddress,
            "updatedAt": FieldValue.serverTimestamp(),
        ])
        try requireCurrentSession(currentSession)
        let profileChange = user.createProfileChangeRequest()
        profileChange.displayName = cleanName
        try await profileChange.commitChanges()
        try requireCurrentSession(currentSession)
        displayName = cleanName
        self.phone = cleanPhone
        self.address = cleanAddress
    }

    func saveOnboardingProfile(name: String, phone: String, address: String) async throws {
        try await updateProfile(name: name, phone: phone, address: address)
    }

    func completeCustomerOnboarding(brand: String, model: String, plate: String,
                                    year: Int, kilometer: Int) async throws {
        let currentSession = try signedInSession()
        let operation = beginLoading()
        defer { finishLoading(operation) }
        let db = Firestore.firestore()
        let vehicleRef = db.collection("vehicles").document()
        let batch = db.batch()
        batch.updateData([
            "profileCompleted": true,
            "updatedAt": FieldValue.serverTimestamp(),
        ], forDocument: db.collection("users").document(currentSession.uid))
        batch.setData([
            "userId": currentSession.uid,
            "brand": brand.trimmingCharacters(in: .whitespacesAndNewlines),
            "model": model.trimmingCharacters(in: .whitespacesAndNewlines),
            "platNumber": plate.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            "year": year,
            "kilometer": kilometer,
        ], forDocument: vehicleRef)
        try await batch.commit()
        try requireCurrentSession(currentSession)
        await loadVehicles(for: currentSession)
        try requireCurrentSession(currentSession)
        profileCompleted = true
    }

    func addVehicle(brand: String, model: String, plate: String,
                    year: Int, kilometer: Int) async throws {
        let currentSession = try signedInSession()
        try await Firestore.firestore().collection("vehicles").addDocument(data: [
            "userId": currentSession.uid,
            "brand": brand.trimmingCharacters(in: .whitespacesAndNewlines),
            "model": model.trimmingCharacters(in: .whitespacesAndNewlines),
            "platNumber": plate.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            "year": year,
            "kilometer": kilometer,
        ])
        try requireCurrentSession(currentSession)
        await loadVehicles(for: currentSession)
        try requireCurrentSession(currentSession)
    }

    func deleteVehicle(_ vehicle: GarageVehicle) async throws {
        let currentSession = try signedInSession()
        guard vehicle.userId == currentSession.uid else { throw GarageStoreError.notSignedIn }
        try await Firestore.firestore().collection("vehicles").document(vehicle.id).delete()
        try requireCurrentSession(currentSession)
        await loadVehicles(for: currentSession)
        try requireCurrentSession(currentSession)
    }

    func updateVehicle(_ vehicle: GarageVehicle) async throws {
        let currentSession = try signedInSession()
        guard vehicle.userId == currentSession.uid else { throw GarageStoreError.notSignedIn }
        try await Firestore.firestore().collection("vehicles").document(vehicle.id).updateData([
            "brand": vehicle.brand,
            "model": vehicle.model,
            "platNumber": vehicle.plate.uppercased(),
            "year": vehicle.year,
            "kilometer": vehicle.kilometer,
        ])
        try requireCurrentSession(currentSession)
        await loadVehicles(for: currentSession)
        try requireCurrentSession(currentSession)
    }

    func addAddress(label: String, fullAddress: String) async throws {
        let currentSession = try signedInSession()
        try await Firestore.firestore().collection("users").document(currentSession.uid)
            .collection("addresses").addDocument(data: [
                "label": label.trimmingCharacters(in: .whitespacesAndNewlines),
                "fullAddress": fullAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                "createdAt": FieldValue.serverTimestamp(),
            ])
        try requireCurrentSession(currentSession)
        await loadAddresses(for: currentSession)
        try requireCurrentSession(currentSession)
    }

    func deleteAddress(_ address: GarageAddress) async throws {
        let currentSession = try signedInSession()
        try await Firestore.firestore().collection("users").document(currentSession.uid)
            .collection("addresses").document(address.id).delete()
        try requireCurrentSession(currentSession)
        await loadAddresses(for: currentSession)
        try requireCurrentSession(currentSession)
    }

    func createBooking(service: GarageService, serviceOption: String?,
                       date: Date, time: String, vehicle: GarageVehicle,
                       note: String, requestID: String = UUID().uuidString) async throws {
        let currentSession = try signedInSession()
        guard vehicle.userId == currentSession.uid else { throw GarageStoreError.notSignedIn }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedNote.count <= 1000 else { throw GarageStoreError.bookingNoteTooLong }
        guard !completedBookingIDs.contains(requestID) else { return }
        guard activeBookingOperation == nil else { throw GarageStoreError.operationInProgress }
        let operation = beginLoading()
        activeBookingOperation = operation
        defer {
            if activeBookingOperation == operation { activeBookingOperation = nil }
            finishLoading(operation)
        }
        var data: [String: Any] = [
            "userId": currentSession.uid,
            "userName": displayName.isEmpty ? (user?.displayName ?? "Pelanggan") : displayName,
            "userPhone": phone.isEmpty ? (user?.phoneNumber ?? "") : phone,
            "vehicleName": vehicle.title,
            "vehiclePlat": vehicle.plate,
            "vehicleYear": vehicle.year,
            "vehicleKm": vehicle.kilometer,
            "serviceName": service.title,
            "bookingDate": Timestamp(date: date),
            "bookingTime": "\(time) WIB",
            "estimatedCost": Double(service.basePrice),
            "status": "Menunggu",
            "currentStep": 1,
            "totalSteps": 5,
            "notes": trimmedNote.isEmpty ? NSNull() : trimmedNote as Any,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        if let serviceOption { data["serviceOption"] = serviceOption }
        let collection = Firestore.firestore().collection("bookings")
        do {
            try await collection.document(requestID).setData(data)
        } catch {
            try requireCurrentSession(currentSession)
            // An acknowledgement can be lost after a successful create. Querying with
            // the owner constraint also works when the requested ID does not exist;
            // reading a missing document directly is denied by the ownership rules.
            let snapshot = try? await collection.whereField("userId", isEqualTo: currentSession.uid)
                .whereField(FieldPath.documentID(), isEqualTo: requestID).getDocuments(source: .server)
            try requireCurrentSession(currentSession)
            guard snapshot?.documents.contains(where: { $0.documentID == requestID }) == true else {
                throw error
            }
        }
        try requireCurrentSession(currentSession)
        completedBookingIDs.insert(requestID)
    }

    func updateBooking(_ booking: GarageBooking, status: String? = nil,
                       estimatedCost: Int? = nil, currentStep: Int? = nil) async throws {
        let currentSession = try adminSession()
        var updates: [String: Any] = [:]
        if let status { updates["status"] = status }
        if let estimatedCost { updates["estimatedCost"] = Double(estimatedCost) }
        if let currentStep {
            let boundedStep = min(max(currentStep, 0), 5)
            updates["currentStep"] = boundedStep
            updates["status"] = [
                0: "Dibatalkan", 1: "Menunggu", 2: "Proses Pengecekan",
                3: "Sedang Dikerjakan", 4: "Quality Check", 5: "Selesai",
            ][boundedStep]
        }
        guard !updates.isEmpty else { return }
        try await Firestore.firestore().collection("bookings").document(booking.id).updateData(updates)
        try requireCurrentSession(currentSession)
    }

    func deleteBooking(_ booking: GarageBooking) async throws {
        let currentSession = try adminSession()
        guard booking.isActive else { throw GarageStoreError.bookingCannotBeCancelled }
        try await Firestore.firestore().collection("bookings").document(booking.id).updateData([
            "status": "Dibatalkan", "currentStep": 0,
        ])
        try requireCurrentSession(currentSession)
    }

    func cancelBooking(_ booking: GarageBooking) async throws {
        let currentSession = try signedInSession()
        guard booking.userId == currentSession.uid, booking.isActive else {
            throw GarageStoreError.bookingCannotBeCancelled
        }
        try await Firestore.firestore().collection("bookings").document(booking.id).updateData([
            "status": "Dibatalkan", "currentStep": 0,
        ])
        try requireCurrentSession(currentSession)
    }

    func addPromo(title: String, description: String, code: String,
                  discount: String, expiry: String) async throws {
        let currentSession = try adminSession()
        try await Firestore.firestore().collection("promos").addDocument(data: [
            "title": title, "description": description, "code": code,
            "discount": discount, "expiry": expiry, "isActive": true,
            "createdAt": FieldValue.serverTimestamp(),
        ])
        try requireCurrentSession(currentSession)
        await loadPromos(for: currentSession)
        try requireCurrentSession(currentSession)
    }

    func updatePromo(_ promo: GaragePromo, isActive: Bool) async throws {
        let currentSession = try adminSession()
        try await Firestore.firestore().collection("promos").document(promo.id)
            .updateData(["isActive": isActive])
        try requireCurrentSession(currentSession)
        await loadPromos(for: currentSession)
        try requireCurrentSession(currentSession)
    }

    func deletePromo(_ promo: GaragePromo) async throws {
        let currentSession = try adminSession()
        try await Firestore.firestore().collection("promos").document(promo.id).delete()
        try requireCurrentSession(currentSession)
        await loadPromos(for: currentSession)
        try requireCurrentSession(currentSession)
    }

    func refreshAdminData() async {
        guard let currentSession = try? adminSession() else { return }
        await loadPromos(for: currentSession)
        guard isCurrentSession(currentSession) else { return }
        await loadCustomers(for: currentSession)
    }

    func refreshPromos() async {
        guard let currentSession = try? signedInSession() else { return }
        await loadPromos(for: currentSession)
    }

    func markNotificationRead(_ notification: GarageNotification) async throws {
        let currentSession = try signedInSession()
        guard notification.userId == currentSession.uid else { throw GarageStoreError.notificationNotOwned }
        guard !notification.isRead else { return }
        try await Firestore.firestore().collection("notifications").document(notification.id)
            .updateData(["isRead": true])
        try requireCurrentSession(currentSession)
    }

    func markAllNotificationsRead() async throws {
        let currentSession = try signedInSession()
        for notification in notifications where !notification.isRead {
            try requireCurrentSession(currentSession)
            guard notification.userId == currentSession.uid else { throw GarageStoreError.notificationNotOwned }
            try await Firestore.firestore().collection("notifications").document(notification.id)
                .updateData(["isRead": true])
        }
        try requireCurrentSession(currentSession)
    }

    func deleteNotification(_ notification: GarageNotification) async throws {
        let currentSession = try signedInSession()
        guard notification.userId == currentSession.uid else { throw GarageStoreError.notificationNotOwned }
        try await Firestore.firestore().collection("notifications").document(notification.id).delete()
        try requireCurrentSession(currentSession)
    }

    private func handleAuthStateChange(_ user: User?) {
        guard Auth.auth().currentUser?.uid == user?.uid else { return }
        // Signup publishes its session only after the Auth profile is ready. The
        // resolver owns the Firestore profile creation for every authentication path.
        guard user == nil || pendingSignUpName == nil else { return }
        guard self.user?.uid != user?.uid else { return }
        _ = startSession(for: user)
    }

    @discardableResult
    private func startSession(for user: User?, initialName: String? = nil) -> Task<Void, Error>? {
        sessionTask?.cancel()
        sessionTask = nil
        bookingListener?.remove()
        notificationListener?.remove()
        bookingListener = nil
        notificationListener = nil
        session = nil
        self.user = user
        role = "user"
        displayName = ""
        phone = ""
        address = ""
        profileCompleted = user == nil
        bookings = []
        vehicles = []
        addresses = []
        notifications = []
        promos = []
        customers = []
        errorMessage = nil
        hasProfileLoadError = false
        loadingOperations.removeAll()
        activeBookingOperation = nil
        completedBookingIDs.removeAll()
        updateLoadingState()
        isResolvingUser = user != nil
        guard let user else { return nil }
        let currentSession = Session(uid: user.uid)
        session = currentSession
        let task = Task { [weak self] in
            guard let self else { return }
            try await self.loadSignedInState(for: user, session: currentSession, initialName: initialName)
        }
        sessionTask = task
        return task
    }

    private func loadSignedInState(for user: User, session currentSession: Session,
                                   initialName: String?) async throws {
        defer {
            if isCurrentSession(currentSession) { isResolvingUser = false }
        }
        do {
            let data = try await provisionProfile(for: user, session: currentSession, initialName: initialName)
            try requireCurrentSession(currentSession)
            role = data["role"] as? String ?? "user"
            displayName = data["name"] as? String ?? user.displayName ?? ""
            phone = data["phone"] as? String ?? user.phoneNumber ?? ""
            address = data["address"] as? String ?? ""
            profileCompleted = data["profileCompleted"] as? Bool ?? true
            startBookingListener(for: currentSession)
            startNotificationListener(for: currentSession)
            await loadVehicles(for: currentSession)
            try requireCurrentSession(currentSession)
            await loadAddresses(for: currentSession)
            try requireCurrentSession(currentSession)
            if isAdmin {
                await loadPromos(for: currentSession)
                try requireCurrentSession(currentSession)
                await loadCustomers(for: currentSession)
                try requireCurrentSession(currentSession)
            }
        } catch {
            if isCurrentSession(currentSession) {
                hasProfileLoadError = true
                errorMessage = "Tidak dapat memuat profil Firebase: \(error.localizedDescription)"
            }
            throw error
        }
    }

    private func provisionProfile(for user: User, session currentSession: Session,
                                  initialName: String?) async throws -> [String: Any] {
        try requireCurrentSession(currentSession)
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)
        let snapshot = try await userRef.getDocument()
        try requireCurrentSession(currentSession)
        if let data = snapshot.data(), snapshot.exists { return data }
        let newProfile: [String: Any] = [
            "uid": user.uid,
            "email": user.email ?? "",
            "name": initialName ?? user.displayName ?? "",
            "phone": user.phoneNumber ?? "",
            "address": "",
            "role": "user",
            "profileCompleted": false,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        // A transaction prevents a second device or a retry from replacing an
        // existing profile, its role, or its immutable creation timestamp.
        let result = try await db.runTransaction { transaction, errorPointer -> Any? in
            do {
                let current = try transaction.getDocument(userRef)
                if current.exists { return current.data() ?? [:] }
                transaction.setData(newProfile, forDocument: userRef)
                return newProfile
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
        try requireCurrentSession(currentSession)
        guard let data = result as? [String: Any] else { throw GarageStoreError.profileNotLoaded }
        return data
    }

    private func startNotificationListener(for currentSession: Session) {
        guard isCurrentSession(currentSession) else { return }
        notificationListener = Firestore.firestore().collection("notifications")
            .whereField("userId", isEqualTo: currentSession.uid)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self, self.isCurrentSession(currentSession) else { return }
                    if let error {
                        self.errorMessage = "Tidak dapat memuat notifikasi: \(error.localizedDescription)"
                        return
                    }
                    self.notifications = snapshot?.documents.map {
                        GarageNotification(id: $0.documentID, data: $0.data())
                    }.sorted { $0.createdAt > $1.createdAt } ?? []
                }
            }
    }

    private func startBookingListener(for currentSession: Session) {
        guard isCurrentSession(currentSession) else { return }
        let collection = Firestore.firestore().collection("bookings")
        let query = isAdmin ? collection : collection.whereField("userId", isEqualTo: currentSession.uid)
        bookingListener = query.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self, self.isCurrentSession(currentSession) else { return }
                if let error {
                    self.errorMessage = "Tidak dapat memuat booking: \(error.localizedDescription)"
                    return
                }
                self.bookings = (snapshot?.documents.compactMap {
                    GarageBooking(id: $0.documentID, data: $0.data())
                } ?? []).sorted { lhs, rhs in
                    switch (lhs.createdAt, rhs.createdAt) {
                    case let (left?, right?):
                        if left != right { return left > right }
                    case (_?, nil):
                        return true
                    case (nil, _?):
                        return false
                    case (nil, nil):
                        switch (lhs.legacySortDate, rhs.legacySortDate) {
                        case let (left?, right?) where left != right:
                            return left > right
                        case (_?, nil):
                            return true
                        case (nil, _?):
                            return false
                        default:
                            break
                        }
                    }
                    return lhs.id < rhs.id
                }
            }
        }
    }

    private func loadVehicles(for currentSession: Session) async {
        guard isCurrentSession(currentSession) else { return }
        do {
            let snapshot = try await Firestore.firestore().collection("vehicles")
                .whereField("userId", isEqualTo: currentSession.uid).getDocuments()
            guard isCurrentSession(currentSession), !Task.isCancelled else { return }
            vehicles = snapshot.documents.compactMap {
                GarageVehicle(id: $0.documentID, data: $0.data())
            }.sorted { $0.year > $1.year }
        } catch {
            guard isCurrentSession(currentSession), !Task.isCancelled else { return }
            errorMessage = "Tidak dapat memuat kendaraan: \(error.localizedDescription)"
        }
    }

    private func loadAddresses(for currentSession: Session) async {
        guard isCurrentSession(currentSession) else { return }
        do {
            let snapshot = try await Firestore.firestore().collection("users").document(currentSession.uid)
                .collection("addresses").getDocuments()
            guard isCurrentSession(currentSession), !Task.isCancelled else { return }
            addresses = snapshot.documents.compactMap {
                GarageAddress(id: $0.documentID, data: $0.data())
            }
        } catch {
            guard isCurrentSession(currentSession), !Task.isCancelled else { return }
            errorMessage = "Tidak dapat memuat alamat: \(error.localizedDescription)"
        }
    }

    private func loadPromos(for currentSession: Session) async {
        guard isCurrentSession(currentSession) else { return }
        do {
            let snapshot = try await Firestore.firestore().collection("promos")
                .order(by: "createdAt", descending: true).getDocuments()
            guard isCurrentSession(currentSession), !Task.isCancelled else { return }
            promos = snapshot.documents.compactMap {
                GaragePromo(id: $0.documentID, data: $0.data())
            }
        } catch {
            guard isCurrentSession(currentSession), !Task.isCancelled else { return }
            errorMessage = "Tidak dapat memuat promo: \(error.localizedDescription)"
        }
    }

    private func loadCustomers(for currentSession: Session) async {
        guard isCurrentSession(currentSession), isAdmin else { return }
        do {
            let snapshot = try await Firestore.firestore().collection("users").getDocuments()
            guard isCurrentSession(currentSession), isAdmin, !Task.isCancelled else { return }
            customers = snapshot.documents.compactMap {
                GarageCustomer(id: $0.documentID, data: $0.data())
            }.filter { $0.role != "admin" }
        } catch {
            guard isCurrentSession(currentSession), !Task.isCancelled else { return }
            errorMessage = "Tidak dapat memuat pelanggan: \(error.localizedDescription)"
        }
    }

    private func signedInSession() throws -> Session {
        try ensureFirebase()
        guard let session, isCurrentSession(session) else { throw GarageStoreError.notSignedIn }
        guard !hasProfileLoadError else { throw GarageStoreError.profileNotLoaded }
        try Task.checkCancellation()
        return session
    }

    private func adminSession() throws -> Session {
        let currentSession = try signedInSession()
        guard isAdmin else { throw GarageStoreError.adminAccessRequired }
        return currentSession
    }

    private func isCurrentSession(_ candidate: Session) -> Bool {
        session == candidate && user?.uid == candidate.uid && Auth.auth().currentUser?.uid == candidate.uid
    }

    private func requireCurrentSession(_ candidate: Session) throws {
        try Task.checkCancellation()
        guard isCurrentSession(candidate) else { throw CancellationError() }
    }

    private func beginAuthentication() throws -> UUID {
        guard authenticationOperation == nil else { throw GarageStoreError.operationInProgress }
        let operation = UUID()
        authenticationOperation = operation
        updateLoadingState()
        return operation
    }

    private func finishAuthentication(_ operation: UUID) {
        guard authenticationOperation == operation else { return }
        authenticationOperation = nil
        updateLoadingState()
    }

    private func beginLoading() -> UUID {
        let operation = UUID()
        loadingOperations.insert(operation)
        updateLoadingState()
        return operation
    }

    private func finishLoading(_ operation: UUID) {
        loadingOperations.remove(operation)
        updateLoadingState()
    }

    private func updateLoadingState() {
        isLoading = authenticationOperation != nil || !loadingOperations.isEmpty
    }

    private func ensureFirebase() throws {
        guard isFirebaseConfigured else { throw GarageStoreError.firebaseNotConfigured }
    }
}

enum GarageStoreError: LocalizedError {
    case firebaseNotConfigured
    case missingGoogleConfiguration
    case missingPresentationContext
    case missingGoogleToken
    case googleSignInUnavailableInEmulator
    case notSignedIn
    case adminAccessRequired
    case adminSignOutFailed(String)
    case bookingCannotBeCancelled
    case notificationNotOwned
    case operationInProgress
    case profileNotLoaded
    case bookingNoteTooLong

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured:
            return "Firebase belum dikonfigurasi. Tambahkan GoogleService-Info.plist ke target AutoGarage."
        case .missingGoogleConfiguration:
            return "Konfigurasi Google Sign-In belum lengkap. Periksa Client ID dan URL scheme callback di target iOS."
        case .missingPresentationContext:
            return "Layar masuk Google tidak dapat dibuka saat ini."
        case .missingGoogleToken:
            return "Google tidak mengembalikan token autentikasi."
        case .googleSignInUnavailableInEmulator:
            return "Gunakan email dan password saat memakai Firebase Emulator."
        case .notSignedIn:
            return "Silakan masuk terlebih dahulu."
        case .adminAccessRequired:
            return "Akun ini tidak memiliki akses administrator."
        case .adminSignOutFailed(let message):
            return "Akun admin gagal dikeluarkan setelah validasi gagal: \(message)"
        case .bookingCannotBeCancelled:
            return "Booking yang sudah selesai atau dibatalkan tidak dapat diubah."
        case .operationInProgress:
            return "Permintaan sebelumnya masih diproses. Tunggu hingga selesai."
        case .profileNotLoaded:
            return "Profil belum dapat dimuat. Coba muat ulang akun terlebih dahulu."
        case .bookingNoteTooLong:
            return "Catatan booking maksimal 1.000 karakter."
        case .notificationNotOwned:
            return "Notifikasi ini bukan milik akun Anda."
        }
    }
}
