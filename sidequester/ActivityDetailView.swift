//
//  ActivityDetailView.swift
//  sidequester
//
//  Created by Rayson Ng on 9/7/26.
//

import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseAuth
import FirebaseFirestore

struct ActivityDetailView: View {
    let activity: Activity
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: Image?
    @State private var imageData: Data?
    @State private var showSubmitButton = false
    @State private var showSuccess = false
    @Environment(\.dismiss) private var dismiss
    @State private var animateSuccess = false
    @State private var errorMessage = ""

    // Anti-farming cooldown: once per activity per 24h.
    @State private var isCheckingCooldown = true
    @State private var cooldownMessage: String?

    private let db = Firestore.firestore()

    var body: some View {
        ZStack {
            ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(activity.name)
                    .font(.largeTitle)
                    .bold()

                Text(activity.description)
                    .foregroundStyle(.secondary)

                Divider()

                Label("Points: \(activity.points)", systemImage: "star.fill")

                Label("Completed by \(activity.completedCount) people", systemImage: "person.2.fill")

                Divider()

                Text("Requirements")
                    .font(.title2)
                    .bold()

                Text(activity.requirement)

                Spacer(minLength: 30)

                if let cooldownMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                        Text(cooldownMessage)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                } else {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Complete Activity", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCheckingCooldown)
                    .accessibilityLabel("Complete activity by taking or choosing a proof photo")
                    .onChange(of: selectedPhoto) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                selectedImage = Image(uiImage: uiImage)
                                // Compress before we ever touch Storage — cuts
                                // upload size/time and Storage cost.
                                imageData = ImageCompression.compress(uiImage) ?? data
                                showSubmitButton = true
                            }
                        }
                    }
                }

                if let selectedImage {
                    Divider()

                    Text("Proof Photo")
                        .font(.headline)

                    selectedImage
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if showSubmitButton {
                    Button("Submit") {
                        uploadPhoto()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Submit proof photo")
                }
            }
            .padding()
        }
            if showSuccess {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 90))
                        .foregroundStyle(.green)
                        .scaleEffect(animateSuccess ? 1 : 0.5)

                    Text("Activity Submitted!")
                        .font(.title2)
                        .bold()

                    Text("+\(activity.points) points")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(30)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { checkCooldown() }
    }

    /// Blocks re-submitting the same activity within 24 hours of the last
    /// completion, so points can't be farmed by spamming one easy activity.
    private func checkCooldown() {
        guard let uid = Auth.auth().currentUser?.uid else {
            isCheckingCooldown = false
            return
        }

        db.collection("users").document(uid)
            .collection("completions").document(activity.id)
            .getDocument { snapshot, _ in
                isCheckingCooldown = false

                guard let lastCompletedAt = (snapshot?.data()?["lastCompletedAt"] as? Timestamp)?.dateValue() else {
                    return
                }

                let hoursSince = Date().timeIntervalSince(lastCompletedAt) / 3600
                if hoursSince < 24 {
                    let hoursLeft = max(1, Int(ceil(24 - hoursSince)))
                    cooldownMessage = "You've already completed this one today — come back in \(hoursLeft)h."
                }
            }
    }

    private func uploadPhoto() {
        guard let imageData else { return }

        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "You need to be signed in to submit."
            return
        }

        errorMessage = ""

        let ref = Storage.storage()
            .reference()
            .child("activityProofs")
            .child(uid)
            .child("\(activity.id)-\(UUID().uuidString).jpg")

        ref.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                errorMessage = "Upload failed: \(error.localizedDescription)"
                return
            }

            ref.downloadURL { url, error in
                if let error = error {
                    errorMessage = "Couldn't get download URL: \(error.localizedDescription)"
                    return
                }

                guard let photoURL = url?.absoluteString else { return }

                recordCompletion(uid: uid, photoURL: photoURL)
            }
        }
    }

    /// Awards the activity's points to the user, bumps the activity's
    /// completed count, and posts to the Feed so friends can see, kudos, and
    /// comment on the completion.
    private func recordCompletion(uid: String, photoURL: String) {
        let userRef = db.collection("users").document(uid)

        userRef.getDocument { snapshot, error in
            let data = snapshot?.data() ?? [:]
            let username = data["username"] as? String ?? "Explorer"
            let profileImageURL = data["profileImageURL"] as? String

            db.collection("posts").addDocument(data: [
                "userId": uid,
                "username": username,
                "profileImageURL": profileImageURL as Any,
                "activityId": activity.id,
                "activityName": activity.name,
                "photoURL": photoURL,
                "points": activity.points,
                "createdAt": Timestamp(date: Date()),
                "kudosCount": 0,
                "commentCount": 0
            ])

            // Streak: count consecutive calendar days with at least one
            // completion. Same day keeps it, exactly one day later extends
            // it, anything else (a gap, or no prior completion) resets to 1.
            let calendar = Calendar.current
            let now = Date()
            let currentStreak = data["streak"] as? Int ?? 0
            let longestStreak = data["longestStreak"] as? Int ?? 0
            let lastCompletedAt = (data["lastCompletedAt"] as? Timestamp)?.dateValue()

            let newStreak: Int
            if let lastCompletedAt {
                let daysBetween = calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: lastCompletedAt),
                    to: calendar.startOfDay(for: now)
                ).day ?? 0

                if daysBetween == 0 {
                    newStreak = max(currentStreak, 1)
                } else if daysBetween == 1 {
                    newStreak = currentStreak + 1
                } else {
                    newStreak = 1
                }
            } else {
                newStreak = 1
            }

            userRef.updateData([
                "points": FieldValue.increment(Int64(activity.points)),
                "lifetimeCompletedActivities": FieldValue.increment(Int64(1)),
                "completedActivities": FieldValue.arrayUnion([activity.id]),
                "streak": newStreak,
                "longestStreak": max(longestStreak, newStreak),
                "lastCompletedAt": Timestamp(date: now)
            ])

            db.collection("activities").document(activity.id).updateData([
                "completedCount": FieldValue.increment(Int64(1))
            ])

            // Stamp this activity's cooldown so it can't be re-submitted for
            // points again within 24 hours.
            db.collection("users").document(uid)
                .collection("completions").document(activity.id)
                .setData(["lastCompletedAt": Timestamp(date: now)], merge: true)

            DispatchQueue.main.async {
                showSubmitButton = false
                NotificationManager.cancelStreakReminder()
                withAnimation(.spring()) {
                    animateSuccess = true
                    showSuccess = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    dismiss()
                }
            }
        }
    }
}
