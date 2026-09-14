import SwiftUI
import FirebaseFirestore

struct FriendsView: View {
    @EnvironmentObject private var customization: AppCustomization
    @State private var username = ""
    @State private var result: Friend?
    @State private var message = ""
    @State private var loading = false
    private let db = Firestore.firestore()

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()
                VStack(spacing: 18) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Find explorers", systemImage: "person.text.rectangle").font(.title3.bold())
                            Text("Search using their username.").foregroundStyle(.secondary)
                            HStack {
                                TextField("Username", text: $username).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
                                Button(action: search) { loading ? AnyView(ProgressView()) : AnyView(Image(systemName: "magnifyingglass")) }
                                    .buttonStyle(.borderedProminent).tint(customization.accentColor.color)
                            }
                        }
                    }
                    if let result { friendCard(result) }
                    else if !message.isEmpty { Text(message).foregroundStyle(.secondary) }
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Friends")
        }
    }

    private func friendCard(_ friend: Friend) -> some View {
        GlassCard {
            VStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill").font(.system(size: 64)).foregroundStyle(customization.accentColor.color)
                Text(friend.displayName).font(.title2.bold())
                Text("@\(friend.username)").foregroundStyle(.secondary)
                Label("\(friend.points) Explorer Points", systemImage: "sparkles").foregroundStyle(.orange)
            }.frame(maxWidth: .infinity)
        }
    }

    private func search() {
        let clean = normalizedUsername(username); guard !clean.isEmpty else { return }
        loading = true; result = nil; message = ""
        db.collection("users").whereField("username", isEqualTo: clean).limit(to: 1).getDocuments { snapshot, error in
            loading = false
            if let error { message = error.localizedDescription; return }
            guard let document = snapshot?.documents.first else { message = "No explorer found with that username."; return }
            let data = document.data()
            result = Friend(username: data["username"] as? String ?? clean, displayName: data["displayName"] as? String ?? clean, points: data["points"] as? Int ?? 0)
        }
    }
}

private struct Friend { let username: String; let displayName: String; let points: Int }
