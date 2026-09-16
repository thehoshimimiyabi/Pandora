import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct HomeView: View {
    @EnvironmentObject private var customization: AppCustomization
    let activities: [Activity]
    let displayName: String

    private var featured: Activity? { activities.max { $0.points < $1.points } }
    private var recommended: [Activity] { Array(activities.shuffled().prefix(3)) }

    // MARK: Feed state

    @State private var posts: [Post] = []
    @State private var kudosedPostIds: Set<String> = []
    @State private var isFeedLoading = true
    @State private var feedErrorMessage: String?
    @State private var activeCommentsPost: Post?
    @State private var postToReport: Post?
    @State private var myFriendIds: Set<String> = []
    @State private var feedScope: FeedScope = .everyone

    enum FeedScope: String, CaseIterable {
        case everyone = "Everyone"
        case friends = "Friends"
    }

    private var visiblePosts: [Post] {
        guard feedScope == .friends, let myUid = Auth.auth().currentUser?.uid else { return posts }
        return posts.filter { $0.userId == myUid || myFriendIds.contains($0.userId) }
    }

    private let db = Firestore.firestore()

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground(topGlowOffset: CGPoint(x: -180, y: -260), bottomGlowOffset: CGPoint(x: 160, y: 340))
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        hero
                        if let featured { featuredCard(featured) }
                        stats
                        feedSection
                        activitySection("Recommended For You", icon: "sparkles", activities: recommended)
                        activitySection("Trending", icon: "flame.fill", activities: activities.sorted { $0.points > $1.points }.prefix(5).map { $0 })
                    }
                    .padding()
                }
                .refreshable {
                    listenToFeed()
                    try? await Task.sleep(nanoseconds: 400_000_000)
                }
            }
            .navigationTitle("Sidequester")
            .onAppear {
                listenToFeed()
                listenToMyFriends()
            }
            .sheet(item: $activeCommentsPost) { post in
                NavigationStack {
                    CommentsView(post: post)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .confirmationDialog(
                "Report this post?",
                isPresented: Binding(
                    get: { postToReport != nil },
                    set: { if !$0 { postToReport = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Report", role: .destructive) {
                    if let postToReport {
                        reportPost(postToReport)
                    }
                    postToReport = nil
                }
                Button("Cancel", role: .cancel) {
                    postToReport = nil
                }
            } message: {
                Text("We'll take a look — this won't notify the person who posted it.")
            }
        }
    }

    private var hero: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome back").foregroundStyle(.secondary)
                    Text("Hi, \(displayName.isEmpty ? "Explorer" : displayName)").font(.title2.bold())
                    Text("Ready for a sidequest?").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "sparkles").font(.system(size: 30)).foregroundStyle(customization.accentColor.color)
            }
        }
    }

    private func featuredCard(_ activity: Activity) -> some View {
        NavigationLink(destination: ActivityDetailView(activity: activity)) {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("TOP QUEST", systemImage: "wand.and.stars").font(.caption.bold()).foregroundStyle(customization.accentColor.color)
                    Text(activity.name).font(.title3.bold()).foregroundStyle(.primary)
                    Text("\(activity.points) points · \(activity.time)").font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private var stats: some View {
        HStack(spacing: 12) {
            stat("\(activities.count)", "Quests", "map.fill")
            stat("\(activities.filter { $0.cost.lowercased() == "free" }.count)", "Free", "gift.fill")
            stat("\(activities.filter { $0.shelter.lowercased().contains("outdoor") }.count)", "Outdoor", "leaf.fill")
        }
    }

    private func stat(_ value: String, _ label: String, _ icon: String) -> some View {
        GlassCard {
            VStack(spacing: 5) {
                Image(systemName: icon).foregroundStyle(customization.accentColor.color)
                Text(value).font(.headline)
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Feed

    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Feed", systemImage: "camera.fill")
                    .font(.title3.bold())

                Spacer()

                Picker("Feed scope", selection: $feedScope) {
                    ForEach(FeedScope.allCases, id: \.self) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            if let feedErrorMessage {
                GlassCard {
                    Text(feedErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } else if isFeedLoading {
                GlassCard {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if visiblePosts.isEmpty {
                GlassCard {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.on.rectangle")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text(
                            feedScope == .friends
                                ? "None of your friends have posted yet."
                                : "No completions yet — be the first to post one!"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 14) {
                    ForEach(visiblePosts) { post in
                        postCard(post)
                    }
                }
            }
        }
    }

    private func postCard(_ post: Post) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    avatar(for: post)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.username)
                            .font(.subheadline.weight(.semibold))
                        Text(post.activityName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("+\(post.points)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(customization.accentColor.color.opacity(0.15), in: Capsule())
                }

                if let url = URL(string: post.photoURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 180)
                        default:
                            Color.gray.opacity(0.15)
                                .frame(height: 180)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .clipped()
                }

                HStack(spacing: 20) {
                    Button {
                        toggleKudos(for: post)
                    } label: {
                        Label(
                            "\(post.kudosCount)",
                            systemImage: kudosedPostIds.contains(post.id) ? "hands.clap.fill" : "hands.clap"
                        )
                        .foregroundStyle(
                            kudosedPostIds.contains(post.id) ? customization.accentColor.color : .secondary
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(kudosedPostIds.contains(post.id) ? "Remove kudos" : "Give kudos")

                    Button {
                        activeCommentsPost = post
                    } label: {
                        Label("\(post.commentCount)", systemImage: "bubble.right")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View comments")

                    if let url = URL(string: post.photoURL) {
                        ShareLink(
                            item: url,
                            subject: Text(post.activityName),
                            message: Text("\(post.username) completed \"\(post.activityName)\" on Sidequester! 🎉")
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("Share this post")
                    }

                    Spacer()

                    if let matchingActivity = activities.first(where: { $0.id == post.activityId }) {
                        NavigationLink(destination: ActivityDetailView(activity: matchingActivity)) {
                            Label("Try This", systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(customization.accentColor.color)
                    }

                    Menu {
                        Button(role: .destructive) {
                            postToReport = post
                        } label: {
                            Label("Report Post", systemImage: "flag")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("More options")
                }
                .font(.subheadline)
            }
        }
    }

    @ViewBuilder
    private func avatar(for post: Post) -> some View {
        if let urlString = post.profileImageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Feed Data

    private func listenToMyFriends() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("friends")
            .addSnapshotListener { snapshot, _ in
                myFriendIds = Set(snapshot?.documents.map { $0.documentID } ?? [])
            }
    }

    private func reportPost(_ post: Post) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("reports").addDocument(data: [
            "postId": post.id,
            "reportedUserId": post.userId,
            "reporterId": uid,
            "reason": "inappropriate",
            "createdAt": Timestamp(date: Date())
        ])
    }

    private func listenToFeed() {
        db.collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: 30)
            .addSnapshotListener { snapshot, error in
                isFeedLoading = false

                if let error = error {
                    feedErrorMessage = error.localizedDescription
                    return
                }

                feedErrorMessage = nil
                posts = snapshot?.documents.compactMap(post(from:)) ?? []
                refreshMyKudos()
            }
    }

    private func post(from doc: QueryDocumentSnapshot) -> Post? {
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
    }

    /// Checks which visible posts the signed-in user has already given
    /// kudos to, so the button reflects the right filled/unfilled state.
    private func refreshMyKudos() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        for post in posts {
            db.collection("posts").document(post.id).collection("kudos").document(uid)
                .getDocument { snapshot, _ in
                    if snapshot?.exists == true {
                        kudosedPostIds.insert(post.id)
                    } else {
                        kudosedPostIds.remove(post.id)
                    }
                }
        }
    }

    private func toggleKudos(for post: Post) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let postRef = db.collection("posts").document(post.id)
        let kudosRef = postRef.collection("kudos").document(uid)
        let alreadyKudosed = kudosedPostIds.contains(post.id)

        // Optimistic local update so the tap feels instant.
        if alreadyKudosed {
            kudosedPostIds.remove(post.id)
        } else {
            kudosedPostIds.insert(post.id)
        }

        if alreadyKudosed {
            kudosRef.delete()
            postRef.updateData(["kudosCount": FieldValue.increment(Int64(-1))])
        } else {
            kudosRef.setData(["createdAt": Timestamp(date: Date())])
            postRef.updateData(["kudosCount": FieldValue.increment(Int64(1))])
        }
    }

    // MARK: Sections

    private func activitySection(_ title: String, icon: String, activities: [Activity]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.title3.bold())
            GlassCard {
                VStack(spacing: 12) {
                    ForEach(activities) { activity in
                        NavigationLink(destination: ActivityDetailView(activity: activity)) {
                            ActivityCard(activity: activity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
