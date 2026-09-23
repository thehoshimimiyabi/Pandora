//
//  MyQuestsView.swift
//  Pandora / sidequester
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct MyQuestsView: View {
    var allActivities: [Activity] = []
    
    @EnvironmentObject private var customization: AppCustomization
    @State private var selectedTab = 0 // 0: Bookmarked, 1: Completed
    @State private var completedIDs: [String] = []
    @State private var bookmarkedIDs: [String] = []
    @State private var activityToComplete: Activity? = nil
    
    private let db = Firestore.firestore()
    
    private var completedActivities: [Activity] {
        allActivities.filter { completedIDs.contains($0.id) }
    }
    
    private var bookmarkedActivities: [Activity] {
        allActivities.filter { bookmarkedIDs.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Segmented Picker
                Picker("Quests Mode", selection: $selectedTab) {
                    Text("Saved Quests (\(bookmarkedActivities.count))").tag(0)
                    Text("Completed (\(completedActivities.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                
                if selectedTab == 0 {
                    // BOOKMARKED QUESTS
                    if bookmarkedActivities.isEmpty {
                        emptyView(
                            icon: "bookmark.slash",
                            title: "No Saved Quests",
                            message: "Tap the bookmark icon on any sidequest on the Home screen to save it for later!"
                        )
                    } else {
                        List(bookmarkedActivities) { act in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(act.name)
                                        .font(.headline)
                                    Spacer()
                                    Text("+\(act.points) pts")
                                        .font(.caption.bold())
                                        .foregroundStyle(.purple)
                                }
                                
                                HStack(spacing: 10) {
                                    Label(act.time, systemImage: "clock")
                                    Label(act.shelter, systemImage: "house")
                                    Label(act.cost, systemImage: "dollarsign.circle")
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                
                                HStack {
                                    Button {
                                        activityToComplete = act
                                    } label: {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                            Text("Log Completion")
                                        }
                                        .font(.footnote.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Spacer()
                                    
                                    Button {
                                        removeBookmark(act.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.footnote)
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 4)
                        }
                        .listStyle(.insetGrouped)
                    }
                } else {
                    // COMPLETED QUESTS
                    if completedActivities.isEmpty {
                        emptyView(
                            icon: "trophy",
                            title: "No Completed Quests",
                            message: "You haven't completed any sidequests yet. Go out, explore, and log your first one!"
                        )
                    } else {
                        List(completedActivities) { act in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(act.name)
                                        .font(.headline)
                                    Text("Completed • +\(act.points) Points Earned")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                                Spacer()
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                            }
                            .padding(.vertical, 4)
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("My Quests")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                fetchUserData()
            }
            .sheet(item: $activityToComplete) { act in
                ActivityCompletionSheet(activity: act)
                    .environmentObject(customization)
            }
        }
    }
    
    private func fetchUserData() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(uid).addSnapshotListener { snapshot, _ in
            guard let data = snapshot?.data() else { return }
            self.completedIDs = data["completedActivities"] as? [String] ?? []
            self.bookmarkedIDs = data["bookmarkedActivities"] as? [String] ?? []
        }
    }
    
    private func removeBookmark(_ id: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).updateData([
            "bookmarkedActivities": FieldValue.arrayRemove([id])
        ])
    }
    
    private func emptyView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}
