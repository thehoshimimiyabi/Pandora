import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var customization: AppCustomization
    let activities: [Activity]
    let displayName: String

    private var featured: Activity? { activities.max { $0.points < $1.points } }
    private var recommended: [Activity] { Array(activities.shuffled().prefix(3)) }

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground(topGlowOffset: CGPoint(x: -180, y: -260), bottomGlowOffset: CGPoint(x: 160, y: 340))
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        hero
                        if let featured { featuredCard(featured) }
                        stats
                        activitySection("Recommended For You", icon: "sparkles", activities: recommended)
                        activitySection("Trending", icon: "flame.fill", activities: activities.sorted { $0.points > $1.points }.prefix(5).map { $0 })
                    }
                    .padding()
                }
            }
            .navigationTitle("Sidequester")
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
