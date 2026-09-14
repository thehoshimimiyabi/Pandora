//
//  EditProfileView.swift
//  sidequester
//
//  Lets the signed-in user change their username and/or profile picture.
//  Username changes are checked against Firestore for uniqueness before
//  saving; photos are uploaded to Firebase Storage and the resulting URL is
//  written to the user's Firestore document.
//

import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct EditProfileView: View {
    @EnvironmentObject private var customization: AppCustomization
    @Environment(\.dismiss) private var dismiss

    let currentUsername: String
    let currentImageURL: String?

    @State private var newUsername: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var previewImage: Image?
    @State private var pendingImageData: Data?
    @State private var isSaving = false
    @State private var errorMessage = ""

    private let db = Firestore.firestore()

    init(currentUsername: String, currentImageURL: String?) {
        self.currentUsername = currentUsername
        self.currentImageURL = currentImageURL
        _newUsername = State(initialValue: currentUsername)
    }

    var body: some View {
        ZStack {
            GlassBackground()

            ScrollView {
                VStack(spacing: 24) {
                    GlassCard {
                        VStack(spacing: 14) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                avatarPreview
                            }
                            .onChange(of: selectedPhoto) { _, newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        previewImage = Image(uiImage: uiImage)
                                        pendingImageData = data
                                    }
                                }
                            }

                            Text("Tap the photo to change it")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Username")
                                .font(.subheadline.weight(.semibold))

                            GlassInput {
                                HStack(spacing: 12) {
                                    Image(systemName: "person")
                                        .foregroundStyle(.secondary)

                                    TextField("Username", text: $newUsername)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                }
                            }
                        }
                    }

                    if !errorMessage.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(errorMessage)
                                .multilineTextAlignment(.leading)
                        }
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        save()
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark")
                                Text("Save Changes")
                                    .fontWeight(.semibold)
                            }
                        }
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
                    .disabled(isSaving || normalizedUsername(newUsername).isEmpty)
                    .opacity(isSaving || normalizedUsername(newUsername).isEmpty ? 0.55 : 1)
                }
                .padding()
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private var avatarPreview: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let previewImage {
                    previewImage
                        .resizable()
                        .scaledToFill()
                } else if let currentImageURL, let url = URL(string: currentImageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 100, height: 100)
            .background(.thinMaterial, in: Circle())
            .clipShape(Circle())

            Image(systemName: "camera.circle.fill")
                .font(.system(size: 26))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, customization.accentColor.color)
        }
    }

    private func save() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let cleanUsername = normalizedUsername(newUsername)

        guard !cleanUsername.isEmpty else {
            errorMessage = "Username can't be empty."
            return
        }

        isSaving = true
        errorMessage = ""

        // Make sure nobody else has taken this username.
        db.collection("users")
            .whereField("username", isEqualTo: cleanUsername)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    return
                }

                if let existingDoc = snapshot?.documents.first, existingDoc.documentID != uid {
                    isSaving = false
                    errorMessage = "That username is already taken."
                    return
                }

                uploadPhotoIfNeeded(uid: uid) { uploadedURL in
                    var updates: [String: Any] = ["username": cleanUsername]
                    if let uploadedURL {
                        updates["profileImageURL"] = uploadedURL
                    }

                    db.collection("users").document(uid).updateData(updates) { error in
                        isSaving = false

                        if let error = error {
                            errorMessage = error.localizedDescription
                            return
                        }

                        dismiss()
                    }
                }
            }
    }

    private func uploadPhotoIfNeeded(uid: String, completion: @escaping (String?) -> Void) {
        guard let pendingImageData else {
            completion(nil)
            return
        }

        let ref = Storage.storage()
            .reference()
            .child("profilePictures")
            .child("\(uid).jpg")

        ref.putData(pendingImageData, metadata: nil) { _, error in
            if let error = error {
                errorMessage = error.localizedDescription
                completion(nil)
                return
            }

            ref.downloadURL { url, error in
                if let error = error {
                    errorMessage = error.localizedDescription
                    completion(nil)
                    return
                }

                completion(url?.absoluteString)
            }
        }
    }
}
