import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import SwiftUI

enum GarageFirebaseBackend {
    static let useEmulators: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--use-firebase-emulators")
            || ProcessInfo.processInfo.environment["USE_FIREBASE_EMULATORS"] == "true"
        #else
        return false
        #endif
    }()

    static let emulatorHost: String = {
        let host = ProcessInfo.processInfo.environment["FIREBASE_EMULATOR_HOST"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return host.isEmpty ? "127.0.0.1" : host
    }()

    static func configure() {
        if FirebaseApp.app() == nil {
            if useEmulators {
                let options = FirebaseOptions(
                    googleAppID: "1:1234567890:ios:1234567890abcdef",
                    gcmSenderID: "1234567890"
                )
                options.apiKey = "demo-api-key"
                options.projectID = "demo-autogarage"
                FirebaseApp.configure(options: options)
            } else if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
                FirebaseApp.configure()
            }
        }

        guard useEmulators, FirebaseApp.app() != nil else { return }
        Auth.auth().useEmulator(withHost: emulatorHost, port: 9099)

        let firestore = Firestore.firestore()
        let settings = firestore.settings
        settings.cacheSettings = MemoryCacheSettings()
        firestore.settings = settings
        firestore.useEmulator(withHost: emulatorHost, port: 8080)
    }
}

@main
struct AutoGarageApp: App {
    @StateObject private var store: GarageStore

    init() {
        GarageFirebaseBackend.configure()
        _store = StateObject(wrappedValue: GarageStore())
    }

    var body: some Scene {
        WindowGroup {
            GarageRootView()
                .environmentObject(store)
                .tint(GarageColor.primary)
                .fontDesign(.rounded)
                .onOpenURL { _ = GIDSignIn.sharedInstance.handle($0) }
        }
    }
}

private struct GarageRootView: View {
    @EnvironmentObject private var store: GarageStore
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false

    var body: some View {
        Group {
            if !didCompleteOnboarding {
                GarageOnboardingView()
            } else if store.user == nil {
                SignInView()
            } else if store.isResolvingUser {
                ProgressView("Memuat akun...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(GarageColor.background)
            } else if store.hasProfileLoadError {
                ContentUnavailableView {
                    Label("Akun belum dapat dimuat", systemImage: "person.crop.circle.badge.exclamationmark")
                } description: {
                    Text("Periksa koneksi Anda, lalu coba muat akun kembali.")
                } actions: {
                    Button("Coba Lagi") {
                        Task { await store.retryProfileLoad() }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Keluar", role: .destructive) {
                        do { try store.signOut() }
                        catch { store.errorMessage = error.localizedDescription }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(GarageColor.background)
            } else if store.isAdmin {
                AdminShellView()
            } else if !store.profileCompleted {
                CustomerSetupView()
            } else {
                CustomerShellView()
            }
        }
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
        .safeAreaInset(edge: .top, spacing: 0) {
            if GarageFirebaseBackend.useEmulators {
                HStack {
                    Spacer()
                    Text("LOKAL · demo-autogarage")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(GarageColor.warning, in: Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .background(GarageColor.background)
            }
        }
        .alert("Informasi", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("Tutup", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}
