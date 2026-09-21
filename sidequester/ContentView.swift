//
//  ContentView.swift
//  TARDIS
//
//  Created by Rayson Ng on 29/6/26.
//

import SwiftUI
import Combine
import SwiftData
import FirebaseFirestore
import FirebaseAuth

// MARK: - Activity Model

struct Activity: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let age: String
    let physical: String
    let cost: String
    let shelter: String
    let time: String
    let requirement: String
    let points: Int
    let completedCount: Int
}

// MARK: - App Theme

enum AppThemeColor: String, CaseIterable, Identifiable {
    case blue
    case purple
    case pink
    case orange
    case green
    case teal
    case red

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .orange: return .orange
        case .green: return .green
        case .teal: return .teal
        case .red: return .red
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

@MainActor
final class AppCustomization: ObservableObject {
    @AppStorage("glassOpacity") var glassOpacity: Double = 0.72
    @AppStorage("glassBlur") var glassBlur: Double = 18
    @AppStorage("glassCornerRadius") var glassCornerRadius: Double = 26
    @AppStorage("glassBorderOpacity") var glassBorderOpacity: Double = 0.30
    @AppStorage("glassShadowOpacity") var glassShadowOpacity: Double = 0.10
    @AppStorage("backgroundOpacity") var backgroundOpacity: Double = 0.10
    @AppStorage("accentColorRaw") private var accentColorRaw = AppThemeColor.blue.rawValue
    @AppStorage("appearanceRaw") private var appearanceRaw = AppAppearance.system.rawValue

    var accentColor: AppThemeColor {
        get { AppThemeColor(rawValue: accentColorRaw) ?? .blue }
        set {
            objectWillChange.send()
            accentColorRaw = newValue.rawValue
        }
    }

    var appearance: AppAppearance {
        get { AppAppearance(rawValue: appearanceRaw) ?? .system }
        set {
            objectWillChange.send()
            appearanceRaw = newValue.rawValue
        }
    }

    func reset() {
        glassOpacity = 0.72
        glassBlur = 18
        glassCornerRadius = 26
        glassBorderOpacity = 0.30
        glassShadowOpacity = 0.10
        backgroundOpacity = 0.10
        accentColorRaw = AppThemeColor.blue.rawValue
        appearanceRaw = AppAppearance.system.rawValue
        scheduleSync()
    }

    // MARK: Firestore Sync

    private var syncTask: Task<Void, Never>?

    /// Debounced write to Firestore (900ms after the last change) — called
    /// on every slider tick, so this avoids hammering Firestore with a
    /// write per pixel of drag.
    func scheduleSync() {
        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            syncNow()
        }
    }

    func syncNow() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(uid).updateData([
            "themeSettings": [
                "glassOpacity": glassOpacity,
                "glassBlur": glassBlur,
                "glassCornerRadius": glassCornerRadius,
                "glassBorderOpacity": glassBorderOpacity,
                "glassShadowOpacity": glassShadowOpacity,
                "backgroundOpacity": backgroundOpacity,
                "accentColor": accentColorRaw,
                "appearance": appearanceRaw
            ]
        ])
    }

    /// Pulls any previously-synced theme down from Firestore — called once
    /// after login so the person's customization follows them to a new
    /// device instead of resetting to defaults.
    func loadFromFirestore() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(uid).getDocument { [weak self] snapshot, _ in
            guard let self, let theme = snapshot?.data()?["themeSettings"] as? [String: Any] else { return }
            DispatchQueue.main.async {
                if let v = theme["glassOpacity"] as? Double { self.glassOpacity = v }
                if let v = theme["glassBlur"] as? Double { self.glassBlur = v }
                if let v = theme["glassCornerRadius"] as? Double { self.glassCornerRadius = v }
                if let v = theme["glassBorderOpacity"] as? Double { self.glassBorderOpacity = v }
                if let v = theme["glassShadowOpacity"] as? Double { self.glassShadowOpacity = v }
                if let v = theme["backgroundOpacity"] as? Double { self.backgroundOpacity = v }
                if let v = theme["accentColor"] as? String { self.accentColorRaw = v }
                if let v = theme["appearance"] as? String { self.appearanceRaw = v }
            }
        }
    }
}

// MARK: - Glass Helpers

struct GlassCard<Content: View>: View {
    @EnvironmentObject private var customization: AppCustomization

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(
                .ultraThinMaterial.opacity(customization.glassOpacity),
                in: RoundedRectangle(
                    cornerRadius: customization.glassCornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: customization.glassCornerRadius,
                    style: .continuous
                )
                .strokeBorder(
                    .white.opacity(customization.glassBorderOpacity),
                    lineWidth: 1
                )
            }
            .shadow(
                color: .black.opacity(customization.glassShadowOpacity),
                radius: customization.glassBlur,
                y: customization.glassBlur / 2
            )
    }
}

struct GlassInput<Content: View>: View {
    @EnvironmentObject private var customization: AppCustomization

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(
                .thinMaterial.opacity(customization.glassOpacity),
                in: RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
                .strokeBorder(
                    .white.opacity(customization.glassBorderOpacity),
                    lineWidth: 1
                )
            }
    }
}

/// Shared ambient background used behind the tab screens — a soft tinted
/// gradient with a couple of blurred glow circles for the "liquid glass" feel.
struct GlassBackground: View {
    @EnvironmentObject private var customization: AppCustomization

    var topGlowOffset: CGPoint = CGPoint(x: -160, y: -300)
    var bottomGlowOffset: CGPoint = CGPoint(x: 170, y: 280)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    customization.accentColor.color.opacity(customization.backgroundOpacity),
                    Color.purple.opacity(customization.backgroundOpacity * 0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(customization.accentColor.color.opacity(0.08))
                .frame(width: 280)
                .blur(radius: 45)
                .offset(x: topGlowOffset.x, y: topGlowOffset.y)

            Circle()
                .fill(Color.purple.opacity(0.08))
                .frame(width: 300)
                .blur(radius: 50)
                .offset(x: bottomGlowOffset.x, y: bottomGlowOffset.y)
        }
    }
}

// MARK: - App Tabs

// MARK: - Content View

struct ContentView: View {
    @StateObject private var customization = AppCustomization()

    @State private var isLoggedIn = Auth.auth().currentUser != nil
    @State private var displayName = ""
    @State private var needsPreferencesSetup = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @State private var activities: [Activity] = [
        Activity(
            id: UUID().uuidString,
            name: "Go explore the neighbouring block/estate",
            description: "",
            age: "Any",
            physical: "Low",
            cost: "Free",
            shelter: "Outdoor",
            time: "15-30 mins",
            requirement: "None",
            points: 10,
            completedCount: 0
        ),
        Activity(
            id: UUID().uuidString,
            name: "Walk along the footpath until you are tired",
            description: "",
            age: "Any",
            physical: "Moderate",
            cost: "Free",
            shelter: "Outdoor",
            time: "30-60 mins",
            requirement: "None",
            points: 15,
            completedCount: 0
        ),
        Activity(
            id: UUID().uuidString,
            name: "Buy a meal from the closest coffee shop/hawker",
            description: "",
            age: "Any",
            physical: "Low",
            cost: "$",
            shelter: "Indoor",
            time: "15-30 mins",
            requirement: "None",
            points: 10,
            completedCount: 0
        ),
        Activity(
            id: UUID().uuidString,
            name: "Check out the neighbourhood playground",
            description: "",
            age: "Kids",
            physical: "Moderate",
            cost: "Free",
            shelter: "Outdoor",
            time: "15-30 mins",
            requirement: "None",
            points: 15,
            completedCount: 0
        ),
        Activity(
            id: UUID().uuidString,
            name: "Visit your childhood playground",
            description: "",
            age: "Teens",
            physical: "Low",
            cost: "Free",
            shelter: "Outdoor",
            time: "15-30 mins",
            requirement: "None",
            points: 20,
            completedCount: 0
        ),
        Activity(
            id: UUID().uuidString,
            name: "Explore a neighbouring estate",
            description: "",
            age: "Any",
            physical: "Moderate",
            cost: "Free",
            shelter: "Outdoor",
            time: "30-60 mins",
            requirement: "None",
            points: 20,
            completedCount: 0
        ),
        Activity(
            id: UUID().uuidString,
            name: "Walk to the closest mall",
            description: "",
            age: "Any",
            physical: "Low",
            cost: "Free",
            shelter: "Both",
            time: "15-30 mins",
            requirement: "None",
            points: 15,
            completedCount: 0
        ),
        Activity(
            id: UUID().uuidString,
            name: "Take the next bus for a random amount of stops and explore the area",
            description: "",
            age: "Teens",
            physical: "Moderate",
            cost: "$",
            shelter: "Both",
            time: "1hr+",
            requirement: "None",
            points: 30,
            completedCount: 0
        ),
        Activity(
            id: UUID().uuidString,
            name: "Check out a new shop/supermarket",
            description: "",
            age: "Any",
            physical: "Low",
            cost: "$",
            shelter: "Indoor",
            time: "15-30 mins",
            requirement: "None",
            points: 10,
            completedCount: 0
        )
    ]

    private let db = Firestore.firestore()

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()
                loggedInContent
            }
        }
        .environmentObject(customization)
        .preferredColorScheme(colorScheme)
        .onAppear {
            loadActivities()
            listenToDisplayName()
            NotificationManager.requestPermissionIfNeeded()
            refreshActivitiesFromSheet()
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { isShowing in hasSeenOnboarding = !isShowing }
        )) {
            OnboardingView(onFinish: { hasSeenOnboarding = true })
                .environmentObject(customization)
        }
    }

    @ViewBuilder
    private var loggedInContent: some View {
        if isLoggedIn {
            if needsPreferencesSetup {
                PreferencesEditorView(onFinish: { needsPreferencesSetup = false })
                    .environmentObject(customization)
            } else {
                TabView {
                    HomeView(activities: activities, displayName: displayName)
                        .tabItem {
                            Label("Home", systemImage: "house.fill")
                        }

                    ProfileView(
                        onLogout: {
                            try? Auth.auth().signOut()
                            isLoggedIn = false
                        }
                    )
                    .tabItem {
                        Label("Profile", systemImage: "person.crop.circle.fill")
                    }

                    LeaderboardView()
                        .tabItem {
                            Label("Friends", systemImage: "person.3.fill")
                        }
                }
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .tint(customization.accentColor.color)
            }
        } else {
            LoginView(onLoginSuccess: {
                isLoggedIn = true
            })
            .padding(.horizontal, 20)
        }
    }

    private var colorScheme: ColorScheme? {
        switch customization.appearance {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    private func loadActivities() {
        isLoggedIn = Auth.auth().currentUser != nil

        db.collection("activities")
            .order(by: "createdAt")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Firestore error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    // Firestore has no activities yet — keep the built-in
                    // sample list instead of wiping the screen blank.
                    return
                }

                let fetched = documents.map { document -> Activity in
                    let data = document.data()

                    return Activity(
                        id: document.documentID,
                        name: data["name"] as? String ?? "",
                        description: data["description"] as? String ?? "",
                        age: data["age"] as? String ?? "Any",
                        physical: data["physical"] as? String ?? "Low",
                        cost: data["cost"] as? String ?? "Free",
                        shelter: data["shelter"] as? String ?? "Outdoor",
                        time: data["time"] as? String ?? "15-30 mins",
                        requirement: data["requirement"] as? String ?? "None",
                        points: data["points"] as? Int ?? 10,
                        completedCount: data["completedCount"] as? Int ?? 0
                    )
                }

                activities = fetched.sorted {
                    $0.completedCount > $1.completedCount
                }
            }
    }

    /// Silently re-imports from the published Google Sheet on every launch,
    /// so activities added/edited there show up automatically — no more
    /// needing to remember to tap an import button. Since `loadActivities()`
    /// above is a live Firestore listener, any changes this writes will
    /// flow straight through to the UI on their own. Failures are ignored
    /// on purpose: if the sheet is briefly unreachable, the app should just
    /// carry on with whatever's already in Firestore.
    private func refreshActivitiesFromSheet() {
        Task {
            _ = try? await SheetImporter.importIntoFirestore(
                fromPublishedSheetURL: SheetImporter.sidequesterSheetURL
            )
        }
    }

    /// Live-updates `displayName` (the current user's username) from
    /// Firestore, so HomeView's greeting stays current — e.g. after the
    /// person changes their username in Edit Profile. Also reschedules
    /// today's streak reminder based on their real completion state.
    private func listenToDisplayName() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users").document(uid).addSnapshotListener { snapshot, error in
            guard let data = snapshot?.data() else { return }
            displayName = data["username"] as? String ?? ""

            // Existing accounts from before this feature won't have a
            // "preferencesSet" field at all — default that to true so we
            // don't retroactively nag people who already have the app.
            // Brand-new signups explicitly write `false`, so this only
            // triggers for people who haven't gone through it yet.
            needsPreferencesSetup = (data["preferencesSet"] as? Bool) == false

            let calendar = Calendar.current
            let lastCompletedAt = (data["lastCompletedAt"] as? Timestamp)?.dateValue()
            let completedToday = lastCompletedAt.map { calendar.isDateInToday($0) } ?? false

            NotificationManager.scheduleStreakReminderForToday(alreadyCompletedToday: completedToday)
        }
    }
}

// MARK: - Username Helpers

/// Normalizes a username the same way everywhere it's stored or queried, so
/// lookups are consistent regardless of casing or stray whitespace.
func normalizedUsername(_ raw: String) -> String {
    raw
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
        .filter { $0.isLetter || $0.isNumber }
}

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject private var customization: AppCustomization

    var onLoginSuccess: () -> Void

    // Shared
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showPassword = false
    @State private var showForgotPassword = false
    @State private var isCreatingAccount = false

    // Log in
    @State private var loginUsername = ""

    // Sign up
    @State private var signUpUsername = ""
    @State private var email = ""
    @State private var confirmPassword = ""

    private let db = Firestore.firestore()

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 46, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    customization.accentColor.color,
                                    .purple
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    .white.opacity(customization.glassBorderOpacity),
                                    lineWidth: 1
                                )
                        }
                        .shadow(
                            color: customization.accentColor.color.opacity(0.15),
                            radius: 20,
                            y: 8
                        )

                    Text("Sidequester")
                        .font(.system(size: 34, weight: .bold))

                    Text("Touch grass. Earn points. Have fun.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                GlassCard {
                    VStack(spacing: 18) {
                        Text(isCreatingAccount ? "Create your account" : "Welcome back")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if isCreatingAccount {
                            GlassInput {
                                HStack(spacing: 12) {
                                    Image(systemName: "person")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)

                                    TextField("Username", text: $signUpUsername)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                }
                            }

                            GlassInput {
                                HStack(spacing: 12) {
                                    Image(systemName: "envelope")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)

                                    TextField("Email", text: $email)
                                        .textInputAutocapitalization(.never)
                                        .keyboardType(.emailAddress)
                                        .autocorrectionDisabled()
                                }
                            }
                        } else {
                            GlassInput {
                                HStack(spacing: 12) {
                                    Image(systemName: "person")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)

                                    TextField("Username", text: $loginUsername)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                }
                            }
                        }

                        GlassInput {
                            HStack(spacing: 12) {
                                Image(systemName: "lock")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)

                                Group {
                                    if showPassword {
                                        TextField("Password", text: $password)
                                    } else {
                                        SecureField("Password", text: $password)
                                    }
                                }

                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(
                                        systemName: showPassword
                                            ? "eye.slash"
                                            : "eye"
                                    )
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if isCreatingAccount {
                            GlassInput {
                                HStack(spacing: 12) {
                                    Image(systemName: "lock.rotation")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)

                                    SecureField("Confirm Password", text: $confirmPassword)
                                }
                            }
                        }

                        if !isCreatingAccount {
                            Button {
                                showForgotPassword = true
                            } label: {
                                Text("Forgot Password?")
                                    .font(.footnote.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        if !errorMessage.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")

                                Text(errorMessage)
                                    .multilineTextAlignment(.leading)
                            }
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            isCreatingAccount ? signUp() : login()
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: isCreatingAccount ? "person.badge.plus" : "arrow.right")
                                    Text(isCreatingAccount ? "Create Account" : "Log In")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .foregroundStyle(.white)
                        .background(
                            LinearGradient(
                                colors: [
                                    customization.accentColor.color,
                                    .purple
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(
                                cornerRadius: 18,
                                style: .continuous
                            )
                        )
                        .disabled(isSubmitDisabled)
                        .opacity(isSubmitDisabled ? 0.55 : 1)

                        Button {
                            withAnimation {
                                isCreatingAccount.toggle()
                                errorMessage = ""
                                password = ""
                                confirmPassword = ""
                            }
                        } label: {
                            Text(
                                isCreatingAccount
                                    ? "Already have an account? Log In"
                                    : "New here? Create an Account"
                            )
                            .font(.footnote.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 40)
        }
        .sheet(isPresented: $showForgotPassword) {
            NavigationStack {
                ForgotPasswordView()
                    .environmentObject(customization)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var isSubmitDisabled: Bool {
        if isLoading { return true }

        if isCreatingAccount {
            return signUpUsername.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty
        } else {
            return loginUsername.isEmpty || password.isEmpty
        }
    }

    /// Username-based login: looks up the email tied to the username in
    /// Firestore, then signs in with Firebase Auth using that email.
    private func login() {
        let cleanUsername = normalizedUsername(loginUsername)

        guard !cleanUsername.isEmpty, !password.isEmpty else {
            return
        }

        isLoading = true
        errorMessage = ""

        db.collection("users")
            .whereField("username", isEqualTo: cleanUsername)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    return
                }

                guard let userDoc = snapshot?.documents.first,
                      let userEmail = userDoc.data()["email"] as? String else {
                    isLoading = false
                    errorMessage = "No account found with that username."
                    return
                }

                Auth.auth().signIn(withEmail: userEmail, password: password) { result, error in
                    isLoading = false

                    if let error = error {
                        errorMessage = error.localizedDescription
                        return
                    }

                    if result?.user != nil {
                        onLoginSuccess()
                    }
                }
            }
    }

    private func signUp() {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUsername = normalizedUsername(signUpUsername)

        guard !cleanUsername.isEmpty, !cleanEmail.isEmpty, !password.isEmpty else {
            return
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }

        isLoading = true
        errorMessage = ""

        // Make sure the username isn't already taken before creating the auth user.
        db.collection("users")
            .whereField("username", isEqualTo: cleanUsername)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    return
                }

                if let existing = snapshot?.documents, !existing.isEmpty {
                    isLoading = false
                    errorMessage = "That username is already taken."
                    return
                }

                Auth.auth().createUser(withEmail: cleanEmail, password: password) { result, error in
                    if let error = error {
                        isLoading = false
                        errorMessage = error.localizedDescription
                        return
                    }

                    guard let user = result?.user else {
                        isLoading = false
                        return
                    }

                    db.collection("users").document(user.uid).setData([
                        "username": cleanUsername,
                        "email": cleanEmail,
                        "points": 0,
                        "streak": 0,
                        "longestStreak": 0,
                        "createdAt": Timestamp(date: Date()),
                        "lifetimeCompletedActivities": 0,
                        "activitiesCreated": 0,
                        "completedActivities": [],
                        "createdActivities": [],
                        "preferencesSet": false
                    ]) { error in
                        isLoading = false

                        if let error = error {
                            errorMessage = error.localizedDescription
                            return
                        }

                        onLoginSuccess()
                    }
                }
            }
    }
}

// MARK: - Forgot Password

struct ForgotPasswordView: View {
    @EnvironmentObject private var customization: AppCustomization
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var email = ""
    @State private var isSending = false
    @State private var message = ""
    @State private var showSuccess = false

    private let db = Firestore.firestore()

    var body: some View {
        ZStack {
            GlassBackground()

            VStack(spacing: 24) {
                Image(systemName: "lock.rotation")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                customization.accentColor.color,
                                .purple
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(
                                .white.opacity(customization.glassBorderOpacity),
                                lineWidth: 1
                            )
                    }

                VStack(spacing: 8) {
                    Text("Forgot Password?")
                        .font(.largeTitle.bold())

                    Text("Enter your username and the email on your account. We'll check they match before sending a reset link.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                GlassCard {
                    VStack(spacing: 16) {
                        GlassInput {
                            HStack(spacing: 12) {
                                Image(systemName: "person")
                                    .foregroundStyle(.secondary)

                                TextField("Username", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                        }

                        GlassInput {
                            HStack(spacing: 12) {
                                Image(systemName: "envelope")
                                    .foregroundStyle(.secondary)

                                TextField("Email on your account", text: $email)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled()
                            }
                        }

                        Button {
                            verifyAndSendResetLink()
                        } label: {
                            HStack {
                                if isSending {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                    Text("Send Reset Link")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .foregroundStyle(.white)
                        .background(
                            LinearGradient(
                                colors: [
                                    customization.accentColor.color,
                                    .purple
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(
                                cornerRadius: 18,
                                style: .continuous
                            )
                        )
                        .disabled(
                            username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            isSending
                        )
                    }
                }

                if !message.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(
                            systemName: showSuccess
                                ? "checkmark.circle.fill"
                                : "exclamationmark.circle.fill"
                        )

                        Text(message)
                            .multilineTextAlignment(.leading)
                    }
                    .font(.footnote)
                    .foregroundStyle(showSuccess ? .green : .red)
                    .padding(.horizontal)
                }

                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back to Login")
                    }
                    .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 500)
        }
        .navigationTitle("Reset Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Looks up the username in Firestore, confirms the entered email matches
    /// the email on file for that account, and only then triggers Firebase's
    /// password reset email. This stops someone from firing off a reset email
    /// for a username without also knowing the email tied to it.
    private func verifyAndSendResetLink() {
        let cleanUsername = normalizedUsername(username)
        let enteredEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !cleanUsername.isEmpty, !enteredEmail.isEmpty else {
            return
        }

        isSending = true
        message = ""
        showSuccess = false

        db.collection("users")
            .whereField("username", isEqualTo: cleanUsername)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    isSending = false
                    message = error.localizedDescription
                    showSuccess = false
                    return
                }

                guard let userDoc = snapshot?.documents.first,
                      let storedEmail = userDoc.data()["email"] as? String else {
                    isSending = false
                    message = "No account found with that username."
                    showSuccess = false
                    return
                }

                guard storedEmail.lowercased() == enteredEmail else {
                    isSending = false
                    message = "That email doesn't match the one on this account."
                    showSuccess = false
                    return
                }

                Auth.auth().sendPasswordReset(withEmail: storedEmail) { error in
                    isSending = false

                    if let error = error {
                        message = error.localizedDescription
                        showSuccess = false
                        return
                    }

                    message = "Password reset link sent! Check your email, including your spam folder."
                    showSuccess = true
                }
            }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
