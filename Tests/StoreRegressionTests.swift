import Foundation
import Darwin

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

@main
@MainActor
struct StoreRegressionTests {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestFailure(description: message) }
    }

    static func eventually(_ message: String, _ condition: () -> Bool) async throws {
        for _ in 0..<1_000 {
            if condition() { return }
            await Task.yield()
        }
        throw TestFailure(description: "Timed out: \(message)")
    }

    static func reset() {
        Auth.shared.reset()
        Firestore.shared.reset()
    }

    static func seedProfile(_ uid: String) {
        Firestore.shared.documents["users/\(uid)"] = [
            "uid": uid, "email": "\(uid)@example.com", "name": "Name \(uid)",
            "phone": "08123456789", "address": "Address \(uid)",
            "role": "user", "profileCompleted": true,
        ]
    }

    static func readyStore(_ uid: String) async throws -> GarageStore {
        seedProfile(uid)
        Auth.shared.currentUser = User(uid: uid, email: "\(uid)@example.com")
        let store = GarageStore()
        try await eventually("resolve \(uid)") {
            store.user?.uid == uid && store.displayName == "Name \(uid)" && !store.isResolvingUser
        }
        return store
    }

    static func signUpProvisionsProfileOnce() async throws {
        reset()
        let store = GarageStore()
        try await store.signUp(name: "  New Customer  ", email: "new@example.com", password: "secret123")
        try await eventually("complete signup session") {
            store.user?.uid == "new-user" && !store.isResolvingUser
        }
        let creations = Firestore.shared.writes.filter {
            $0.path == "users/new-user" && $0.data["createdAt"] != nil
        }
        try expect(creations.count == 1, "Auth callback and signup must provision createdAt exactly once")
        try expect(Firestore.shared.documents["users/new-user"]?["name"] as? String == "New Customer",
                   "Signup must preserve the entered profile name")
        try expect(store.displayName == "New Customer" && !store.profileCompleted,
                   "New accounts must continue to onboarding")
        try expect(store.errorMessage == nil, "Successful signup must not publish a permission/setup error")
        print("PASS signup: callback race provisions profile once")
    }

    static func book(_ store: GarageStore, requestID: String) async throws {
        let vehicle = GarageVehicle(id: "car", data: [
            "userId": "customer", "brand": "Toyota", "model": "Avanza",
            "platNumber": "B 201 AUTO", "year": 2020, "kilometer": 35_000,
        ])!
        try await store.createBooking(service: GarageService.catalog[0], serviceOption: nil,
                                      date: Date().addingTimeInterval(86_400), time: "09:00",
                                      vehicle: vehicle, note: "Check brakes", requestID: requestID)
    }

    static func duplicateAndRetriedBookingCommitOnce() async throws {
        reset()
        let store = try await readyStore("customer")
        let gate = Suspension()
        Firestore.shared.writeSuspensions["bookings/same-request"] = gate
        let first = Task { try await book(store, requestID: "same-request") }
        try await eventually("first booking waits at commit") { gate.entered }
        var duplicateRejected = false
        do { try await book(store, requestID: "same-request") }
        catch { duplicateRejected = true }
        try expect(duplicateRejected, "A simultaneous booking submission must be rejected while the first is pending")
        gate.resume()
        try await first.value
        try await book(store, requestID: "same-request")
        try expect(Firestore.shared.writes.filter { $0.path == "bookings/same-request" }.count == 1,
                   "Retrying an acknowledged request must not write a second booking")

        Firestore.shared.failAfterCommit.insert("bookings/uncertain-request")
        do { try await book(store, requestID: "uncertain-request") }
        catch { /* A lost response can be surfaced or recovered immediately. */ }
        try await book(store, requestID: "uncertain-request")
        try expect(Firestore.shared.writes.filter { $0.path == "bookings/uncertain-request" }.count == 1,
                   "Retry after a lost commit response must recover the existing booking")
        try expect(Firestore.shared.documents.keys.filter { $0.hasPrefix("bookings/") }.count == 2,
                   "Two distinct request IDs must create exactly two bookings")
        try expect(!store.isLoading, "Submitting and retrying must release the loading state")
        print("PASS booking: concurrent taps and lost-response retries commit once per request")
    }

    static func oversizedNumbersAreIgnoredSafely() throws {
        let oversized = NSNumber(value: UInt64.max)
        let floatingOverflow = NSNumber(value: 10_000_000_000_000_000_000.0)
        let booking = GarageBooking(id: "invalid-numbers", data: [
            "serviceName": "Servis",
            "estimatedCost": floatingOverflow,
            "vehicleYear": oversized,
            "vehicleKm": floatingOverflow,
            "currentStep": oversized,
        ])!
        try expect(booking.price == 0, "An out-of-range price must use its safe fallback")
        try expect(booking.vehicleYear == 0 && booking.vehicleKilometer == 0,
                   "Out-of-range vehicle values must use safe fallbacks")
        try expect(booking.progressStep == 1, "An out-of-range progress step must use its safe fallback")
        print("PASS models: out-of-range numeric fields are handled without trapping")
    }

    static func bookingsAreSortedNewestFirstWithLegacyFallback() async throws {
        reset()
        seedProfile("customer")
        Firestore.shared.documents["bookings/newest"] = [
            "userId": "customer", "serviceName": "Newest",
            "createdAt": Timestamp(date: Date(timeIntervalSince1970: 300)),
        ]
        Firestore.shared.documents["bookings/older"] = [
            "userId": "customer", "serviceName": "Older",
            "createdAt": Timestamp(date: Date(timeIntervalSince1970: 200)),
        ]
        Firestore.shared.documents["bookings/legacy-later"] = [
            "userId": "customer", "serviceName": "Legacy later",
            "bookingDate": Timestamp(date: Date(timeIntervalSince1970: 100)),
        ]
        Firestore.shared.documents["bookings/legacy-earlier"] = [
            "userId": "customer", "serviceName": "Legacy earlier",
            "bookingDate": Timestamp(date: Date(timeIntervalSince1970: 50)),
        ]

        let store = try await readyStore("customer")
        try await eventually("booking listener sorts records") {
            store.bookings.map(\.id) == ["newest", "older", "legacy-later", "legacy-earlier"]
        }
        try expect(store.bookings.first?.service == "Newest",
                   "The customer home must receive the most recently created booking first")
        print("PASS booking: newest-first ordering includes a deterministic legacy fallback")
    }

    static func staleLoaderCannotPublishAfterAccountSwitch(path: String) async throws {
        reset()
        seedProfile("account-a")
        seedProfile("account-b")
        Firestore.shared.documents["vehicles/private-car"] = [
            "userId": "account-a", "brand": "Private", "model": "Account A",
            "platNumber": "SECRET A", "year": 2020, "kilometer": 10,
        ]
        Firestore.shared.documents["users/account-a/addresses/private-address"] = [
            "label": "Account A home", "fullAddress": "Private account A address",
        ]
        let gate = Suspension()
        Firestore.shared.readSuspensions[path] = gate
        Auth.shared.currentUser = User(uid: "account-a", email: "a@example.com")
        let store = GarageStore()
        try await eventually("account A loader suspends at \(path)") { gate.entered }
        try store.signOut()
        try await eventually("signout clears current user") { store.user == nil }
        Auth.shared.setUser(User(uid: "account-b", email: "b@example.com"))
        try await eventually("account B finishes loading") {
            store.user?.uid == "account-b" && store.displayName == "Name account-b" && !store.isResolvingUser
        }
        gate.resume()
        // Give the cancelled request and any queued listener callbacks a chance to return.
        for _ in 0..<50 { await Task.yield() }
        try expect(store.user?.uid == "account-b" && store.displayName == "Name account-b",
                   "An old response must not replace the new account")
        try expect(store.vehicles.isEmpty, "Account A vehicle response must not leak into account B")
        try expect(store.addresses.isEmpty, "Account A address response must not leak into account B")
        try expect(store.errorMessage == nil && !store.isResolvingUser,
                   "A stale task must not alter the new session's error/loading state")
        print("PASS session: late \(path) response ignored after signout/account switch")
    }

    static func sameUserReauthenticationRejectsOldOperation() async throws {
        reset()
        let uid = "returning-customer"
        let store = try await readyStore(uid)
        let gate = Suspension()
        Firestore.shared.readSuspensions["vehicles"] = gate
        // A public mutation starts this loader outside the cancellable sign-in task.
        // Comparing UID alone cannot distinguish it from the next login below.
        let oldOperation = Task {
            try await store.addVehicle(brand: "Old", model: "Session", plate: "OLD",
                                       year: 2020, kilometer: 100)
        }
        try await eventually("old mutation waits for its vehicles snapshot") { gate.entered }
        try store.signOut()
        Firestore.shared.documents = Firestore.shared.documents.filter { !$0.key.hasPrefix("vehicles/") }
        Firestore.shared.documents["vehicles/fresh-session"] = [
            "userId": uid, "brand": "Fresh", "model": "Session", "platNumber": "FRESH",
            "year": 2026, "kilometer": 0,
        ]
        Auth.shared.setUser(User(uid: uid, email: "returning@example.com"))
        try await eventually("same UID loads a fresh session") {
            store.user?.uid == uid && !store.isResolvingUser && store.vehicles.map(\.id) == ["fresh-session"]
        }
        gate.resume()
        var oldOperationRejected = false
        do { try await oldOperation.value }
        catch is CancellationError { oldOperationRejected = true }
        try expect(oldOperationRejected, "A mutation from a previous login must not succeed in a new session with the same UID")
        try expect(store.vehicles.map(\.id) == ["fresh-session"],
                   "An old same-UID loader must not replace the fresh session's vehicles")
        print("PASS session: same-UID reauthentication rejects an old mutation/loader")
    }

    static func main() async {
        do {
            try await signUpProvisionsProfileOnce()
            try oversizedNumbersAreIgnoredSafely()
            try await duplicateAndRetriedBookingCommitOnce()
            try await bookingsAreSortedNewestFirstWithLegacyFallback()
            try await staleLoaderCannotPublishAfterAccountSwitch(path: "users/account-a")
            try await staleLoaderCannotPublishAfterAccountSwitch(path: "vehicles")
            try await staleLoaderCannotPublishAfterAccountSwitch(path: "users/account-a/addresses")
            try await sameUserReauthenticationRejectsOldOperation()
            print("All GarageStore regression tests passed.")
        } catch {
            fputs("FAIL: \(error)\n", stderr)
            exit(1)
        }
    }
}
