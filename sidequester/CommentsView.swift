import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct Comment: Identifiable {
    let id: String
    let userId: String
    let username: String
    let text: String
    let createdAt: Date
}

struct CommentsView: View {
    @Environment(\.dismiss) private var dismiss

    let post: Post

    @State private var comments: [Comment] = []
    @State private var newComment = ""
    @State private var isSending = false

    private let db = Firestore.firestore()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if comments.isEmpty {
                        Text("No comments yet — say something nice!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        ForEach(comments) { comment in
                            commentRow(comment)
                        }
                    }
                }
                .padding()
            }

            Divider()

            HStack(spacing: 10) {
                TextField("Add a comment...", text: $newComment)
                    .textFieldStyle(.roundedBorder)

                Button {
                    sendComment()
                } label: {
                    if isSending {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                }
                .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding()
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .onAppear { listenToComments() }
    }

    private func commentRow(_ comment: Comment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(comment.username)
                    .font(.subheadline.weight(.semibold))
                Text(comment.text)
                    .font(.subheadline)
            }

            Spacer()
        }
    }

    private func listenToComments() {
        db.collection("posts").document(post.id).collection("comments")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }

                comments = documents.compactMap { doc in
                    let data = doc.data()
                    guard let userId = data["userId"] as? String,
                          let username = data["username"] as? String,
                          let text = data["text"] as? String else {
                        return nil
                    }
                    let timestamp = data["createdAt"] as? Timestamp
                    return Comment(
                        id: doc.documentID,
                        userId: userId,
                        username: username,
                        text: text,
                        createdAt: timestamp?.dateValue() ?? Date()
                    )
                }
            }
    }

    private func sendComment() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let trimmed = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSending = true

        db.collection("users").document(uid).getDocument { snapshot, _ in
            let username = snapshot?.data()?["username"] as? String ?? "Explorer"

            db.collection("posts").document(post.id).collection("comments").addDocument(data: [
                "userId": uid,
                "username": username,
                "text": trimmed,
                "createdAt": Timestamp(date: Date())
            ]) { error in
                isSending = false

                if error == nil {
                    newComment = ""
                    db.collection("posts").document(post.id).updateData([
                        "commentCount": FieldValue.increment(Int64(1))
                    ])
                }
            }
        }
    }
}
