/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {setGlobalOptions} from "firebase-functions";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
// import {onRequest} from "firebase-functions/https";
// import * as logger from "firebase-functions/logger";

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({maxInstances: 10});

admin.initializeApp();

// Create this with: firebase functions:secrets:set OPENROUTER_API_KEY
const openRouterApiKey = defineSecret("OPENROUTER_API_KEY");

type ModerationDecision = {
  recommendedStatus: "approved" | "rejected" | "needs_review";
  reason: string;
  suggestedPoints: number;
};

/**
 * Reviews every newly submitted activity. It intentionally leaves the public
 * status as "pending" so an admin can make the final decision; this prevents a
 * modified iOS app from using an AI response to self-approve easy-point quests.
 */
export const moderateActivity = onDocumentCreated(
  {
    document: "activities/{activityId}",
    secrets: [openRouterApiKey],
    maxInstances: 3,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const activity = snapshot.data();
    if (activity.status !== "pending") return;

    const prompt = [
      "You moderate neighbourhood activity submissions for teenagers.",
      "Reject activities that are trivial, unsafe, illegal, discriminatory,",
      "or offer points disproportionate to the effort. Do not reward merely",
      "opening an app, clicking something, or other easily faked actions.",
      "Return one JSON object only. Its fields must be recommendedStatus",
      "(approved, rejected, or needs_review), reason (short), and",
      "suggestedPoints (an integer from 1 through 10).",
      JSON.stringify({
        name: activity.name,
        age: activity.age,
        effort: activity.effort,
        cost: activity.cost,
        sheltered: activity.sheltered,
        duration: activity.duration,
        requirement: activity.requirement,
        points: activity.points,
      }),
    ].join("\n");

    try {
      const response = await fetch(
        "https://openrouter.ai/api/v1/chat/completions",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer " + openRouterApiKey.value(),
          },
          body: JSON.stringify({
            model: "openrouter/free",
            temperature: 0.1,
            max_tokens: 180,
            messages: [
              {role: "system", content: "Return valid JSON and nothing else."},
              {role: "user", content: prompt},
            ],
          }),
        }
      );

      if (!response.ok) {
        throw new Error("OpenRouter returned " + response.status);
      }
      type OpenRouterResponse = {
        choices?: Array<{message?: {content?: string}}>;
      };
      const payload = await response.json() as OpenRouterResponse;
      const content = payload.choices?.[0]?.message?.content;
      if (!content) throw new Error("OpenRouter did not return a decision");
      const json = content.replace(/^```json\s*|\s*```$/g, "");
      const decision = JSON.parse(json) as ModerationDecision;

      await snapshot.ref.update({
        moderation: {
          recommendedStatus: decision.recommendedStatus,
          reason: decision.reason,
          suggestedPoints: Math.min(
            10,
            Math.max(1, Number(decision.suggestedPoints) || 1)
          ),
          reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
    } catch (error) {
      logger.error("Activity moderation failed", error);
      await snapshot.ref.update({
        moderation: {
          recommendedStatus: "needs_review",
          reason: "Automated review is unavailable. " +
            "Review this activity manually.",
          reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
    }
  }
);

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
