import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// The signed-in user's own completion history — every post they've made,
/// newest first. Reachable from Profile ("My Quests").
struct MyQuestsView: View {
    @EnvironmentObject private var customization: AppCustomization

    @State private var posts: [Post] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let db = Firestore.firestore()

    var body: some View {
        ZStack {
            GlassBackground(
                topGlowOffset: CGPoint(x: 160, y: -300),
                bottomGlowOffset: CGPoint(x: -170, y: 320)
            )

            ScrollView {
                VStack(spacing: 16) {
                    if let errorMessage {
                        GlassCard {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    } else if isLoading {
                        GlassCard {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        }
                    } else if posts.isEmpty {
                        GlassCard {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.seal")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.secondary)
                                Text("You haven't completed a quest yet — go find one on Home!")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        ForEach(posts) { post in
                            questRow(post)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("My Quests")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { listenToMyQuests() }
    }

    private func questRow(_ post: Post) -> some View {
        GlassCard {
            HStack(spacing: 14) {
                if let url = URL(string: post.photoURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Color.gray.opacity(0.15)
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(post.activityName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)

                    Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Label("\(post.kudosCount)", systemImage: "hands.clap")
                        Label("\(post.commentCount)", systemImage: "bubble.right")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text("+\(post.points)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(customization.accentColor.color.opacity(0.15), in: Capsule())
            }
        }
    }

    private func listenToMyQuests() {
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            errorMessage = "You need to be signed in to see your quest history."
            return
        }

        db.collection("posts")
            .whereField("userId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { snapshot, error in
                isLoading = false

                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }

                errorMessage = nil
                posts = snapshot?.documents.compactMap { doc -> Post? in
                    let data = doc.data()
                    guard let userId = data["userId"] as? String,
                          let username = data["username"] as? String,
                          let activityId = data["activityId"] as? String,
                          let activityName = data["activityName"] as? String,
                          let photoURL = data["photoURL"] as? String else {
                        return nil
                    }

                    let timestamp = data["createdAt"] as? Timestamp

                    return Post(
                        id: doc.documentID,
                        userId: userId,
                        username: username,
                        profileImageURL: data["profileImageURL"] as? String,
                        activityId: activityId,
                        activityName: activityName,
                        photoURL: photoURL,
                        points: data["points"] as? Int ?? 0,
                        createdAt: timestamp?.dateValue() ?? Date(),
                        kudosCount: data["kudosCount"] as? Int ?? 0,
                        commentCount: data["commentCount"] as? Int ?? 0
                    )
                } ?? []
            }
    }
}
