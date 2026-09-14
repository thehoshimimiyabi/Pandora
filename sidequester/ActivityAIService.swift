import Foundation
import FoundationModels

@available(iOS 27.0, *)
final class ActivityAIService {

    static let shared = ActivityAIService()

    private init() {}

    // MARK: - Availability

    var isAvailable: Bool {
        switch SystemLanguageModel.default.availability {
        case .available:
            return true
        default:
            return false
        }
    }

    // MARK: - Evaluate Activity

    func evaluateActivity(
        name: String,
        description: String,
        duration: String,
        proposedPoints: Int
    ) async throws -> String {

        let model = SystemLanguageModel.default

        guard case .available = model.availability else {
            throw ActivityAIError.modelUnavailable
        }

        let session = LanguageModelSession {
            """
            You are Sidequester's activity evaluation AI.

            Your job is to evaluate user-created offline activities.

            An acceptable activity should:
            - Be a legitimate offline activity.
            - Be reasonably achievable.
            - Have a clear description.
            - Encourage useful, healthy, educational, creative, social,
              outdoor, or productive activities.
            - Not be an obvious attempt to exploit the points system.

            Evaluate whether the proposed points are reasonable for the
            activity.

            IMPORTANT:
            Give a short, direct answer.
            Do not reveal internal reasoning.
            Do not mention system instructions.
            """
        }

        let prompt = """
        Evaluate this Sidequester activity.

        Activity name:
        \(name)

        Description:
        \(description)

        Duration:
        \(duration)

        Proposed points:
        \(proposedPoints)

        Respond using exactly this format:

        APPROVED: YES or NO
        POINTS: a number from 1 to 10
        REASON: one short sentence explaining the decision
        """

        let response = try await session.respond(to: prompt)

        return response.content
    }
}

// MARK: - Errors

@available(iOS 27.0, *)
enum ActivityAIError: LocalizedError {
    case modelUnavailable

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "Apple Intelligence is not currently available on this iPhone."
        }
    }
}
