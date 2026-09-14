import SwiftUI
import FirebaseFirestore

struct LeaderboardView: View {
    @EnvironmentObject private var customization: AppCustomization

    struct FriendResult: Identifiable {
        let id: String
        let username: String
        let points: Int
        let profileImageURL: String?
    }

    @State private var searchText = ""
    @State private var searchResults: [FriendResult] = []
    @State private var isSearching = false
    @State private var searchError: String?

    @State private var leaderboard: [FriendResult] = []
    @State private var isLoadingLeaderboard = true
    @State private var leaderboardError: String?

    private let db = Firestore.firestore()
    private var leaderboardListener: ListenerRegistration?

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
                            leaderboardSection
                        }
                    }
                    .padding()
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Friends")
            .onAppear { listenToLeaderboard() }
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
                            friendRow(result, rank: nil)

                            if index != searchResults.count - 1 {
                                Divider().opacity(0.3)
                            }
                        }
                    }
                }
            }
        }
    }

    private func friendRow(_ result: FriendResult, rank: Int?) -> some View {
        HStack(spacing: 14) {
            if let rank {
                Text("#\(rank)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .leading)
            }

            avatar(for: result)

            Text(result.username)
                .font(.subheadline.weight(.medium))

            Spacer()

            Label("\(result.points)", systemImage: "star.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(customization.accentColor.color)
        }
    }

    @ViewBuilder
    private func avatar(for result: FriendResult) -> some View {
        if let urlString = result.profileImageURL, let url = URL(string: urlString) {
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
                            friendRow(result, rank: index + 1)

                            if index != leaderboard.count - 1 {
                                Divider().opacity(0.3)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Live-updates the top 20 users by points, straight from Firestore.
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
}
