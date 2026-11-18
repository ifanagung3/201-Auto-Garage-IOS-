import SwiftUI

struct GarageOnboardingView: View {
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @AppStorage("openSignUpAfterOnboarding") private var openSignUpAfterOnboarding = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
            VStack(spacing: 10) {
                Text("Drive Better, We Care")
                    .font(.title2.bold())
                    .foregroundStyle(GarageColor.authInk)
                Text("Mudah booking, harga transparan, layanan terpercaya.")
                    .font(.subheadline)
                    .foregroundStyle(GarageColor.authMuted)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            GaragePrimaryButton(title: "Masuk") {
                openSignUpAfterOnboarding = false
                didCompleteOnboarding = true
            }
            Button("Daftar Akun") {
                openSignUpAfterOnboarding = true
                didCompleteOnboarding = true
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(GarageColor.authInk)
        }
        .padding(24)
        .background(GarageColor.authBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

struct SignInView: View {
    @EnvironmentObject private var store: GarageStore
    @AppStorage("openSignUpAfterOnboarding") private var openSignUpAfterOnboarding = false
    @State private var email = ""
    @State private var password = ""
    @State private var message: String?
    @State private var showingSignUp = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    BrandHeader()
                    VStack(spacing: 8) {
                        Text("Selamat Datang Kembali")
                            .font(.system(size: 24, weight: .bold))
                            .tracking(-0.4)
                            .foregroundStyle(GarageColor.authInk)
                            .multilineTextAlignment(.center)
                        Text("Masuk ke akun Anda menggunakan email atau akun sosial")
                            .font(.subheadline)
                            .foregroundStyle(GarageColor.authMuted)
                            .multilineTextAlignment(.center)
                    }
                    VStack(spacing: 14) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .garageField()
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .garageField()
                        HStack {
                            Spacer()
                            NavigationLink("Lupa password?") { ForgotPasswordView() }
                                .font(.subheadline.weight(.semibold))
                        }
                    }

                    GaragePrimaryButton(title: "Login", isLoading: store.isLoading) {
                        Task {
                            do { try await store.signIn(email: email, password: password) }
                            catch { message = error.localizedDescription }
                        }
                    }

                    if !GarageFirebaseBackend.useEmulators {
                        HStack {
                            Rectangle().fill(GarageColor.border).frame(height: 1)
                            Text("atau").font(.caption).foregroundStyle(GarageColor.secondary)
                            Rectangle().fill(GarageColor.border).frame(height: 1)
                        }
                        Button {
                            Task {
                                do { try await store.signInWithGoogle() }
                                catch { message = error.localizedDescription }
                            }
                        } label: {
                            Label("Masuk dengan Google", systemImage: "g.circle.fill")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(GarageColor.surface, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(GarageColor.border))
                        }
                        .disabled(store.isLoading)
                    }

                    HStack {
                        Spacer()
                        Text("Belum punya akun?")
                        NavigationLink("Daftar") { SignUpView() }.fontWeight(.semibold)
                        Spacer()
                    }
                    .font(.subheadline)
                    .foregroundStyle(GarageColor.secondary)
                    NavigationLink {
                        AdminLoginView()
                    } label: {
                        Label("Login khusus admin", systemImage: "lock.shield")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }

                    if !store.isFirebaseConfigured {
                        Label("Firebase belum dikonfigurasi. Lihat README untuk menambahkan konfigurasi iOS.",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(GarageColor.warning)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(GarageColor.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 29)
                .padding(.top, 40)
                .padding(.bottom, 32)
            }
            .background(GarageColor.authBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .alert("Login gagal", isPresented: messageBinding) {
                Button("Tutup", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
            .navigationDestination(isPresented: $showingSignUp) {
                SignUpView()
            }
            .onAppear {
                guard openSignUpAfterOnboarding else { return }
                openSignUpAfterOnboarding = false
                showingSignUp = true
            }
        }
        .preferredColorScheme(.dark)
    }

    private var messageBinding: Binding<Bool> {
        Binding(get: { message != nil }, set: { if !$0 { message = nil } })
    }
}

private struct BrandHeader: View {
    var body: some View {
        Image("BrandLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 132, height: 132)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Logo 201 Auto Garage")
    }
}

struct SignUpView: View {
    @EnvironmentObject private var store: GarageStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var message: String?

    var body: some View {
        Form {
            Section("Data akun") {
                TextField("Nama lengkap", text: $name)
                    .textContentType(.name)
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                SecureField("Password (min. 6 karakter)", text: $password)
                    .textContentType(.newPassword)
            }
            Section {
                GaragePrimaryButton(title: "Buat akun", isLoading: store.isLoading) {
                    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          password.count >= 6 else {
                        message = "Masukkan nama dan password minimal 6 karakter."
                        return
                    }
                    Task {
                        do {
                            try await store.signUp(name: name, email: email, password: password)
                        } catch { message = error.localizedDescription }
                    }
                }
                .listRowBackground(Color.clear)
            }
            Section {
                Text("Dengan mendaftar, Anda dapat membuat booking dan melihat status servis kendaraan.")
                    .font(.footnote)
                    .foregroundStyle(GarageColor.secondary)
            }
        }
        .navigationTitle("Daftar")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Informasi akun", isPresented: messageBinding) {
            Button("OK") { message = nil; if store.user != nil { dismiss() } }
        } message: { Text(message ?? "") }
    }

    private var messageBinding: Binding<Bool> {
        Binding(get: { message != nil }, set: { if !$0 { message = nil } })
    }
}

struct CustomerSetupView: View {
    @EnvironmentObject private var store: GarageStore
    @State private var step = 0
    @State private var name = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var brand = ""
    @State private var model = ""
    @State private var plate = ""
    @State private var year = "2020"
    @State private var kilometer = "0"
    @State private var message: String?

    private var validVehicle: Bool {
        guard let year = Int(year), let kilometer = Int(kilometer) else { return false }
        return (1980...Calendar.current.component(.year, from: Date()) + 1).contains(year)
            && (0...2_000_000).contains(kilometer)
    }

    var body: some View {
        NavigationStack {
            Form {
                if step == 0 {
                    Section("Profil pelanggan") {
                        TextField("Nama lengkap", text: $name)
                            .textContentType(.name)
                        TextField("Nomor telepon", text: $phone)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                        TextField("Alamat", text: $address, axis: .vertical)
                            .lineLimit(2...4)
                    }
                    Section {
                        GaragePrimaryButton(title: "Lanjut ke kendaraan", isLoading: store.isLoading) {
                            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                  !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                  !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                                message = "Nama, nomor telepon, dan alamat wajib diisi."
                                return
                            }
                            Task {
                                do {
                                    try await store.saveOnboardingProfile(
                                        name: name, phone: phone, address: address
                                    )
                                    step = 1
                                } catch {
                                    message = error.localizedDescription
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section("Kendaraan pertama") {
                        TextField("Merek kendaraan", text: $brand)
                        TextField("Model kendaraan", text: $model)
                        TextField("Nomor polisi", text: $plate)
                            .textInputAutocapitalization(.characters)
                        TextField("Tahun", text: $year)
                            .keyboardType(.numberPad)
                        TextField("Kilometer", text: $kilometer)
                            .keyboardType(.numberPad)
                    }
                    Section {
                        GaragePrimaryButton(title: "Simpan dan mulai", isLoading: store.isLoading) {
                            guard !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                  !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                  !plate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                  validVehicle,
                                  let parsedYear = Int(year),
                                  let parsedKilometer = Int(kilometer) else {
                                message = "Lengkapi data kendaraan dengan tahun dan kilometer yang valid."
                                return
                            }
                            Task {
                                do {
                                    try await store.completeCustomerOnboarding(
                                        brand: brand,
                                        model: model,
                                        plate: plate,
                                        year: parsedYear,
                                        kilometer: parsedKilometer
                                    )
                                } catch {
                                    message = error.localizedDescription
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle(step == 0 ? "Lengkapi Profil" : "Tambah Kendaraan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step == 1 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Kembali") { step = 0 }
                            .disabled(store.isLoading)
                    }
                }
            }
            .alert("Lengkapi pendaftaran", isPresented: Binding(
                get: { message != nil }, set: { if !$0 { message = nil } }
            )) {
                Button("Tutup", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
            .onAppear {
                if name.isEmpty { name = store.displayName }
                if phone.isEmpty { phone = store.phone }
                if address.isEmpty { address = store.address }
            }
        }
    }
}

private struct ForgotPasswordView: View {
    @EnvironmentObject private var store: GarageStore
    @State private var email = ""
    @State private var message: String?

    var body: some View {
        Form {
            Section("Reset password") {
                TextField("Email akun", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
            Section {
                Button("Kirim tautan reset") {
                    Task {
                        do {
                            try await store.resetPassword(email: email)
                            message = "Tautan reset password telah dikirim."
                        } catch { message = error.localizedDescription }
                    }
                }
            }
        }
        .navigationTitle("Lupa Password")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset password", isPresented: Binding(
            get: { message != nil }, set: { if !$0 { message = nil } }
        )) {
            Button("Tutup", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }
}

private struct AdminLoginView: View {
    @EnvironmentObject private var store: GarageStore
    @State private var email = ""
    @State private var password = ""
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Label("Portal Administrator", systemImage: "person.badge.key.fill")
                    .font(.headline)
                    .foregroundStyle(GarageColor.adminOrange)
                Text("Masuk menggunakan akun yang telah diberi role admin di Firestore.")
                    .font(.footnote).foregroundStyle(GarageColor.secondary)
            }
            Section("Akun admin") {
                TextField("Email admin", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .textContentType(.emailAddress)
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }
            Section {
                GaragePrimaryButton(title: "Login Admin", isLoading: store.isLoading) {
                    Task {
                        do { try await store.signInAsAdmin(email: email, password: password) }
                        catch { message = error.localizedDescription }
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Admin")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Login Admin", isPresented: Binding(
            get: { message != nil }, set: { if !$0 { message = nil } }
        )) {
            Button("Tutup", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }
}

struct CustomerShellView: View {
    @State private var selectedTab: CustomerTab = .home
    @State private var showingBookingFlow = false
    @State private var pendingBookingService: GarageService?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                CustomerHomeView(
                    onBook: { service in
                        pendingBookingService = service
                        showingBookingFlow = true
                    },
                    onStatus: { selectedTab = .status }
                )
                .navigationDestination(isPresented: $showingBookingFlow) {
                    BookingFlowView(selectedTab: $selectedTab,
                                    pendingService: $pendingBookingService,
                                    isPresented: $showingBookingFlow)
                }
            }
            .tabItem { Label("Beranda", systemImage: "house") }
            .tag(CustomerTab.home)

            NavigationStack {
                CustomerBookingListView(mode: .status)
            }
            .tabItem { Label("Status", systemImage: "doc.text") }
            .tag(CustomerTab.status)

            NavigationStack {
                CustomerBookingListView(mode: .history)
            }
            .tabItem { Label("Riwayat", systemImage: "clock.arrow.circlepath") }
            .tag(CustomerTab.history)

            NavigationStack {
                AccountView()
            }
            .tabItem { Label("Akun", systemImage: "person.crop.circle") }
            .tag(CustomerTab.account)
        }
        .tint(GarageColor.primary)
    }
}

private struct CustomerHomeView: View {
    @EnvironmentObject private var store: GarageStore
    @State private var searchText = ""
    let onBook: (GarageService?) -> Void
    let onStatus: () -> Void

    private var services: [GarageService] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            return GarageService.catalog.filter {
                $0.title.localizedCaseInsensitiveContains(query)
            }
        }
        let featuredTitles: Set<String> = [
            "Servis Berkala",
            "Tuning ECU & Remap Stage 1 / 2",
            "Overhaul Mesin (Turun Mesin)",
            "Ganti Oli Mesin & Transmisi",
        ]
        return GarageService.catalog.filter { featuredTitles.contains($0.title) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image("BrandLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 54, height: 54)
                        .background(Color.black, in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityLabel("Logo 201 Auto Garage")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("201 AUTO GARAGE")
                            .font(.subheadline.weight(.bold))
                            .tracking(0.25)
                            .foregroundStyle(GarageColor.text)
                        Text("Booking mudah, layanan terpercaya")
                            .font(.caption2)
                            .foregroundStyle(GarageColor.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    NavigationLink {
                        GarageNotificationsView()
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .font(.title3).foregroundStyle(GarageColor.primary)
                                .frame(width: 42, height: 42)
                            let unreadCount = store.notifications.filter { !$0.isRead }.count
                            if unreadCount > 0 {
                                Text(unreadCount > 9 ? "9+" : "\(unreadCount)")
                                    .font(.caption2.bold()).foregroundStyle(.white)
                                    .padding(4)
                                    .background(GarageColor.error, in: Circle())
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                    .accessibilityLabel("Notifikasi")
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Halo, \(store.displayName.split(separator: " ").first.map(String.init) ?? "Pelanggan")")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(GarageColor.text)
                    Text("Mobil sehat, perjalanan lebih tenang.")
                        .font(.subheadline)
                        .foregroundStyle(GarageColor.secondary)
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(GarageColor.primary)
                    TextField("Cari servis, remap, oli...", text: $searchText)
                        .font(.subheadline)
                        .textInputAutocapitalization(.never)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(GarageColor.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(GarageColor.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(GarageColor.border))

                Button {
                    if store.bookings.contains(where: \.isActive) {
                        onStatus()
                    } else {
                        onBook(nil)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.title3)
                            .foregroundStyle(GarageColor.primary)
                            .frame(width: 42, height: 42)
                            .background(GarageColor.primary.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.bookings.first(where: \.isActive) == nil
                                 ? "Belum ada booking aktif" : "Booking terdekat")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(GarageColor.text)
                            Text(store.bookings.first(where: \.isActive).map {
                                "\($0.service) • \($0.status)"
                            } ?? "Pilih layanan untuk mulai booking")
                                .font(.caption)
                                .foregroundStyle(GarageColor.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(GarageColor.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(14)
                .background(GarageColor.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(GarageColor.border))

                NavigationLink {
                    GarageEstimatorView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundStyle(GarageColor.primary)
                            .frame(width: 44, height: 44)
                            .background(GarageColor.primary.opacity(0.16),
                                        in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Kalkulator Estimasi AI")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            Text("Perkiraan biaya sebelum ke bengkel")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.72))
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(14)
                    .background(GarageColor.adminBackground, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(searchText.isEmpty ? "Layanan Kami" : "Hasil Pencarian")
                            .font(.headline)
                        Spacer()
                        Button("Lihat semua") { onBook(nil) }
                            .font(.subheadline.weight(.semibold))
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(services) { service in
                            HomeServiceCard(service: service) { onBook(service) }
                        }
                    }
                    if services.isEmpty {
                        Text("Layanan tidak ditemukan.")
                            .font(.subheadline)
                            .foregroundStyle(GarageColor.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(GarageColor.background)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct HomeServiceCard: View {
    let service: GarageService
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: service.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(GarageColor.primary)
                Text(service.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(GarageColor.text)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(service.priceLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(GarageColor.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .background(GarageColor.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(GarageColor.border))
        }
        .buttonStyle(.plain)
    }
}

private struct GarageEstimatorView: View {
    @EnvironmentObject private var store: GarageStore
    @State private var category = GarageEstimator.categories[0]
    @State private var selectedVehicleID = ""
    @State private var yearText = "2020"
    @State private var kilometerText = "0"
    @State private var replaceEngineOil = true
    @State private var replaceFilter = false
    @State private var replaceBrakePad = false
    @State private var replaceSparkPlugs = false
    @State private var estimate: GarageEstimate?

    private var selectedVehicle: GarageVehicle? {
        store.vehicles.first { $0.id == selectedVehicleID }
    }

    private var year: Int? { selectedVehicle?.year ?? Int(yearText) }
    private var kilometer: Int? { selectedVehicle?.kilometer ?? Int(kilometerText) }
    private var canCalculate: Bool {
        guard let year, let kilometer else { return false }
        return (1900...Calendar.current.component(.year, from: Date())).contains(year)
            && (0...2_000_000).contains(kilometer)
    }

    var body: some View {
        Form {
            Section("Kendaraan dan layanan") {
                Picker("Kategori layanan", selection: $category) {
                    ForEach(GarageEstimator.categories, id: \.self) { item in
                        Text(item).tag(item)
                    }
                }
                Picker("Kendaraan", selection: $selectedVehicleID) {
                    Text("Input manual").tag("")
                    ForEach(store.vehicles) { vehicle in
                        Text("\(vehicle.fullName) · \(vehicle.plate)").tag(vehicle.id)
                    }
                }
                if let vehicle = selectedVehicle {
                    LabeledContent("Tahun", value: "\(vehicle.year)")
                    LabeledContent("Kilometer", value: "\(vehicle.kilometer.formatted()) km")
                } else {
                    TextField("Tahun kendaraan", text: $yearText)
                        .keyboardType(.numberPad)
                    TextField("Kilometer", text: $kilometerText)
                        .keyboardType(.numberPad)
                }
            }

            Section("Komponen") {
                Toggle("Ganti oli mesin", isOn: $replaceEngineOil)
                Toggle("Ganti filter", isOn: $replaceFilter)
                Toggle("Ganti kampas rem", isOn: $replaceBrakePad)
                Toggle("Ganti busi", isOn: $replaceSparkPlugs)
            }

            Section {
                Button("Hitung Estimasi") {
                    guard let year, let kilometer else { return }
                    estimate = GarageEstimator.predict(GarageEstimateInput(
                        category: category,
                        year: year,
                        kilometer: kilometer,
                        replaceEngineOil: replaceEngineOil,
                        replaceFilter: replaceFilter,
                        replaceBrakePad: replaceBrakePad,
                        replaceSparkPlugs: replaceSparkPlugs
                    ))
                }
                .disabled(!canCalculate)
                .frame(maxWidth: .infinity)
            }

            if let estimate {
                Section("Hasil estimasi") {
                    LabeledContent("Perkiraan biaya", value: rupiah(estimate.estimatedCost))
                        .font(.headline)
                    LabeledContent("Kisaran", value: "\(rupiah(estimate.minCost)) – \(rupiah(estimate.maxCost))")
                    LabeledContent("Jasa", value: rupiah(estimate.laborCost))
                    LabeledContent("Komponen", value: rupiah(estimate.sparepartCost))
                    LabeledContent("Durasi perkiraan", value: "\(estimate.durationMinutes) menit")
                    Text("Hasil ini merupakan estimasi model lokal, bukan penawaran harga. Biaya akhir ditentukan setelah pemeriksaan kendaraan.")
                        .font(.footnote).foregroundStyle(GarageColor.secondary)
                }
            }
        }
        .navigationTitle("Estimasi Servis")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard selectedVehicleID.isEmpty, let firstVehicle = store.vehicles.first else { return }
            selectedVehicleID = firstVehicle.id
        }
    }
}

private struct GarageNotificationsView: View {
    @EnvironmentObject private var store: GarageStore
    @State private var message: String?

    var body: some View {
        List {
            if store.notifications.contains(where: { !$0.isRead }) {
                Section {
                    Button("Tandai semua telah dibaca") {
                        Task {
                            do { try await store.markAllNotificationsRead() }
                            catch { message = error.localizedDescription }
                        }
                    }
                }
            }
            if store.notifications.isEmpty {
                ContentUnavailableView("Belum ada notifikasi", systemImage: "bell",
                                       description: Text("Pembaruan booking akan tampil di sini."))
            }
            ForEach(store.notifications) { notification in
                Button {
                    guard !notification.isRead else { return }
                    Task {
                        do { try await store.markNotificationRead(notification) }
                        catch { message = error.localizedDescription }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(notification.title).font(.headline)
                                .foregroundStyle(GarageColor.text)
                            Spacer()
                            if !notification.isRead {
                                Circle().fill(GarageColor.primary).frame(width: 8, height: 8)
                            }
                        }
                        Text(notification.message).font(.subheadline)
                            .foregroundStyle(GarageColor.secondary)
                        Text(notification.createdAt == .distantPast
                             ? notification.category
                             : notification.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(GarageColor.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(notification.isRead ? GarageColor.surface : GarageColor.primary.opacity(0.08))
                .swipeActions {
                    Button(role: .destructive) {
                        Task {
                            do { try await store.deleteNotification(notification) }
                            catch { message = error.localizedDescription }
                        }
                    } label: {
                        Label("Hapus", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Notifikasi")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Gagal memperbarui notifikasi", isPresented: Binding(
            get: { message != nil }, set: { if !$0 { message = nil } }
        )) {
            Button("Tutup", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }
}

private struct ServiceRow: View {
    let service: GarageService
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: service.icon)
                    .font(.title3)
                    .foregroundStyle(GarageColor.primary)
                    .frame(width: 48, height: 48)
                    .background(GarageColor.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(service.title).font(.subheadline.weight(.semibold)).foregroundStyle(GarageColor.text)
                    Text(service.description).font(.caption).foregroundStyle(GarageColor.secondary)
                    Text(service.priceLabel).font(.caption.weight(.bold)).foregroundStyle(GarageColor.primary)
                    if let priceNote = service.priceNote {
                        Text(priceNote).font(.caption2).foregroundStyle(GarageColor.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(GarageColor.secondary)
            }
            .padding(13)
            .background(GarageColor.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(GarageColor.border))
        }
        .buttonStyle(.plain)
    }
}

private enum BookingRoute: Hashable {
    case date(GarageService, String?, GarageVehicle)
    case time(GarageService, String?, GarageVehicle, Date)
    case confirm(GarageService, String?, GarageVehicle, Date, String)
}

private struct BookingFlowView: View {
    @Binding var selectedTab: CustomerTab
    @Binding var pendingService: GarageService?
    @Binding var isPresented: Bool
    @EnvironmentObject private var store: GarageStore
    @State private var selectedVehicleID: String?
    @State private var path: [BookingRoute] = []
    @State private var optionService: GarageService?
    @State private var requestedService: GarageService?

    private let groups = ["Servis Rutin", "Performa & Diesel"]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GaragePageTitle(title: "Booking Servis", subtitle: "Pilih kendaraan, layanan, tanggal, dan waktu.")
                    if store.vehicles.isEmpty {
                        GarageCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Tambahkan kendaraan sebelum booking", systemImage: "car.side")
                                    .font(.subheadline.weight(.semibold))
                                NavigationLink("Kelola Kendaraan") { VehicleListView() }
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pilih Kendaraan").font(.headline)
                            Picker("Kendaraan", selection: $selectedVehicleID) {
                                ForEach(store.vehicles) { vehicle in
                                    Text("\(vehicle.fullName) • \(vehicle.plate)")
                                        .tag(Optional(vehicle.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(GarageColor.surface, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    if let requestedService {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Layanan pilihan").font(.headline)
                            ServiceRow(service: requestedService) {
                                beginBooking(requestedService)
                            }
                            .disabled(store.vehicles.isEmpty)
                        }
                    }
                    ForEach(groups, id: \.self) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(group).font(.headline)
                            ForEach(GarageService.catalog.filter { $0.group == group }) { service in
                                ServiceRow(service: service) {
                                    beginBooking(service)
                                }
                                .disabled(store.vehicles.isEmpty)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(GarageColor.background)
            .navigationTitle("Booking Servis")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: BookingRoute.self) { route in
                switch route {
                case .date(let service, let option, let vehicle):
                    BookingDateView(service: service, serviceOption: option, vehicle: vehicle)
                case .time(let service, let option, let vehicle, let date):
                    BookingTimeView(service: service, serviceOption: option, vehicle: vehicle, date: date)
                case .confirm(let service, let option, let vehicle, let date, let time):
                    BookingConfirmView(service: service, serviceOption: option, vehicle: vehicle,
                                       date: date, time: time) { destination in
                        path.removeAll()
                        selectedTab = destination
                        isPresented = false
                    }
                }
            }
            .confirmationDialog("Pilih opsi \(optionService?.title ?? "")",
                                isPresented: Binding(
                                    get: { optionService != nil },
                                    set: { if !$0 { optionService = nil } }
                                ),
                                titleVisibility: .visible) {
                if let optionService {
                    ForEach(optionService.options, id: \.self) { option in
                        Button(option) { beginBooking(optionService, option: option) }
                    }
                }
                Button("Batal", role: .cancel) { optionService = nil }
            } message: {
                if let optionService {
                    Text("\(optionService.priceLabel). Harga final dikonfirmasi setelah pemeriksaan kendaraan.")
                }
            }
            .onAppear {
                if selectedVehicleID == nil { selectedVehicleID = store.vehicles.first?.id }
                consumePendingService()
            }
            .onChange(of: pendingService) { _, _ in
                consumePendingService()
            }
            .onChange(of: store.vehicles) { _, vehicles in
                if !vehicles.contains(where: { $0.id == selectedVehicleID }) {
                    selectedVehicleID = vehicles.first?.id
                }
            }
        }
    }

    private func consumePendingService() {
        guard let service = pendingService else { return }
        pendingService = nil
        requestedService = service
    }

    private func beginBooking(_ service: GarageService, option: String? = nil) {
        guard let vehicle = store.vehicles.first(where: { $0.id == selectedVehicleID })
                ?? store.vehicles.first else { return }
        if service.options.isEmpty {
            path.append(.date(service, nil, vehicle))
        } else if let option {
            optionService = nil
            path.append(.date(service, option, vehicle))
        } else {
            optionService = service
        }
    }
}

private struct BookingDateView: View {
    let service: GarageService
    let serviceOption: String?
    let vehicle: GarageVehicle
    @State private var date: Date?

    private var availableDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (1...30).compactMap { offset in
            guard let value = calendar.date(byAdding: .day, value: offset, to: today),
                  calendar.component(.weekday, from: value) != 1 else { return nil }
            return value
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GarageCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(service.title).font(.headline)
                        if let serviceOption { Text("Opsi: \(serviceOption)").font(.subheadline) }
                        Text(service.description).font(.subheadline).foregroundStyle(GarageColor.secondary)
                        Text(service.priceLabel).font(.headline).foregroundStyle(GarageColor.primary)
                        Text("\(vehicle.fullName) • \(vehicle.plate)")
                            .font(.caption).foregroundStyle(GarageColor.secondary)
                    }
                }
                Text("Bengkel buka Senin–Sabtu. Booking paling cepat untuk besok.")
                    .font(.caption).foregroundStyle(GarageColor.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                    ForEach(availableDates, id: \.self) { value in
                        Button { date = value } label: {
                            VStack(spacing: 3) {
                                Text(value.formatted(.dateTime.weekday(.abbreviated)))
                                    .font(.caption2)
                                Text(value.formatted(.dateTime.day()))
                                    .font(.headline)
                                Text(value.formatted(.dateTime.month(.abbreviated)))
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .foregroundStyle(Calendar.current.isDate(value, inSameDayAs: date ?? .distantPast)
                                             ? .white : GarageColor.text)
                            .background(Calendar.current.isDate(value, inSameDayAs: date ?? .distantPast)
                                        ? GarageColor.primary : GarageColor.surface,
                                        in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(GarageColor.border))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            if let date {
                NavigationLink(value: BookingRoute.time(service, serviceOption, vehicle, date)) {
                    Text("Pilih Waktu").fontWeight(.semibold).frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(.white).background(GarageColor.primary, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(20)
                .background(GarageColor.background)
            }
        }
        .background(GarageColor.background)
        .navigationTitle("Pilih Tanggal")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BookingTimeView: View {
    let service: GarageService
    let serviceOption: String?
    let vehicle: GarageVehicle
    let date: Date
    @State private var selectedTime: String?
    private let slots = ["08:00", "09:00", "10:00", "11:00", "13:00", "14:00", "15:00", "16:00"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GaragePageTitle(title: "Pilih Waktu", subtitle: bookingDate(ISO8601DateFormatter().string(from: date)))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(slots, id: \.self) { slot in
                        Button {
                            selectedTime = slot
                        } label: {
                            Text(slot).fontWeight(.semibold).frame(maxWidth: .infinity, minHeight: 48)
                                .foregroundStyle(selectedTime == slot ? .white : GarageColor.text)
                                .background(selectedTime == slot ? GarageColor.primary : GarageColor.surface,
                                            in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(GarageColor.border))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            if let selectedTime {
                NavigationLink(value: BookingRoute.confirm(service, serviceOption, vehicle, date, selectedTime)) {
                    Text("Lanjutkan").fontWeight(.semibold).frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(.white).background(GarageColor.primary, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(20)
                .background(GarageColor.background)
            }
        }
        .background(GarageColor.background)
        .navigationTitle("Pilih Waktu")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BookingConfirmView: View {
    @EnvironmentObject private var store: GarageStore
    let service: GarageService
    let serviceOption: String?
    let vehicle: GarageVehicle
    let date: Date
    let time: String
    let onCompleted: (CustomerTab) -> Void
    @State private var note = ""
    @State private var message: String?
    @State private var showingSuccess = false
    @State private var isSubmitting = false
    @State private var didCreateBooking = false
    @State private var requestID = UUID().uuidString
    @State private var successDestination: CustomerTab = .status

    var body: some View {
        Form {
            Section("Detail Booking") {
                LabeledContent("Layanan", value: service.title)
                if let serviceOption { LabeledContent("Opsi", value: serviceOption) }
                LabeledContent("Tanggal", value: date.formatted(date: .long, time: .omitted))
                LabeledContent("Waktu", value: "\(time) WIB")
                LabeledContent("Harga katalog", value: service.priceLabel)
                if let priceNote = service.priceNote {
                    Text(priceNote).font(.caption).foregroundStyle(GarageColor.secondary)
                }
            }
            Section("Kendaraan") {
                LabeledContent("Kendaraan", value: vehicle.fullName)
                LabeledContent("Nomor Polisi", value: vehicle.plate)
                LabeledContent("Jarak Tempuh", value: "\(vehicle.kilometer.formatted()) km")
            }
            Section("Catatan (opsional)") {
                TextField("Tambahkan catatan", text: $note, axis: .vertical)
                    .lineLimit(3...5)
            }
            Section {
                GaragePrimaryButton(title: "Konfirmasi Booking", isLoading: isSubmitting || store.isLoading) {
                    guard !isSubmitting, !didCreateBooking, !store.isLoading else { return }
                    guard note.trimmingCharacters(in: .whitespacesAndNewlines).count <= 1_000 else {
                        message = "Catatan maksimal 1.000 karakter."
                        return
                    }
                    isSubmitting = true
                    Task {
                        defer { isSubmitting = false }
                        do {
                            try await store.createBooking(service: service, serviceOption: serviceOption,
                                                          date: date, time: time,
                                                          vehicle: vehicle, note: note,
                                                          requestID: requestID)
                            didCreateBooking = true
                            showingSuccess = true
                        } catch { message = error.localizedDescription }
                    }
                }
                .disabled(didCreateBooking)
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Konfirmasi Booking")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSubmitting || didCreateBooking)
        .sheet(isPresented: $showingSuccess, onDismiss: {
            if didCreateBooking { onCompleted(successDestination) }
        }) {
            BookingSuccessView(service: service, serviceOption: serviceOption,
                               vehicle: vehicle, date: date, time: time) { destination in
                successDestination = destination
                showingSuccess = false
            }
        }
        .alert("Booking", isPresented: Binding(
            get: { message != nil }, set: { if !$0 { message = nil } }
        )) {
            Button("OK") { message = nil }
        } message: { Text(message ?? "") }
    }
}

private struct BookingSuccessView: View {
    let service: GarageService
    let serviceOption: String?
    let vehicle: GarageVehicle
    let date: Date
    let time: String
    let onClose: (CustomerTab) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 108, height: 108)
                .background(GarageColor.success, in: Circle())
                .padding(14)
                .background(GarageColor.success.opacity(0.12), in: Circle())
            Text("Booking Berhasil!").font(.title2.bold()).foregroundStyle(GarageColor.text)
            Text("Permintaan booking Anda telah terkirim. Bengkel akan mengonfirmasi jadwal dan biaya final.")
                .font(.subheadline).foregroundStyle(GarageColor.secondary)
                .multilineTextAlignment(.center)
            GarageCard {
                VStack(spacing: 12) {
                    LabeledContent("Layanan", value: service.title)
                    if let serviceOption { LabeledContent("Opsi", value: serviceOption) }
                    LabeledContent("Kendaraan", value: "\(vehicle.fullName) • \(vehicle.plate)")
                    LabeledContent("Tanggal", value: date.formatted(date: .long, time: .omitted))
                    LabeledContent("Waktu", value: "\(time) WIB")
                    LabeledContent("Harga katalog", value: service.priceLabel)
                }
            }
            Spacer()
            GaragePrimaryButton(title: "Pantau Status Servis") {
                onClose(.status)
            }
            Button("Kembali ke Beranda") {
                onClose(.home)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(GarageColor.primary)
        }
        .padding(24)
        .background(GarageColor.background.ignoresSafeArea())
    }
}

private struct CustomerBookingListView: View {
    enum Mode { case status, history }
    @EnvironmentObject private var store: GarageStore
    let mode: Mode
    @State private var searchText = ""
    @State private var historyFilter = "Semua"

    private var items: [GarageBooking] {
        let source = mode == .status
            ? store.bookings.filter(\.isActive)
            : store.bookings.filter(\.isHistory)
        return source.filter { booking in
            let matchesFilter = historyFilter == "Semua" || booking.status == historyFilter
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty
                || booking.service.localizedCaseInsensitiveContains(query)
                || (booking.serviceOption?.localizedCaseInsensitiveContains(query) ?? false)
                || booking.vehicle.localizedCaseInsensitiveContains(query)
                || booking.vehiclePlate.localizedCaseInsensitiveContains(query)
                || booking.id.localizedCaseInsensitiveContains(query)
            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GaragePageTitle(title: mode == .status ? "Status Servis" : "Riwayat Servis",
                                subtitle: mode == .status ? "Pantau progres kendaraan Anda." : "Daftar servis yang pernah Anda booking.")
                if mode == .history {
                    TextField("Cari layanan, mobil, atau ID booking", text: $searchText)
                        .padding(12)
                        .background(GarageColor.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(GarageColor.border))
                    Picker("Filter Riwayat", selection: $historyFilter) {
                        ForEach(["Semua", "Selesai", "Dibatalkan"], id: \.self) { status in
                            Text(status).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if items.isEmpty {
                    EmptyStateCard(icon: mode == .status ? "wrench.and.screwdriver" : "clock",
                                   title: mode == .status ? "Tidak ada servis aktif" : "Belum ada riwayat servis",
                                   detail: "Booking servis akan muncul di sini.")
                } else {
                    ForEach(items) { BookingCard(booking: $0) }
                }
            }
            .padding(20)
        }
        .background(GarageColor.background)
        .navigationTitle(mode == .status ? "Status Servis" : "Riwayat Servis")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BookingCard: View {
    @EnvironmentObject private var store: GarageStore
    @State private var showingCancelConfirmation = false
    @State private var message: String?
    let booking: GarageBooking

    var body: some View {
        GarageCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(booking.service).font(.headline).foregroundStyle(GarageColor.text)
                    Spacer()
                    GarageStatusBadge(status: booking.status)
                }
                Label(booking.vehicle.isEmpty ? "Kendaraan belum diisi" : booking.vehicle,
                      systemImage: "car.side")
                    .font(.subheadline).foregroundStyle(GarageColor.secondary)
                if !booking.vehiclePlate.isEmpty {
                    Text("Plat \(booking.vehiclePlate) • \(booking.vehicleYear) • \(booking.vehicleKilometer.formatted()) km")
                        .font(.caption).foregroundStyle(GarageColor.secondary)
                }
                if let option = booking.serviceOption {
                    Text("Opsi: \(option)").font(.caption).foregroundStyle(GarageColor.secondary)
                }
                Label("\(bookingDate(booking.date)) • \(booking.time) WIB",
                      systemImage: "calendar")
                    .font(.subheadline).foregroundStyle(GarageColor.secondary)
                HStack {
                    Text("Estimasi").foregroundStyle(GarageColor.secondary)
                    Spacer()
                    Text(rupiah(booking.estimate ?? booking.price)).fontWeight(.semibold)
                        .foregroundStyle(GarageColor.primary)
                }
                ServiceProgressTimeline(progressStep: booking.progressStep, status: booking.status)
                if !booking.note.isEmpty {
                    Text("Catatan: \(booking.note)").font(.caption).foregroundStyle(GarageColor.secondary)
                }
                if booking.isActive {
                    Button("Batalkan Booking", role: .destructive) {
                        showingCancelConfirmation = true
                    }
                    .font(.caption.weight(.semibold))
                }
            }
        }
        .confirmationDialog("Batalkan booking?", isPresented: $showingCancelConfirmation,
                            titleVisibility: .visible) {
            Button("Batalkan Booking", role: .destructive) {
                Task {
                    do { try await store.cancelBooking(booking) }
                    catch { message = error.localizedDescription }
                }
            }
        } message: {
            Text("Status booking akan diubah menjadi Dibatalkan.")
        }
        .alert("Booking", isPresented: Binding(
            get: { message != nil }, set: { if !$0 { message = nil } }
        )) {
            Button("Tutup", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }
}

private struct ServiceProgressTimeline: View {
    let progressStep: Int
    let status: String
    private let steps = [
        "Penerimaan Kendaraan",
        "Pengecekan Awal",
        "Pengerjaan",
        "Quality Check",
        "Selesai",
    ]

    private var isCancelled: Bool { progressStep == 0 || status.lowercased() == "dibatalkan" }
    private var isFinished: Bool { progressStep >= steps.count || status.lowercased() == "selesai" }
    private var currentIndex: Int { min(max(progressStep - 1, 0), steps.count - 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lacak Pengerjaan").font(.subheadline.weight(.semibold))
            if isCancelled {
                Label("Booking dibatalkan", systemImage: "xmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GarageColor.error)
            } else {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    let completed = isFinished || index < currentIndex
                    let current = !isFinished && index == currentIndex
                    HStack(spacing: 10) {
                        Image(systemName: completed ? "checkmark.circle.fill" :
                                (current ? "circle.inset.filled" : "circle"))
                            .foregroundStyle(completed ? GarageColor.success :
                                                (current ? GarageColor.primary : GarageColor.border))
                        Text(step)
                            .font(.caption.weight(current ? .semibold : .regular))
                            .foregroundStyle(completed ? GarageColor.success : GarageColor.secondary)
                        Spacer()
                        if current && status.lowercased() == "menunggu" {
                            Text("Menunggu").font(.caption2.weight(.semibold)).foregroundStyle(GarageColor.warning)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GarageColor.background, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct EmptyStateCard: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        GarageCard {
            VStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 30)).foregroundStyle(GarageColor.primary)
                Text(title).font(.headline).foregroundStyle(GarageColor.text)
                Text(detail).font(.subheadline).foregroundStyle(GarageColor.secondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

private extension View {
    func garageField() -> some View {
        padding(15)
            .background(GarageColor.authInput, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(GarageColor.authOutline))
    }
}

private struct AccountView: View {
    @EnvironmentObject private var store: GarageStore
    @State private var message: String?

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 48)).foregroundStyle(GarageColor.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.displayName.isEmpty ? "Pelanggan" : store.displayName)
                            .font(.headline)
                        Text(store.user?.email ?? "").font(.subheadline).foregroundStyle(GarageColor.secondary)
                    }
                }
                .padding(.vertical, 8)
                NavigationLink("Data Diri") { ProfileEditView() }
                NavigationLink("Alamat Saya") { AddressView() }
                NavigationLink("Kendaraan Saya") { VehicleListView() }
            }
            Section("Layanan") {
                NavigationLink { CustomerPromoView() } label: {
                    Label("Promo", systemImage: "tag")
                }
                NavigationLink { HelpView() } label: {
                    Label("Bantuan", systemImage: "questionmark.circle")
                }
                NavigationLink { SettingsView() } label: {
                    Label("Pengaturan", systemImage: "gearshape")
                }
                NavigationLink { AboutView() } label: {
                    Label("Tentang Aplikasi", systemImage: "info.circle")
                }
            }
            Section {
                Button("Keluar", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    do { try store.signOut() }
                    catch { message = error.localizedDescription }
                }
            }
        }
        .navigationTitle("Akun")
        .alert("Keluar", isPresented: Binding(
            get: { message != nil }, set: { if !$0 { message = nil } }
        )) {
            Button("Tutup", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }
}

private struct ProfileEditView: View {
    @EnvironmentObject private var store: GarageStore
    @State private var name = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var message: String?

    var body: some View {
        Form {
            Section("Informasi akun") {
                TextField("Nama lengkap", text: $name)
                    .textContentType(.name)
                TextField("Nomor telepon", text: $phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                TextField("Alamat", text: $address, axis: .vertical)
                    .textContentType(.fullStreetAddress)
                    .lineLimit(2...4)
                LabeledContent("Email", value: store.user?.email ?? "-")
            }
            Section {
                GaragePrimaryButton(title: "Simpan Perubahan", isLoading: store.isLoading) {
                    Task {
                        do {
                            try await store.updateProfile(name: name, phone: phone, address: address)
                            message = "Data diri berhasil diperbarui."
                        } catch { message = error.localizedDescription }
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Data Diri")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = store.displayName
            phone = store.phone
            address = store.address
        }
        .alert("Data Diri", isPresented: Binding(
            get: { message != nil }, set: { if !$0 { message = nil } }
        )) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }
}

private struct AddressView: View {
    @EnvironmentObject private var store: GarageStore
    @State private var showingAddAddress = false
    @State private var message: String?

    var body: some View {
        List {
            if store.addresses.isEmpty {
                ContentUnavailableView("Belum ada alamat",
                                       systemImage: "mappin.and.ellipse",
                                       description: Text("Tambahkan alamat rumah atau kantor Anda."))
            }
            ForEach(store.addresses) { address in
                VStack(alignment: .leading, spacing: 7) {
                    Label(address.label, systemImage: "mappin.and.ellipse")
                        .font(.headline)
                    Text(address.fullAddress)
                        .font(.subheadline)
                        .foregroundStyle(GarageColor.secondary)
                }
                .padding(.vertical, 5)
                .swipeActions {
                    Button("Hapus", systemImage: "trash", role: .destructive) {
                        Task {
                            do { try await store.deleteAddress(address) }
                            catch { message = error.localizedDescription }
                        }
                    }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button { showingAddAddress = true } label: {
                Label("Tambah Alamat", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18).padding(.vertical, 13)
                    .foregroundStyle(.white)
                    .background(GarageColor.primary, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
            }
            .padding(20)
        }
        .navigationTitle("Alamat Saya")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddAddress) { AddAddressView() }
        .alert("Alamat", isPresented: Binding(
            get: { message != nil }, set: { if !$0 { message = nil } }
        )) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }
}

private struct AddAddressView: View {
    @EnvironmentObject private var store: GarageStore
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var fullAddress = ""
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Alamat baru") {
                    TextField("Label (Rumah, Kantor, dll.)", text: $label)
                    TextField("Alamat lengkap", text: $fullAddress, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Button("Simpan Alamat") {
                        guard !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                              !fullAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            message = "Label dan alamat lengkap harus diisi."
                            return
                        }
                        Task {
                            do {
                                try await store.addAddress(label: label, fullAddress: fullAddress)
                                dismiss()
                            } catch { message = error.localizedDescription }
                        }
                    }
                }
            }
            .navigationTitle("Tambah Alamat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Batal") { dismiss() } }
            }
            .alert("Alamat", isPresented: Binding(
                get: { message != nil }, set: { if !$0 { message = nil } }
            )) {
                Button("OK", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
        }
    }
}

private struct VehicleListView: View {
    @EnvironmentObject private var store: GarageStore
    @State private var editor: VehicleEditor?
    @State private var message: String?

    var body: some View {
        List {
            if store.vehicles.isEmpty {
                ContentUnavailableView("Belum ada kendaraan",
                                       systemImage: "car.side",
                                       description: Text("Tambahkan kendaraan untuk mempercepat booking servis."))
            }
            ForEach(store.vehicles) { vehicle in
                HStack(spacing: 12) {
                    Image(systemName: "car.side.fill")
                        .foregroundStyle(GarageColor.primary)
                        .frame(width: 42, height: 42)
                        .background(GarageColor.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vehicle.title).fontWeight(.semibold)
                        Text("\(vehicle.plate) • \(vehicle.year) • \(vehicle.kilometer.formatted()) km")
                            .font(.caption).foregroundStyle(GarageColor.secondary)
                    }
                    Spacer()
                    Menu {
                        Button("Ubah", systemImage: "pencil") {
                            editor = VehicleEditor(vehicle: vehicle)
                        }
                        Button("Hapus", systemImage: "trash", role: .destructive) {
                            Task {
                                do { try await store.deleteVehicle(vehicle) }
                                catch { message = error.localizedDescription }
                            }
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
        }
        .navigationTitle("Kendaraan Saya")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editor = VehicleEditor(vehicle: nil) } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $editor) { editor in VehicleEditorView(vehicle: editor.vehicle) }
        .alert("Kendaraan", isPresented: Binding(
            get: { message != nil }, set: { if !$0 { message = nil } }
        )) {
            Button("Tutup", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }
}

private struct VehicleEditor: Identifiable {
    let id: String
    let vehicle: GarageVehicle?

    init(vehicle: GarageVehicle?) {
        self.vehicle = vehicle
        id = vehicle?.id ?? UUID().uuidString
    }
}

private struct VehicleEditorView: View {
    @EnvironmentObject private var store: GarageStore
    @Environment(\.dismiss) private var dismiss
    @State private var brand = ""
    @State private var model = ""
    @State private var plate = ""
    @State private var year = Calendar.current.component(.year, from: .now) - 5
    @State private var kilometer = 35_000
    @State private var message: String?

    let vehicle: GarageVehicle?

    init(vehicle: GarageVehicle?) {
        self.vehicle = vehicle
        _brand = State(initialValue: vehicle?.brand ?? "")
        _model = State(initialValue: vehicle?.model ?? "")
        _plate = State(initialValue: vehicle?.plate ?? "")
        _year = State(initialValue: vehicle?.year ?? Calendar.current.component(.year, from: .now) - 5)
        _kilometer = State(initialValue: vehicle?.kilometer ?? 35_000)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Informasi kendaraan") {
                    TextField("Merek (contoh: Toyota)", text: $brand)
                    TextField("Model (contoh: Avanza)", text: $model)
                    TextField("Nomor plat", text: $plate)
                        .textInputAutocapitalization(.characters)
                    TextField("Tahun", value: $year, format: .number.grouping(.never))
                        .keyboardType(.numberPad)
                    TextField("Kilometer", value: $kilometer, format: .number)
                        .keyboardType(.numberPad)
                }
                Section {
                    Button(vehicle == nil ? "Simpan Kendaraan" : "Simpan Perubahan") {
                        guard !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                              !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                              !plate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            message = "Merek, model, dan nomor plat harus diisi."
                            return
                        }
                        guard (1900...Calendar.current.component(.year, from: .now) + 1).contains(year),
                              (0...2_000_000).contains(kilometer) else {
                            message = "Periksa kembali tahun dan kilometer kendaraan."
                            return
                        }
                        Task {
                            do {
                                if let vehicle {
                                    var updated = vehicle
                                    updated.brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
                                    updated.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
                                    updated.plate = plate.trimmingCharacters(in: .whitespacesAndNewlines)
                                    updated.year = year
                                    updated.kilometer = kilometer
                                    try await store.updateVehicle(updated)
                                } else {
                                    try await store.addVehicle(brand: brand, model: model,
                                                               plate: plate, year: year,
                                                               kilometer: kilometer)
                                }
                                dismiss()
                            } catch { message = error.localizedDescription }
                        }
                    }
                }
            }
            .navigationTitle(vehicle == nil ? "Tambah Kendaraan" : "Edit Kendaraan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Batal") { dismiss() }
                }
            }
            .alert("Kendaraan", isPresented: Binding(
                get: { message != nil }, set: { if !$0 { message = nil } }
            )) {
                Button("OK", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
        }
    }
}

private struct CustomerPromoView: View {
    @EnvironmentObject private var store: GarageStore

    private var activePromos: [GaragePromo] {
        store.promos.filter(\.isActive)
    }

    var body: some View {
        List {
            if activePromos.isEmpty {
                ContentUnavailableView("Belum ada promo", systemImage: "tag",
                                       description: Text("Promo terbaru akan tampil di halaman ini."))
            }
            ForEach(activePromos) { promo in
                PromoCard(promo: promo)
            }
        }
        .navigationTitle("Promo")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.refreshPromos() }
    }
}

private struct PromoCard: View {
    let promo: GaragePromo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(promo.title).font(.headline)
                Spacer()
                Text(promo.discount).font(.caption.weight(.bold)).foregroundStyle(GarageColor.primary)
            }
            Text(promo.description).font(.subheadline).foregroundStyle(GarageColor.secondary)
            if !promo.code.isEmpty {
                Label(promo.code, systemImage: "ticket").font(.caption.weight(.semibold))
                    .foregroundStyle(GarageColor.primary)
            }
            if !promo.expiry.isEmpty {
                Label("Berlaku hingga \(promo.expiry)", systemImage: "calendar")
                    .font(.caption).foregroundStyle(GarageColor.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct SettingsView: View {
    @AppStorage("pushNotificationsEnabled") private var pushNotificationsEnabled = true
    @AppStorage("emailNotificationsEnabled") private var emailNotificationsEnabled = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false

    var body: some View {
        Form {
            Section("Notifikasi") {
                Toggle("Notifikasi Push", isOn: $pushNotificationsEnabled)
                Toggle("Notifikasi Email", isOn: $emailNotificationsEnabled)
                Text("Preferensi ini disimpan di perangkat. Pengiriman push dan email belum diaktifkan.")
                    .font(.footnote)
                    .foregroundStyle(GarageColor.secondary)
            }
            Section("Tampilan") {
                Toggle("Mode Gelap", isOn: $darkModeEnabled)
            }
        }
        .navigationTitle("Pengaturan")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HelpView: View {
    private let questions = [
        ("Bagaimana cara melakukan booking servis?",
         "Dari Beranda, pilih Booking Servis atau layanan yang diinginkan. Pilih kendaraan, tanggal, dan waktu, lalu konfirmasi pesanan."),
        ("Bagaimana cara memantau servis?",
         "Buka tab Status untuk melihat progres pengerjaan dari bengkel."),
        ("Bagaimana menggunakan promo?",
         "Periksa kode promo pada menu Akun > Promo, lalu sampaikan kode tersebut saat booking."),
    ]

    var body: some View {
        List {
            ForEach(questions, id: \.0) { item in
                DisclosureGroup(item.0) {
                    Text(item.1).font(.subheadline).foregroundStyle(GarageColor.secondary)
                        .padding(.vertical, 5)
                }
            }
            Section {
                Label("Hubungi 201 Auto Garage", systemImage: "phone")
                Text("Senin–Sabtu, 08.00–17.00 WIB").font(.caption).foregroundStyle(GarageColor.secondary)
            }
        }
        .navigationTitle("Bantuan")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 24))
                    .padding(.top, 36)
                Text("201 Auto Garage").font(.title2.bold())
                Text("Aplikasi resmi 201 Auto Garage untuk memudahkan booking servis kendaraan, memantau status pengerjaan bengkel, dan melihat riwayat servis dengan cepat dan transparan.")
                    .font(.body).foregroundStyle(GarageColor.secondary).multilineTextAlignment(.center)
                Text("Versi 1.0.0").font(.caption).foregroundStyle(GarageColor.secondary)
            }
            .padding(28)
        }
        .background(GarageColor.background)
        .navigationTitle("Tentang Aplikasi")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AdminShellView: View {
    @EnvironmentObject private var store: GarageStore
    @State private var selectedTab: AdminTab = .dashboard

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { AdminDashboardView() }
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2.fill") }
                .tag(AdminTab.dashboard)
            NavigationStack { AdminBookingsView() }
                .tabItem { Label("Booking", systemImage: "calendar") }
                .tag(AdminTab.bookings)
            NavigationStack { AdminServicesView() }
                .tabItem { Label("Servis", systemImage: "wrench.and.screwdriver") }
                .tag(AdminTab.services)
            NavigationStack { AdminMoreFeaturesView() }
                .tabItem { Label("Lainnya", systemImage: "square.grid.2x2") }
                .tag(AdminTab.more)
        }
        .tint(GarageColor.adminOrange)
        .preferredColorScheme(.dark)
    }
}

private struct AdminMoreFeaturesView: View {
    var body: some View {
        List {
            Section("Fitur Admin Lainnya") {
                NavigationLink {
                    AdminCustomersView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Pelanggan")
                                .font(.subheadline.weight(.semibold))
                            Text("Lihat data pelanggan terdaftar")
                                .font(.caption)
                                .foregroundStyle(GarageColor.secondary)
                        }
                    } icon: {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(GarageColor.primary)
                    }
                }
                NavigationLink {
                    AdminPromosView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Kelola Kode Promo")
                                .font(.subheadline.weight(.semibold))
                            Text("Tambah dan atur promo pelanggan")
                                .font(.caption)
                                .foregroundStyle(GarageColor.secondary)
                        }
                    } icon: {
                        Image(systemName: "tag.fill")
                            .foregroundStyle(GarageColor.primary)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(GarageColor.adminBackground)
        .navigationTitle("Lainnya")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AdminDashboardView: View {
    @EnvironmentObject private var store: GarageStore
    @State private var message: String?

    private var waiting: Int { store.bookings.filter { $0.status == "Menunggu" }.count }
    private var inProgress: Int {
        store.bookings.filter {
            ["Proses Pengecekan", "Sedang Dikerjakan", "Quality Check"].contains($0.status)
        }.count
    }
    private var finished: Int { store.bookings.filter { $0.status == "Selesai" }.count }
    private var todayCount: Int {
        store.bookings.filter { booking in
            guard let date = ISO8601DateFormatter().date(from: booking.date) else { return false }
            return Calendar.current.isDateInToday(date)
        }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Selamat datang, Admin").font(.title2.bold())
                        Text(Date.now.formatted(date: .complete, time: .omitted))
                            .font(.caption).foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer()
                    Button {
                        do { try store.signOut() }
                        catch { message = error.localizedDescription }
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.red)
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    AdminStatCard(title: "Booking Hari Ini", value: "\(todayCount)",
                                  icon: "calendar", color: GarageColor.adminOrange)
                    AdminStatCard(title: "Menunggu", value: "\(waiting)",
                                  icon: "hourglass", color: GarageColor.warning)
                    AdminStatCard(title: "Dikerjakan", value: "\(inProgress)",
                                  icon: "wrench.and.screwdriver", color: GarageColor.primary)
                    AdminStatCard(title: "Selesai", value: "\(finished)",
                                  icon: "checkmark.circle", color: GarageColor.success)
                }
                GarageCard {
                    HStack(spacing: 14) {
                        Image(systemName: "chart.bar.fill").font(.largeTitle).foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Estimasi Pendapatan").font(.subheadline).foregroundStyle(.white.opacity(0.8))
                            Text(rupiah(store.bookings.filter { $0.status == "Selesai" }.reduce(0) { $0 + ($1.estimate ?? $1.price) }))
                                .font(.title3.bold()).foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .padding(4)
                    .background(GarageColor.adminOrange, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(-16)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Booking Terbaru").font(.headline)
                        Spacer()
                        NavigationLink("Semua") { AdminBookingsView() }
                            .font(.subheadline.weight(.semibold)).foregroundStyle(GarageColor.adminOrange)
                    }
                    if store.bookings.isEmpty {
                        Text("Belum ada booking pelanggan.")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.65))
                    } else {
                        ForEach(store.bookings.prefix(4)) { booking in
                            AdminBookingRow(booking: booking)
                        }
                    }
                }
                NavigationLink {
                    AdminEstimateListView()
                } label: {
                    Label("Kelola Estimasi Biaya", systemImage: "banknote")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(GarageColor.adminSurface, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
        }
        .background(GarageColor.adminBackground)
        .navigationTitle("Dashboard Admin")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(GarageColor.adminSurface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Informasi", isPresented: Binding(
            get: { message != nil }, set: { if !$0 { message = nil } }
        )) {
            Button("Tutup", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }
}

private struct AdminStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(value).font(.title.bold()).foregroundStyle(.white)
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(GarageColor.adminSurface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.3)))
    }
}

private struct AdminBookingRow: View {
    let booking: GarageBooking

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "car.side.fill").foregroundStyle(GarageColor.adminOrange)
                .frame(width: 40, height: 40).background(GarageColor.adminOrange.opacity(0.15),
                                                         in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(booking.customerName.isEmpty ? booking.customerPhone : booking.customerName)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text("\(booking.vehicle) • \(booking.service)")
                    .font(.caption).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
            }
            Spacer(minLength: 2)
            GarageStatusBadge(status: booking.status)
        }
        .padding(12)
        .background(GarageColor.adminSurface, in: RoundedRectangle(cornerRadius: 13))
    }
}

private struct AdminBookingsView: View {
    @EnvironmentObject private var store: GarageStore
    @State private var filter = "Semua"
    private let filters = ["Semua", "Menunggu", "Proses", "Selesai", "Dibatalkan"]

    private var bookings: [GarageBooking] {
        switch filter {
        case "Menunggu": store.bookings.filter { $0.status == "Menunggu" }
        case "Proses":
            store.bookings.filter {
                ["Proses Pengecekan", "Sedang Dikerjakan", "Quality Check"].contains($0.status)
            }
        case "Selesai": store.bookings.filter { $0.status == "Selesai" }
        case "Dibatalkan": store.bookings.filter { $0.status == "Dibatalkan" }
        default: store.bookings
        }
    }

    var body: some View {
        List {
            Picker("Status", selection: $filter) {
                ForEach(filters, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(GarageColor.adminBackground)
            if bookings.isEmpty {
                ContentUnavailableView("Tidak ada booking", systemImage: "calendar",
                                       description: Text("Booking akan muncul setelah pelanggan membuat pesanan."))
                    .listRowBackground(GarageColor.adminBackground)
            }
            ForEach(bookings) { booking in
                AdminBookingManagementRow(booking: booking)
                    .listRowBackground(GarageColor.adminSurface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(GarageColor.adminBackground)
        .navigationTitle("Booking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(GarageColor.adminSurface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

private struct AdminBookingManagementRow: View {
    @EnvironmentObject private var store: GarageStore
    let booking: GarageBooking
    @State private var rejectionConfirmation = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AdminBookingRow(booking: booking)
            Text("\(bookingDate(booking.date)) • \(booking.time) WIB • \(rupiah(booking.estimate ?? booking.price))")
                .font(.caption).foregroundStyle(.white.opacity(0.65))
            if booking.status == "Menunggu" {
                HStack {
                    Button("Terima") {
                        Task {
                            do { try await store.updateBooking(booking, currentStep: 2) }
                            catch { message = error.localizedDescription }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(GarageColor.success)
                    Button("Tolak", role: .destructive) { rejectionConfirmation = true }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 4)
        .confirmationDialog("Tolak booking ini?", isPresented: $rejectionConfirmation,
                            titleVisibility: .visible) {
            Button("Tolak dan hapus booking", role: .destructive) {
                Task {
                    do { try await store.deleteBooking(booking) }
                    catch { message = error.localizedDescription }
                }
            }
        } message: {
            Text("Booking \(booking.service) milik \(booking.customerName) akan dihapus.")
        }
        .alert("Booking", isPresented: Binding(
            get: { message != nil }, set: { if !$0 { message = nil } }
        )) {
            Button("Tutup", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }
}

private struct AdminServicesView: View {
    @EnvironmentObject private var store: GarageStore
    @State private var selectedBooking: GarageBooking?
    @State private var progressBooking: GarageBooking?

    var body: some View {
        List {
            if store.bookings.isEmpty {
                ContentUnavailableView("Belum ada servis", systemImage: "wrench.and.screwdriver",
                                       description: Text("Booking pelanggan akan ditampilkan di sini."))
                    .listRowBackground(GarageColor.adminBackground)
            }
            ForEach(store.bookings) { booking in
                VStack(alignment: .leading, spacing: 12) {
                    AdminBookingRow(booking: booking)
                    HStack {
                        Text("Estimasi: \(rupiah(booking.estimate ?? booking.price))")
                            .font(.caption).foregroundStyle(.white.opacity(0.75))
                        Spacer()
                        Button("Atur biaya") { selectedBooking = booking }
                            .font(.caption.weight(.semibold)).foregroundStyle(GarageColor.adminOrange)
                    }
                    Button {
                        progressBooking = booking
                    } label: {
                        Label("Perbarui progres servis", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption.weight(.semibold)).foregroundStyle(GarageColor.primary)
                    }
                }
                .padding(.vertical, 5)
                .listRowBackground(GarageColor.adminSurface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(GarageColor.adminBackground)
        .navigationTitle("Update Servis")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(GarageColor.adminSurface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(item: $selectedBooking) { booking in
            EstimateEditorView(booking: booking)
        }
        .sheet(item: $progressBooking) { booking in
            ServiceProgressEditorView(booking: booking)
        }
    }
}

private struct ServiceProgressEditorView: View {
    @EnvironmentObject private var store: GarageStore
    @Environment(\.dismiss) private var dismiss
    let booking: GarageBooking
    @State private var selectedStep: Int
    @State private var message: String?

    private let steps = [
        "Penerimaan Kendaraan",
        "Pengecekan Awal",
        "Pengerjaan",
        "Quality Check",
        "Selesai",
    ]

    init(booking: GarageBooking) {
        self.booking = booking
        _selectedStep = State(initialValue: min(max(booking.progressStep - 1, 0), 4))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Booking") {
                    LabeledContent("Pelanggan", value: booking.customerName)
                    LabeledContent("Kendaraan", value: booking.vehicle)
                    LabeledContent("Layanan", value: booking.service)
                }
                Section("Tahap pengerjaan") {
                    ForEach(steps.indices, id: \.self) { step in
                        Button {
                            selectedStep = step
                        } label: {
                            HStack {
                                Image(systemName: step < selectedStep ? "checkmark.circle.fill" :
                                        (step == selectedStep ? "largecircle.fill.circle" : "circle"))
                                    .foregroundStyle(step < selectedStep ? GarageColor.success :
                                                        (step == selectedStep ? GarageColor.adminOrange : GarageColor.secondary))
                                Text(steps[step]).foregroundStyle(.primary)
                                Spacer()
                                if step == selectedStep {
                                    Image(systemName: "checkmark").foregroundStyle(GarageColor.adminOrange)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section {
                    Button("Simpan Progress") {
                        Task {
                            do {
                                try await store.updateBooking(booking, currentStep: selectedStep + 1)
                                dismiss()
                            } catch { message = error.localizedDescription }
                        }
                    }
                }
            }
            .navigationTitle("Update Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Batal") { dismiss() } }
            }
            .alert("Progress Servis", isPresented: Binding(
                get: { message != nil }, set: { if !$0 { message = nil } }
            )) {
                Button("OK", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
        }
    }
}

private struct AdminEstimateListView: View {
    @EnvironmentObject private var store: GarageStore
    @State private var selectedBooking: GarageBooking?

    var body: some View {
        List {
            if store.bookings.isEmpty {
                ContentUnavailableView("Belum ada booking", systemImage: "banknote",
                                       description: Text("Estimasi biaya akan tersedia setelah pelanggan membuat booking."))
                    .listRowBackground(GarageColor.adminBackground)
            }
            ForEach(store.bookings) { booking in
                Button { selectedBooking = booking } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(booking.customerName) — \(booking.service)")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Text("\(booking.vehicle) • \(rupiah(booking.estimate ?? booking.price))")
                            .font(.caption).foregroundStyle(.white.opacity(0.65))
                    }
                }
                .listRowBackground(GarageColor.adminSurface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(GarageColor.adminBackground)
        .navigationTitle("Estimasi Biaya")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedBooking) { booking in
            EstimateEditorView(booking: booking)
        }
    }
}

private struct EstimateEditorView: View {
    @EnvironmentObject private var store: GarageStore
    @Environment(\.dismiss) private var dismiss
    let booking: GarageBooking
    @State private var amount = ""
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Booking") {
                    LabeledContent("Pelanggan", value: booking.customerName)
                    LabeledContent("Layanan", value: booking.service)
                    LabeledContent("Kendaraan", value: booking.vehicle)
                }
                Section("Estimasi biaya") {
                    TextField("Jumlah (Rupiah)", text: $amount)
                        .keyboardType(.numberPad)
                }
                Section {
                    Button("Simpan Estimasi") {
                        guard let value = Int(amount), value > 0 else {
                            message = "Masukkan nominal lebih dari nol."
                            return
                        }
                        Task {
                            do {
                                try await store.updateBooking(booking, estimatedCost: value)
                                dismiss()
                            } catch { message = error.localizedDescription }
                        }
                    }
                }
            }
            .navigationTitle("Atur Estimasi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Batal") { dismiss() } }
            }
            .onAppear { amount = String(booking.estimate ?? booking.price) }
            .alert("Estimasi", isPresented: Binding(
                get: { message != nil }, set: { if !$0 { message = nil } }
            )) {
                Button("OK", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
        }
    }
}

private struct AdminCustomersView: View {
    @EnvironmentObject private var store: GarageStore
    @State private var query = ""

    private var customers: [GarageCustomer] {
        guard !query.isEmpty else { return store.customers }
        return store.customers.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.email.localizedCaseInsensitiveContains(query) ||
            $0.phone.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            ForEach(customers) { customer in
                VStack(alignment: .leading, spacing: 6) {
                    Text(customer.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text(customer.email).font(.caption).foregroundStyle(.white.opacity(0.65))
                    if customer.phone != "-" {
                        Label(customer.phone, systemImage: "phone").font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    let count = store.bookings.filter { $0.userId == customer.id }.count
                    Text("\(count) booking").font(.caption.weight(.semibold)).foregroundStyle(GarageColor.primary)
                }
                .padding(.vertical, 5)
                .listRowBackground(GarageColor.adminSurface)
            }
        }
        .searchable(text: $query, prompt: "Cari nama atau email")
        .scrollContentBackground(.hidden)
        .background(GarageColor.adminBackground)
        .navigationTitle("Pelanggan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(GarageColor.adminSurface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await store.refreshAdminData() }
    }
}

private struct AdminPromosView: View {
    @EnvironmentObject private var store: GarageStore
    @State private var showingAdd = false

    var body: some View {
        List {
            if store.promos.isEmpty {
                ContentUnavailableView("Belum ada promo", systemImage: "tag",
                                       description: Text("Tambahkan promo untuk pelanggan."))
                    .listRowBackground(GarageColor.adminBackground)
            }
            ForEach(store.promos) { promo in
                VStack(alignment: .leading, spacing: 10) {
                    PromoCard(promo: promo)
                    Toggle("Promo aktif", isOn: Binding(
                        get: { promo.isActive },
                        set: { active in
                            Task {
                                do { try await store.updatePromo(promo, isActive: active) }
                                catch { store.errorMessage = error.localizedDescription }
                            }
                        }
                    ))
                    .tint(GarageColor.adminOrange)
                }
                .listRowBackground(GarageColor.adminSurface)
            }
            .onDelete { offsets in
                for index in offsets {
                    let promo = store.promos[index]
                    Task {
                        do { try await store.deletePromo(promo) }
                        catch { store.errorMessage = error.localizedDescription }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(GarageColor.adminBackground)
        .navigationTitle("Promo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(GarageColor.adminSurface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) { AddPromoView() }
    }
}

private struct AddPromoView: View {
    @EnvironmentObject private var store: GarageStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var detail = ""
    @State private var code = ""
    @State private var discount = ""
    @State private var expiry = ""
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Informasi promo") {
                    TextField("Nama promo", text: $title)
                    TextField("Deskripsi", text: $detail, axis: .vertical)
                    TextField("Kode promo", text: $code).textInputAutocapitalization(.characters)
                    TextField("Diskon (contoh: 20%)", text: $discount)
                    TextField("Berlaku hingga", text: $expiry)
                }
                Section {
                    Button("Simpan Promo") {
                        guard !title.isEmpty else {
                            message = "Nama promo harus diisi."
                            return
                        }
                        Task {
                            do {
                                try await store.addPromo(title: title, description: detail,
                                                         code: code, discount: discount,
                                                         expiry: expiry)
                                dismiss()
                            } catch { message = error.localizedDescription }
                        }
                    }
                }
            }
            .navigationTitle("Tambah Promo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Batal") { dismiss() } }
            }
            .alert("Promo", isPresented: Binding(
                get: { message != nil }, set: { if !$0 { message = nil } }
            )) {
                Button("OK", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
        }
    }
}
