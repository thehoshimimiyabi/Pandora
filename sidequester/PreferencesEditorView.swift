import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Model

/// A person's activity preferences — used both to personalize "Recommended
/// For You" on Home and just as a nicer, more tailored first-run experience.
/// Every dimension defaults to "Any" (no preference).
struct ActivityPreferences: Equatable {
    var age = "Any"
    var physical = "Any"
    var cost = "Any"
    var shelter = "Any"

    static let ageOptions = ["Any", "Kids", "Teens", "Adults", "Seniors"]
    static let physicalOptions = ["Any", "Low", "Moderate", "High"]
    static let costOptions = ["Any", "Free", "$", "$$", "$$$"]
    static let shelterOptions = ["Any", "Indoor", "Outdoor", "Both"]

    /// Reads a preferences map back out of a Firestore user document. Missing
    /// or malformed fields just fall back to "Any" rather than failing.
    static func from(firestoreData data: [String: Any]?) -> ActivityPreferences {
        guard let raw = data?["preferences"] as? [String: String] else {
            return ActivityPreferences()
        }
        var prefs = ActivityPreferences()
        prefs.age = raw["age"] ?? "Any"
        prefs.physical = raw["physical"] ?? "Any"
        prefs.cost = raw["cost"] ?? "Any"
        prefs.shelter = raw["shelter"] ?? "Any"
        return prefs
    }

    var asFirestoreMap: [String: String] {
        ["age": age, "physical": physical, "cost": cost, "shelter": shelter]
    }

    /// How well a given activity matches these preferences — used to bias
    /// "Recommended For You" toward things the person actually said they like.
    func matchScore(for activity: Activity) -> Int {
        var score = 0
        if age == "Any" || activity.age == age { score += 1 }
        if physical == "Any" || activity.physical == physical { score += 1 }
        if cost == "Any" || activity.cost == cost { score += 1 }
        if shelter == "Any" || activity.shelter == shelter || activity.shelter == "Both" { score += 1 }
        return score
    }
}

// MARK: - Shared Form

/// The reusable picker form — embedded in both the post-signup setup screen
/// and the Profile "Edit Preferences" screen so the two stay visually
/// identical.
struct PreferencesFormView: View {
    @Binding var preferences: ActivityPreferences

    var body: some View {
        GlassCard {
            VStack(spacing: 18) {
                preferenceRow(title: "Age Range", systemImage: "person.fill", selection: $preferences.age, options: ActivityPreferences.ageOptions)
                Divider().opacity(0.3)
                preferenceRow(title: "Effort Level", systemImage: "figure.walk", selection: $preferences.physical, options: ActivityPreferences.physicalOptions)
                Divider().opacity(0.3)
                preferenceRow(title: "Cost", systemImage: "dollarsign.circle", selection: $preferences.cost, options: ActivityPreferences.costOptions)
                Divider().opacity(0.3)
                preferenceRow(title: "Indoor / Outdoor", systemImage: "leaf.fill", selection: $preferences.shelter, options: ActivityPreferences.shelterOptions)
            }
        }
    }

    private func preferenceRow(title: String, systemImage: String, selection: Binding<String>, options: [String]) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))

            Spacer()

            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

// MARK: - Post-Signup Setup

/// Shown once, right after account creation, before entering the main app.
/// "Skip" is always available — preferences are a nice-to-have, never a
/// blocker — and just saves the all-"Any" defaults.
struct PreferencesEditorView: View {
    @EnvironmentObject private var customization: AppCustomization
    var onFinish: () -> Void

    @State private var preferences = ActivityPreferences()
    @State private var isSaving = false

    private let db = Firestore.firestore()

    var body: some View {
        ZStack {
            GlassBackground()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 46))
                        .foregroundStyle(
                            LinearGradient(colors: [customization.accentColor.color, .purple], startPoint: .top, endPoint: .bottom)
                        )

                    Text("What are you into?")
                        .font(.title.bold())

                    Text("This helps us recommend quests you'll actually enjoy. You can always change it later.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                PreferencesFormView(preferences: $preferences)
                    .padding(.horizontal, 20)

                Spacer()

                Button {
                    save()
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Continue").fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .foregroundStyle(.white)
                .background(
                    LinearGradient(colors: [customization.accentColor.color, .purple], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .padding(.horizontal, 24)
                .disabled(isSaving)

                Button("Skip for now") { save() }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .disabled(isSaving)
                    .padding(.bottom, 12)
            }
        }
    }

    private func save() {
        guard let uid = Auth.auth().currentUser?.uid else {
            onFinish()
            return
        }

        isSaving = true

        db.collection("users").document(uid).updateData([
            "preferences": preferences.asFirestoreMap,
            "preferencesSet": true
        ]) { _ in
            isSaving = false
            onFinish()
        }
    }
}

// MARK: - Edit From Profile

/// Reachable from Profile > Account > Preferences. Loads the person's
/// existing preferences first, then lets them change and save.
struct EditPreferencesView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var preferences = ActivityPreferences()
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage = ""

    private let db = Firestore.firestore()

    var body: some View {
        ZStack {
            GlassBackground()

            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView().padding(.top, 40)
                    } else {
                        PreferencesFormView(preferences: $preferences)

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        Button {
                            save()
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Save").fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .foregroundStyle(.white)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .disabled(isSaving)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { load() }
    }

    private func load() {
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }

        db.collection("users").document(uid).getDocument { snapshot, _ in
            preferences = ActivityPreferences.from(firestoreData: snapshot?.data())
            isLoading = false
        }
    }

    private func save() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        isSaving = true
        errorMessage = ""

        db.collection("users").document(uid).updateData([
            "preferences": preferences.asFirestoreMap,
            "preferencesSet": true
        ]) { error in
            isSaving = false

            if let error = error {
                errorMessage = error.localizedDescription
                return
            }

            dismiss()
        }
    }
}
