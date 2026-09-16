import Foundation

/// A single "I completed this activity" post in the Feed tab — the
/// Strava/Instagram-style unit that friends can kudos and comment on.
struct Post: Identifiable, Hashable {
    let id: String
    let userId: String
    let username: String
    let profileImageURL: String?
    let activityId: String
    let activityName: String
    let photoURL: String
    let points: Int
    let createdAt: Date
    let kudosCount: Int
    let commentCount: Int
}
