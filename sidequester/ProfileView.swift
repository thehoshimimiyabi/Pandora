//
//  ProfileView.swift
//  sidequester
//
//  The merged Points + Achievements + Customize + Account tab. Loads the
//  signed-in user's username, points, and profile picture live from
//  Firestore, and lets them jump into EditProfileView to change either.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

private struct AchievementDefinition: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let threshold: Int
}

private let achievementDefinitions: [AchievementDefinition] = [
    AchievementDefinition(title: "Bronze Explorer", description: "Earn 100 points.", icon: "medal.fill", threshold: 100),
    AchievementDefinition(title: "Adventurer", description: "Earn 500 points.", icon: "figure.walk", threshold: 500),
    AchievementDefinition(title: "SideQuest Master", description: "Earn 1000 points.", icon: "star.fill", threshold: 1000),
    AchievementDefinition(title: "Legendary Wanderer", description: "Earn 5000 points.", icon: "trophy.fill", threshold: 5000)
]

struct ProfileView: View {
    @EnvironmentObject private var customization: AppCustomization

    var onLogout: () -> Void

    @State private var username = ""
    @State private var points = 0
    @State private var profileImageURL: String?
    @State private var streak = 0
    @State private var longestStreak = 0
    @State private var lifetimeCompletedActivities = 0
    @State private var activitiesCreated = 0

    @State private var showLogoutConfirmation = false
    @State private var showEditProfile = false

    private let db = Firestore.firestore()

    private var unlockedCount: Int {
        achievementDefinitions.filter { points >= $0.threshold }.count
    }

    private var nextMilestone: AchievementDefinition? {
        achievementDefinitions.first { points < $0.threshold }
    }

    private var progressToNextMilestone: Double {
        guard let next = nextMilestone else { return 1.0 }
        let previousThreshold = achievementDefinitions
            .last(where: { $0.threshold <= points })?.threshold ?? 0
        let span = Double(next.threshold - previousThreshold)
        guard span > 0 else { return 1.0 }
        return min(1.0, max(0.0, Double(points - previousThreshold) / span))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground(
                    topGlowOffset: CGPoint(x: 150, y: -280),
                    bottomGlowOffset: CGPoint(x: -160, y: 320)
                )

                ScrollView {
                    VStack(spacing: 22) {
                        pointsHeader
                        statsSection
                        achievementsSection
                        appearanceSection
                        glassinessSection
                        accountSection
                    }
                    .padding()
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Profile")
            .onAppear { listenToProfile() }
            .sheet(isPresented: $showEditProfile) {
                NavigationStack {
                    EditProfileView(
                        currentUsername: username,
                        currentImageURL: profileImageURL
                    )
                    .environmentObject(customization)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: Header

    private var pointsHeader: some View {
        GlassCard {
            VStack(spacing: 16) {
                Button {
                    showEditProfile = true
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        avatarView

                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, customization.accentColor.color)
                    }
                }
                .buttonStyle(.plain)

                VStack(spacing: 4) {
                    Text(username.isEmpty ? "Explorer" : username)
                        .font(.title3.bold())

                    Button {
                        showEditProfile = true
                    } label: {
                        Label("Edit Profile", systemImage: "pencil")
                            .font(.caption.weight(.semibold))
                    }
                }

                Text("\(points)")
                    .font(.system(size: 54, weight: .bold, design: .rounded))

                Text("Explorer Points")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                RankBadge(points: points)

                if let nextMilestone {
                    VStack(spacing: 6) {
                        HStack {
                            Text("Next: \(nextMilestone.title)")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text("\(nextMilestone.threshold - points) pts to go")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(.thinMaterial)
                                    .frame(height: 8)

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [customization.accentColor.color, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * progressToNextMilestone, height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [customization.accentColor.color, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(0.15)
                .frame(width: 96, height: 96)
                .blur(radius: 10)

            if let profileImageURL, let url = URL(string: profileImageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [customization.accentColor.color, .purple],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
                .frame(width: 88, height: 88)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [customization.accentColor.color, .purple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }

    // MARK: Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Stats", systemImage: "chart.bar.fill")
                .font(.title3.bold())

            GlassCard {
                HStack(spacing: 0) {
                    statTile(value: "\(streak)", label: "Day Streak", icon: "flame.fill")
                    Divider().frame(height: 44)
                    statTile(value: "\(longestStreak)", label: "Best Streak", icon: "trophy.fill")
                    Divider().frame(height: 44)
                    statTile(value: "\(lifetimeCompletedActivities)", label: "Completed", icon: "checkmark.seal.fill")
                    Divider().frame(height: 44)
                    statTile(value: "\(activitiesCreated)", label: "Created", icon: "plus.circle.fill")
                }
            }
        }
    }

    private func statTile(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(customization.accentColor.color)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Achievements

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Achievements", systemImage: "trophy.fill")
                    .font(.title3.bold())
                Spacer()
                Text("\(unlockedCount)/\(achievementDefinitions.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
            }

            GlassCard {
                VStack(spacing: 14) {
                    ForEach(Array(achievementDefinitions.enumerated()), id: \.element.id) { index, definition in
                        AchievementCard(
                            title: definition.title,
                            description: definition.description,
                            icon: definition.icon,
                            unlocked: points >= definition.threshold
                        )

                        if index != achievementDefinitions.count - 1 {
                            Divider().opacity(0.3)
                        }
                    }
                }
            }
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Appearance", systemImage: "paintpalette.fill")
                .font(.title3.bold())

            GlassCard {
                VStack(spacing: 18) {
                    Picker("Mode", selection: Binding(
                        get: { customization.appearance },
                        set: { customization.appearance = $0 }
                    )) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.displayName)
                                .tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Accent Color")
                            .font(.subheadline.weight(.semibold))

                        HStack(spacing: 14) {
                            ForEach(AppThemeColor.allCases) { color in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        customization.accentColor = color
                                    }
                                } label: {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 32, height: 32)
                                        .overlay {
                                            Circle()
                                                .strokeBorder(.white, lineWidth: customization.accentColor == color ? 3 : 0)
                                        }
                                        .overlay {
                                            Circle()
                                                .strokeBorder(.black.opacity(0.08), lineWidth: 1)
                                        }
                                        .shadow(
                                            color: color.color.opacity(customization.accentColor == color ? 0.4 : 0),
                                            radius: 6
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: Liquid Glass Tuning

    private var glassinessSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Liquid Glass", systemImage: "drop.fill")
                .font(.title3.bold())

            GlassCard {
                VStack(spacing: 18) {
                    glassSlider(
                        title: "Glassiness",
                        valueLabel: "\(Int(customization.glassOpacity * 100))%",
                        value: $customization.glassOpacity,
                        range: 0.15...1.0
                    )

                    glassSlider(
                        title: "Blur / Glow",
                        valueLabel: "\(Int(customization.glassBlur))",
                        value: $customization.glassBlur,
                        range: 0...45
                    )

                    glassSlider(
                        title: "Corner Radius",
                        valueLabel: "\(Int(customization.glassCornerRadius))",
                        value: $customization.glassCornerRadius,
                        range: 8...45
                    )

                    glassSlider(
                        title: "Glass Border",
                        valueLabel: "\(Int(customization.glassBorderOpacity * 100))%",
                        value: $customization.glassBorderOpacity,
                        range: 0...0.8
                    )

                    glassSlider(
                        title: "Background Glow",
                        valueLabel: "\(Int(customization.backgroundOpacity * 100))%",
                        value: $customization.backgroundOpacity,
                        range: 0...0.30
                    )

                    Button {
                        withAnimation {
                            customization.reset()
                        }
                    } label: {
                        Text("Reset All Customization")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundStyle(.red)
                }
            }
        }
    }

    private func glassSlider(
        title: String,
        valueLabel: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(valueLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: range)
        }
    }

    // MARK: Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Account", systemImage: "gearshape.fill")
                .font(.title3.bold())

            GlassCard {
                VStack(spacing: 0) {
                    NavigationLink(destination: MyQuestsView()) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                            Text("My Quests")
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                    }

                    Divider().opacity(0.3).padding(.vertical, 12)

                    NavigationLink(destination: EditPreferencesView()) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Text("Preferences")
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                    }

                    Divider().opacity(0.3).padding(.vertical, 12)

                    Button {
                        showLogoutConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Log Out")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .confirmationDialog(
            "Log out of Sidequester?",
            isPresented: $showLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Log Out", role: .destructive) {
                onLogout()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Data

    private func listenToProfile() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users").document(uid).addSnapshotListener { snapshot, error in
            guard let data = snapshot?.data() else { return }
            username = data["username"] as? String ?? ""
            points = data["points"] as? Int ?? 0
            profileImageURL = data["profileImageURL"] as? String
            streak = data["streak"] as? Int ?? 0
            longestStreak = data["longestStreak"] as? Int ?? 0
            lifetimeCompletedActivities = data["lifetimeCompletedActivities"] as? Int ?? 0
            activitiesCreated = data["activitiesCreated"] as? Int ?? 0
        }
    }
}
