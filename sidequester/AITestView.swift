import SwiftUI

@available(iOS 27.0, *)
struct AITestView: View {

    @State private var activityName = "Walk around my neighbourhood"
    @State private var activityDescription =
        "Walk for 30 minutes and explore an area I haven't visited before."
    @State private var duration = "30 minutes"
    @State private var points = 6

    @State private var result = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Activity")
                            .font(.headline)

                        TextField(
                            "Activity name",
                            text: $activityName
                        )
                        .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)

                        TextEditor(text: $activityDescription)
                            .frame(height: 120)
                            .padding(8)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.gray.opacity(0.3))
                            }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Duration")
                            .font(.headline)

                        TextField(
                            "Duration",
                            text: $duration
                        )
                        .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Proposed Points")
                            .font(.headline)

                        Stepper(
                            "\(points) points",
                            value: $points,
                            in: 1...10
                        )
                    }

                    Button {
                        evaluateActivity()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            }

                            Image(systemName: "apple.intelligence")
                            
                            Text(
                                isLoading
                                ? "Evaluating..."
                                : "Evaluate Activity"
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)

                    if !result.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(
                                "AI Evaluation",
                                systemImage: "sparkles"
                            )
                            .font(.headline)

                            Text(result)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 20)
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("AI Test")
        }
    }

    private func evaluateActivity() {

        isLoading = true
        result = ""

        Task {
            do {

                let evaluation =
                    try await ActivityAIService.shared.evaluateActivity(
                        name: activityName,
                        description: activityDescription,
                        duration: duration,
                        proposedPoints: points
                    )

                await MainActor.run {
                    result = evaluation
                    isLoading = false
                }

            } catch {

                await MainActor.run {
                    result = "❌ \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    if #available(iOS 27.0, *) {
        AITestView();
    }
}
