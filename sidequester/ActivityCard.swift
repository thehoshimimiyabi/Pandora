import SwiftUI

struct ActivityCard: View {
    let activity: Activity

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(activity.name)
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                Text("\(activity.completedCount) completed")
                    .font(.subheadline)
            }
            .foregroundStyle(.primary.opacity(0.72))

            HStack(spacing: 14) {
                Label("\(activity.points) pts", systemImage: "star.fill")
                Label(activity.time, systemImage: "clock")
                Label(activity.cost, systemImage: "dollarsign.circle")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.primary.opacity(0.72))

            HStack(spacing: 6) {
                Text(activity.physical)
                Text("•")
                Text(activity.shelter)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.primary.opacity(0.6))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
