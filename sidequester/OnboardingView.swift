import SwiftUI

/// A short first-launch carousel. Shown once via ContentView, gated by an
/// @AppStorage flag.
struct OnboardingView: View {
    @EnvironmentObject private var customization: AppCustomization
    var onFinish: () -> Void

    @State private var page = 0

    private struct Page {
        let icon: String
        let title: String
        let description: String
    }

    private let pages: [Page] = [
        Page(
            icon: "figure.walk.motion",
            title: "Welcome to Sidequester",
            description: "Turn boring afternoons into bite-sized real-world quests."
        ),
        Page(
            icon: "star.fill",
            title: "Earn Points",
            description: "Complete quests, snap a proof photo, and rack up points, streaks, and achievements."
        ),
        Page(
            icon: "camera.fill",
            title: "Share & Get Kudos",
            description: "Every completion posts to the Feed — friends can kudos and comment, Strava-style."
        ),
        Page(
            icon: "person.3.fill",
            title: "Add Friends",
            description: "Search by username, send friend requests, and compare points on the leaderboard."
        )
    ]

    var body: some View {
        ZStack {
            GlassBackground()

            VStack(spacing: 24) {
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button {
                    if page < pages.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(page < pages.count - 1 ? "Next" : "Get Started")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [customization.accentColor.color, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .padding(.horizontal, 24)
                .accessibilityLabel(page < pages.count - 1 ? "Next" : "Get started")

                if page < pages.count - 1 {
                    Button("Skip") { onFinish() }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Color.clear.frame(height: 16)
                }
            }
            .padding(.bottom, 30)
        }
    }

    private func pageView(_ page: Page) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 70))
                .foregroundStyle(
                    LinearGradient(
                        colors: [customization.accentColor.color, .purple],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text(page.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text(page.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}
