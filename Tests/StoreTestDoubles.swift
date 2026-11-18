import Foundation

// Deliberately small SDK boundaries for exercising the actual GarageStore on macOS.
// These doubles control suspension and auth callbacks; they do not emulate security rules.
struct Timestamp {
    let value: Date
    init(date: Date) { value = date }
    func dateValue() -> Date { value }
}

enum FieldValue {
    static func serverTimestamp() -> Timestamp { Timestamp(date: Date()) }
}

enum FirestoreSource { case server, `default` }
struct FieldPath {
    static func documentID() -> FieldPath { FieldPath() }
}

final class ListenerRegistration {
    var removed = false
    func remove() { removed = true }
}

final class DocumentSnapshot {
    let documentID: String
    private let fields: [String: Any]?
    var exists: Bool { fields != nil }
    init(id: String, data: [String: Any]?) { documentID = id; fields = data }
    func data() -> [String: Any]? { fields }
}

struct QueryDocumentSnapshot {
    let documentID: String
    let fields: [String: Any]
    func data() -> [String: Any] { fields }
}

struct QuerySnapshot { let documents: [QueryDocumentSnapshot] }
enum MockFailure: Error { case network }

@MainActor
final class Suspension {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var entered = false
    func wait() async {
        entered = true
        await withCheckedContinuation { continuation = $0 }
    }
    func resume() { continuation?.resume(); continuation = nil }
}

@MainActor
final class Firestore {
    struct Write { let path: String; let data: [String: Any] }
    static let shared = Firestore()
    static func firestore() -> Firestore { shared }
    var documents: [String: [String: Any]] = [:]
    var writes: [Write] = []
    var readSuspensions: [String: Suspension] = [:]
    var writeSuspensions: [String: Suspension] = [:]
    var failAfterCommit: Set<String> = []

    func reset() {
        documents = [:]; writes = []; readSuspensions = [:]
        writeSuspensions = [:]; failAfterCommit = []
    }
    func collection(_ name: String) -> CollectionReference { CollectionReference(path: name) }
    func batch() -> WriteBatch { WriteBatch() }
    func pauseRead(_ path: String) async {
        if let gate = readSuspensions.removeValue(forKey: path) { await gate.wait() }
    }
    func write(_ data: [String: Any], path: String, merge: Bool) {
        if merge { documents[path, default: [:]].merge(data) { _, new in new } }
        else { documents[path] = data }
        writes.append(Write(path: path, data: data))
    }
    func runTransaction(_ block: (Transaction, UnsafeMutablePointer<NSError?>?) -> Any?) async throws -> Any? {
        var error: NSError?
        let result = withUnsafeMutablePointer(to: &error) { block(Transaction(), $0) }
        if let error { throw error }
        return result
    }
}

@MainActor
class Query {
    let path: String
    var filters: [(String, String)] = []
    var documentFilter: String?
    init(path: String) { self.path = path }
    func whereField(_ field: String, isEqualTo value: Any) -> Query {
        let query = copy()
        query.filters.append((field, String(describing: value)))
        return query
    }
    func whereField(_ field: FieldPath, isEqualTo value: Any) -> Query {
        let query = copy(); query.documentFilter = String(describing: value); return query
    }
    func order(by field: String, descending: Bool) -> Query { copy() }
    func limit(to count: Int) -> Query { copy() }
    private func copy() -> Query {
        let query = Query(path: path); query.filters = filters; query.documentFilter = documentFilter
        return query
    }
    func snapshot() -> QuerySnapshot {
        let prefix = path + "/"
        return QuerySnapshot(documents: Firestore.shared.documents.compactMap { key, value in
            guard key.hasPrefix(prefix), !key.dropFirst(prefix.count).contains("/") else { return nil }
            let id = String(key.dropFirst(prefix.count))
            guard documentFilter == nil || documentFilter == id,
                  filters.allSatisfy({ String(describing: value[$0.0] ?? "") == $0.1 }) else { return nil }
            return QueryDocumentSnapshot(documentID: id, fields: value)
        })
    }
    func getDocuments(source: FirestoreSource = .default) async throws -> QuerySnapshot {
        let captured = snapshot()
        await Firestore.shared.pauseRead(path)
        return captured
    }
    func addSnapshotListener(_ callback: @escaping (QuerySnapshot?, Error?) -> Void) -> ListenerRegistration {
        let registration = ListenerRegistration()
        callback(snapshot(), nil)
        return registration
    }
}

@MainActor
final class CollectionReference: Query {
    func document(_ id: String = UUID().uuidString) -> DocumentReference {
        DocumentReference(path: path + "/" + id)
    }
    @discardableResult
    func addDocument(data: [String: Any]) async throws -> DocumentReference {
        let reference = document(); try await reference.setData(data); return reference
    }
}

@MainActor
final class DocumentReference {
    let path: String
    var documentID: String { String(path.split(separator: "/").last!) }
    init(path: String) { self.path = path }
    func collection(_ name: String) -> CollectionReference { CollectionReference(path: path + "/" + name) }
    func getDocument(source: FirestoreSource = .default) async throws -> DocumentSnapshot {
        let captured = DocumentSnapshot(id: documentID, data: Firestore.shared.documents[path])
        await Firestore.shared.pauseRead(path)
        return captured
    }
    func setData(_ data: [String: Any], merge: Bool = false) async throws {
        if let gate = Firestore.shared.writeSuspensions.removeValue(forKey: path) { await gate.wait() }
        Firestore.shared.write(data, path: path, merge: merge)
        if Firestore.shared.failAfterCommit.remove(path) != nil { throw MockFailure.network }
    }
    func updateData(_ data: [String: Any]) async throws { try await setData(data, merge: true) }
    func delete() async throws { Firestore.shared.documents[path] = nil }
}

@MainActor
final class Transaction {
    func getDocument(_ reference: DocumentReference) throws -> DocumentSnapshot {
        DocumentSnapshot(id: reference.documentID, data: Firestore.shared.documents[reference.path])
    }
    func setData(_ data: [String: Any], forDocument reference: DocumentReference, merge: Bool = false) {
        Firestore.shared.write(data, path: reference.path, merge: merge)
    }
}

@MainActor
final class WriteBatch {
    private var operations: [() -> Void] = []
    func updateData(_ data: [String: Any], forDocument reference: DocumentReference) {
        operations.append { Firestore.shared.write(data, path: reference.path, merge: true) }
    }
    func setData(_ data: [String: Any], forDocument reference: DocumentReference) {
        operations.append { Firestore.shared.write(data, path: reference.path, merge: false) }
    }
    func commit() async throws { operations.forEach { $0() } }
}

typealias AuthStateDidChangeListenerHandle = UUID

@MainActor
final class User {
    let uid: String
    var email: String?
    var displayName: String?
    var phoneNumber: String?
    var isEmailVerified = false
    init(uid: String, email: String? = nil) { self.uid = uid; self.email = email }
    func createProfileChangeRequest() -> UserProfileChangeRequest { UserProfileChangeRequest(user: self) }
    func sendEmailVerification() async throws {}
}

@MainActor
final class UserProfileChangeRequest {
    let user: User
    var displayName: String?
    init(user: User) { self.user = user }
    func commitChanges() async throws { await Task.yield(); user.displayName = displayName }
}

@MainActor
struct AuthDataResult { let user: User }

@MainActor
final class Auth {
    static let shared = Auth()
    static func auth() -> Auth { shared }
    var currentUser: User?
    private var listeners: [UUID: (Auth, User?) -> Void] = [:]
    func reset() { currentUser = nil; listeners = [:] }
    func setUser(_ user: User?) {
        currentUser = user
        for callback in Array(listeners.values) { callback(self, user) }
    }
    func addStateDidChangeListener(_ callback: @escaping (Auth, User?) -> Void) -> UUID {
        let id = UUID(); listeners[id] = callback; callback(self, currentUser); return id
    }
    func removeStateDidChangeListener(_ id: UUID) { listeners[id] = nil }
    func createUser(withEmail email: String, password: String) async throws -> AuthDataResult {
        let user = User(uid: "new-user", email: email)
        setUser(user)
        // The callback runs before createUser returns, as it can in the real SDK.
        await Task.yield()
        return AuthDataResult(user: user)
    }
    func signIn(withEmail email: String, password: String) async throws -> AuthDataResult {
        let user = User(uid: "signed-in-user", email: email); setUser(user); return AuthDataResult(user: user)
    }
    func signIn(with credential: String) async throws -> AuthDataResult {
        try await signIn(withEmail: "google@example.com", password: "")
    }
    func signOut() throws { setUser(nil) }
    func sendPasswordReset(withEmail email: String) async throws {}
}

enum GoogleAuthProvider {
    static func credential(withIDToken: String, accessToken: String) -> String { withIDToken }
}

struct FirebaseOptions { var clientID: String? = "test-client" }
final class FirebaseApp {
    let options = FirebaseOptions()
    static func app() -> FirebaseApp? { FirebaseApp() }
}
enum GarageFirebaseBackend { static let useEmulators = false }

class UIScene {}
class UIViewController {}
final class UIWindow { let isKeyWindow = true; let rootViewController: UIViewController? = UIViewController() }
final class UIWindowScene: UIScene { let windows = [UIWindow()] }
final class UIApplication { static let shared = UIApplication(); let connectedScenes: [UIScene] = [] }
struct GIDConfiguration { init(clientID: String) {} }
struct GIDToken { let tokenString = "token" }
struct GIDGoogleUser { let idToken: GIDToken? = GIDToken(); let accessToken = GIDToken() }
struct GIDSignInResult { let user = GIDGoogleUser() }
final class GIDSignIn {
    static let sharedInstance = GIDSignIn()
    var configuration: GIDConfiguration?
    func signIn(withPresenting presenter: UIViewController) async throws -> GIDSignInResult { GIDSignInResult() }
    func signOut() {}
}
