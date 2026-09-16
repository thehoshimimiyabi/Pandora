import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct LeaderboardView: View {
    @EnvironmentObject private var customization: AppCustomization

    struct FriendResult: Identifiable {
        let id: String
        let username: String
        let points: Int
        let profileImageURL: String?
    }

    struct FriendRequest: Identifiable {
        let id: String
        let fromUid: String
        let fromUsername: String
        let fromProfileImageURL: String?
    }

    enum FriendStatus {
        case none, requestSent, requestReceived, friends
    }

    // Search
    @State private var searchText = ""
    @State private var searchResults: [FriendResult] = []
    @State private var isSearching = false
    @State private var searchError: String?

    // Leaderboard
    @State private var leaderboard: [FriendResult] = []
    @State private var isLoadingLeaderboard = true
    @State private var leaderboardError: String?

    // Friends system
    @State private var myUsername = ""
    @State private var myFriendIds: Set<String> = []
    @State private var sentRequestUids: Set<String> = []
    @State private var incomingRequests: [FriendRequest] = []
    @State private var myFriends: [FriendResult] = []

    private let db = Firestore.firestore()

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground(
                    topGlowOffset: CGPoint(x: -170, y: -300),
                    bottomGlowOffset: CGPoint(x: 170, y: 300)
                )

                ScrollView {
                    VStack(spacing: 22) {
                        searchSection

                        if !trimmedQuery.isEmpty {
                            searchResultsSection
                        } else {
                            if !incomingRequests.isEmpty {
                                requestsSection
                            }
                            myFriendsSection
                            leaderboardSection
                        }
                    }
                    .padding()
                    .padding(.bottom, 24)
                }
                .refreshable {
                    listenToLeaderboard()
                    try? await Task.sleep(nanoseconds: 400_000_000)
                }
            }
            .navigationTitle("Friends")
            .onAppear {
                listenToLeaderboard()
                listenToMyProfile()
                listenToFriends()
                listenToIncomingRequests()
                listenToSentRequests()
            }
        }
    }

    // MARK: Search

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Find Friends", systemImage: "magnifyingglass")
                .font(.title3.bold())

            GlassCard {
                GlassInput {
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill.viewfinder")
                            .foregroundStyle(.secondary)

                        TextField("Search by username", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityLabel("Search by username")
                            .onChange(of: searchText) { _, newValue in
                                search(for: newValue)
                            }

                        if isSearching {
                            ProgressView()
                        } else if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                searchResults = []
                                searchError = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("Clear search")
                        }
                    }
                }
            }
        }
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let searchError {
                Text(searchError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if searchResults.isEmpty && !isSearching && searchError == nil {
                GlassCard {
                    Text("No users found.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else if !searchResults.isEmpty {
                GlassCard {
                    VStack(spacing: 14) {
                        ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, result in
                            searchResultRow(result)

                            if index != searchResults.count - 1 {
                                Divider().opacity(0.3)
                            }
                        }
                    }
                }
            }
        }
    }

    private func searchResultRow(_ result: FriendResult) -> some View {
        HStack(spacing: 14) {
            avatar(urlString: result.profileImageURL)

            Text(result.username)
                .font(.subheadline.weight(.medium))

            Spacer()

            Label("\(result.points)", systemImage: "star.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(customization.accentColor.color)

            friendActionButton(for: result)
        }
    }

    // MARK: Friend action button (Add / Pending / Respond / Friends)

    @ViewBuilder
    private func friendActionButton(for result: FriendResult) -> some View {
        switch status(for: result.id) {
        case .friends:
            Label("Friends", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)

        case .requestSent:
            Text("Requested")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.thinMaterial, in: Capsule())

        case .requestReceived:
            Text("Respond below")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

        case .none:
            Button {
                sendFriendRequest(to: result)
            } label: {
                Text("Add")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(customization.accentColor.color, in: Capsule())
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("Add \(result.username) as a friend")
        }
    }

    private func status(for userId: String) -> FriendStatus {
        if myFriendIds.contains(userId) { return .friends }
        if sentRequestUids.contains(userId) { return .requestSent }
        if incomingRequests.contains(where: { $0.fromUid == userId }) { return .requestReceived }
        return .none
    }

    // MARK: Friend Requests

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Friend Requests", systemImage: "person.badge.clock.fill")
                .font(.title3.bold())

            GlassCard {
                VStack(spacing: 14) {
                    ForEach(Array(incomingRequests.enumerated()), id: \.element.id) { index, request in
                        HStack(spacing: 14) {
                            avatar(urlString: request.fromProfileImageURL)

                            Text(request.fromUsername)
                                .font(.subheadline.weight(.medium))

                            Spacer()

                            Button {
                                respond(to: request, accept: true)
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                            }
                            .accessibilityLabel("Accept \(request.fromUsername)'s friend request")

                            Button {
                                respond(to: request, accept: false)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.red)
                            }
                            .accessibilityLabel("Decline \(request.fromUsername)'s friend request")
                        }

                        if index != incomingRequests.count - 1 {
                            Divider().opacity(0.3)
                        }
                    }
                }
            }
        }
    }

    // MARK: My Friends

    private var myFriendsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("My Friends", systemImage: "person.2.fill")
                .font(.title3.bold())

            if myFriends.isEmpty {
                GlassCard {
                    Text("No friends yet — search above to add some!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                GlassCard {
                    VStack(spacing: 14) {
                        ForEach(Array(myFriends.enumerated()), id: \.element.id) { index, friend in
                            HStack(spacing: 14) {
                                avatar(urlString: friend.profileImageURL)

                                Text(friend.username)
                                    .font(.subheadline.weight(.medium))

                                Spacer()

                                Label("\(friend.points)", systemImage: "star.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(customization.accentColor.color)
                            }

                            if index != myFriends.count - 1 {
                                Divider().opacity(0.3)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Leaderboard (live from Firestore)

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Leaderboard", systemImage: "chart.bar.fill")
                .font(.title3.bold())

            if let leaderboardError {
                GlassCard {
                    Text(leaderboardError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if isLoadingLeaderboard {
                GlassCard {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if leaderboard.isEmpty {
                GlassCard {
                    Text("No explorers yet — be the first to earn points!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                GlassCard {
                    VStack(spacing: 14) {
                        ForEach(Array(leaderboard.enumerated()), id: \.element.id) { index, result in
                            HStack(spacing: 14) {
                                Text("#\(index + 1)")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 32, alignment: .leading)

                                avatar(urlString: result.profileImageURL)

                                Text(result.username)
                                    .font(.subheadline.weight(.medium))

                                Spacer()

                                Label("\(result.points)", systemImage: "star.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(customization.accentColor.color)
                            }

                            if index != leaderboard.count - 1 {
                                Divider().opacity(0.3)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Shared

    @ViewBuilder
    private func avatar(urlString: String?) -> some View {
        if let urlString, let url = URL(string: urlString) {
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
            .frame(width: 36, height: 36)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Data — Search

    private func search(for rawText: String) {
        let query = normalizedUsername(rawText)

        guard !query.isEmpty else {
            searchResults = []
            searchError = nil
            isSearching = false
            return
        }

        isSearching = true
        searchError = nil

        db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: query)
            .whereField("username", isLessThanOrEqualTo: query + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments { snapshot, error in
                isSearching = false

                if let error = error {
                    searchError = error.localizedDescription
                    return
                }

                searchResults = snapshot?.documents.compactMap(friendResult(from:)) ?? []
            }
    }

    // MARK: Data — Leaderboard

    private func listenToLeaderboard() {
        db.collection("users")
            .order(by: "points", descending: true)
            .limit(to: 20)
            .addSnapshotListener { snapshot, error in
                isLoadingLeaderboard = false

                if let error = error {
                    leaderboardError = error.localizedDescription
                    return
                }

                leaderboardError = nil
                leaderboard = snapshot?.documents.compactMap(friendResult(from:)) ?? []
            }
    }

    private func friendResult(from doc: QueryDocumentSnapshot) -> FriendResult? {
        let data = doc.data()
        guard let username = data["username"] as? String else { return nil }
        return FriendResult(
            id: doc.documentID,
            username: username,
            points: data["points"] as? Int ?? 0,
            profileImageURL: data["profileImageURL"] as? String
        )
    }

    // MARK: Data — Friends system

    private func listenToMyProfile() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).addSnapshotListener { snapshot, _ in
            myUsername = snapshot?.data()?["username"] as? String ?? ""
        }
    }

    private func listenToFriends() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("friends")
            .addSnapshotListener { snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                myFriendIds = Set(documents.map { $0.documentID })
                myFriends = documents.map { doc in
                    let data = doc.data()
                    return FriendResult(
                        id: doc.documentID,
                        username: data["username"] as? String ?? "",
                        points: data["points"] as? Int ?? 0,
                        profileImageURL: data["profileImageURL"] as? String
                    )
                }
            }
    }

    private func listenToIncomingRequests() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("friendRequests")
            .whereField("toUid", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snapshot, _ in
                incomingRequests = snapshot?.documents.compactMap { doc in
                    let data = doc.data()
                    guard let fromUid = data["fromUid"] as? String,
                          let fromUsername = data["fromUsername"] as? String else {
                        return nil
                    }
                    return FriendRequest(
                        id: doc.documentID,
                        fromUid: fromUid,
                        fromUsername: fromUsername,
                        fromProfileImageURL: data["fromProfileImageURL"] as? String
                    )
                } ?? []
            }
    }

    private func listenToSentRequests() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("friendRequests")
            .whereField("fromUid", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snapshot, _ in
                sentRequestUids = Set(
                    snapshot?.documents.compactMap { $0.data()["toUid"] as? String } ?? []
                )
            }
    }

    private func sendFriendRequest(to result: FriendResult) {
        guard let uid = Auth.auth().currentUser?.uid, uid != result.id else { return }

        db.collection("friendRequests").addDocument(data: [
            "fromUid": uid,
            "fromUsername": myUsername,
            "fromProfileImageURL": nil as Any,
            "toUid": result.id,
            "toUsername": result.username,
            "status": "pending",
            "createdAt": Timestamp(date: Date())
        ])
    }

    private func respond(to request: FriendRequest, accept: Bool) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let requestRef = db.collection("friendRequests").document(request.id)

        if accept {
            requestRef.updateData(["status": "accepted"])

            // Mutual friendship: one doc on each side, denormalized for
            // quick display without extra lookups.
            db.collection("users").document(request.fromUid).getDocument { snapshot, _ in
                let theirData = snapshot?.data() ?? [:]

                db.collection("users").document(uid).collection("friends").document(request.fromUid).setData([
                    "username": request.fromUsername,
                    "profileImageURL": theirData["profileImageURL"] as? String as Any,
                    "points": theirData["points"] as? Int ?? 0,
                    "since": Timestamp(date: Date())
                ])
            }

            db.collection("users").document(uid).getDocument { snapshot, _ in
                let myData = snapshot?.data() ?? [:]

                db.collection("users").document(request.fromUid).collection("friends").document(uid).setData([
                    "username": myData["username"] as? String ?? myUsername,
                    "profileImageURL": myData["profileImageURL"] as? String as Any,
                    "points": myData["points"] as? Int ?? 0,
                    "since": Timestamp(date: Date())
                ])
            }
        } else {
            requestRef.updateData(["status": "declined"])
        }
    }
}
