//
//  HomeView.swift
//  Pandora / sidequester
//

import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Dropdown Filter Option

enum QuestFilterOption: String, CaseIterable, Identifiable {
    case all = "All Quests"
    case friends = "Friends Completed"
    case highestPoints = "Highest XP"
    case quick = "Quick (<30m)"
    case free = "Free Only"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "sparkles"
        case .friends: return "person.2.fill"
        case .highestPoints: return "flame.fill"
        case .quick: return "bolt.fill"
        case .free: return "dollarsign.circle"
        }
    }
}

// MARK: - Liquid Glass View Modifier

struct LiquidGlassModifier: ViewModifier {
    @EnvironmentObject private var customization: AppCustomization
    var cornerRadius: CGFloat? = nil

    private var effectiveRadius: CGFloat {
        cornerRadius ?? CGFloat(customization.glassCornerRadius)
    }

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: effectiveRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(customization.glassOpacity)

                    RoundedRectangle(cornerRadius: effectiveRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.04),
                                    customization.accentColor.color.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay {
                RoundedRectangle(cornerRadius: effectiveRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(customization.glassBorderOpacity + 0.35),
                                Color.white.opacity(customization.glassBorderOpacity * 0.4),
                                customization.accentColor.color.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            }
            .shadow(
                color: customization.accentColor.color.opacity(customization.glassShadowOpacity * 0.8),
                radius: customization.glassBlur,
                y: customization.glassBlur / 2
            )
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat? = nil) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Main Home View

struct HomeView: View {
    let activities: [Activity]
    let displayName: String
    
    @EnvironmentObject private var customization: AppCustomization
    
    // Search Bar & Dropdown Filter State
    @State private var searchText = ""
    @State private var isSearching = false
    @FocusState private var isSearchFocused: Bool
    @State private var selectedFilter: QuestFilterOption = .all
    
    // Sheets & Navigation
    @State private var selectedCategoryTitle: String? = nil
    @State private var selectedCategoryActivities: [Activity] = []
    @State private var showCategorySheet = false
    @State private var showStatsSheet = false
    @State private var showCustomizationSheet = false
    @State private var showCreateActivitySheet = false
    @State private var activityToComplete: Activity? = nil
    
    // User & Friend Data from Firestore
    @State private var userCompletedActivityIDs: Set<String> = []
    @State private var bookmarkedIDs: Set<String> = []
    @State private var friendCompletedActivityIDs: Set<String> = []
    
    private let db = Firestore.firestore()
    
    // 1. Filter out completed quests
    private var uncompletedActivities: [Activity] {
        activities.filter { !userCompletedActivityIDs.contains($0.id) }
    }
    
    // 2. Top Quest
    private var topQuest: Activity? {
        uncompletedActivities.max(by: { $0.points < $1.points })
    }
    
    // 3. Apply Filter Option
    private var filteredActivities: [Activity] {
        var list = uncompletedActivities
        
        switch selectedFilter {
        case .all:
            break
        case .friends:
            list = list.filter { friendCompletedActivityIDs.contains($0.id) }
        case .highestPoints:
            list.sort { $0.points > $1.points }
        case .quick:
            list = list.filter { $0.time.contains("15") || $0.time.contains("30") }
        case .free:
            list = list.filter { $0.cost.localizedCaseInsensitiveContains("Free") }
        }
        
        if selectedFilter == .all {
            list.sort { act1, act2 in
                let act1Friend = friendCompletedActivityIDs.contains(act1.id)
                let act2Friend = friendCompletedActivityIDs.contains(act2.id)
                if act1Friend != act2Friend {
                    return act1Friend
                }
                return act1.completedCount > act2.completedCount
            }
        }
        
        return list
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Spacer().frame(height: 72)
                    
                    // WELCOME BACK BAR
                    Button {
                        showStatsSheet = true
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [customization.accentColor.color, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 46, height: 46)
                                Text("⚡️")
                                    .font(.headline)
                            }
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 1))
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Welcome back, \(displayName.isEmpty ? "Adventurer" : displayName)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.primary)
                                
                                Text("\(userCompletedActivityIDs.count) Completed • \(uncompletedActivities.count) Available")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .liquidGlass(cornerRadius: 18)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    
                    // CENTERED VIBE BUBBLES
                    VStack(alignment: .center, spacing: 14) {
                        Text("EXPLORE VIBES")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        HStack(spacing: 24) {
                            bubbleButton(title: "Outdoors", icon: "sun.max.fill", color: .orange) {
                                openCategory(title: "Outdoors", filter: {
                                    $0.shelter.localizedCaseInsensitiveContains("Outdoor") || $0.shelter.localizedCaseInsensitiveContains("Both")
                                })
                            }
                            
                            bubbleButton(title: "Free", icon: "sparkles", color: .green) {
                                openCategory(title: "Free Quests", filter: {
                                    $0.cost.localizedCaseInsensitiveContains("Free")
                                })
                            }
                            
                            bubbleButton(title: "Quick", icon: "bolt.fill", color: .blue) {
                                openCategory(title: "Quick (<30m)", filter: {
                                    $0.time.contains("15") || $0.time.contains("30")
                                })
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 20)
                    
                    // FEATURED QUEST
                    if let top = topQuest {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("FEATURED QUEST")
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("🔥 Top XP")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.red)
                            }
                            .padding(.horizontal, 22)
                            
                            Button {
                                activityToComplete = top
                            } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text(top.shelter.uppercased())
                                            .font(.caption2.weight(.heavy))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(customization.accentColor.color.opacity(0.18))
                                            .foregroundStyle(customization.accentColor.color)
                                            .clipShape(Capsule())
                                        
                                        Spacer()
                                        
                                        Text("+\(top.points) PTS")
                                            .font(.caption.weight(.heavy))
                                            .foregroundStyle(.purple)
                                    }
                                    
                                    Text(top.name)
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                    
                                    HStack(spacing: 14) {
                                        Label(top.time, systemImage: "clock")
                                        Label(top.physical, systemImage: "figure.walk")
                                        Label(top.cost, systemImage: "dollarsign.circle")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    
                                    HStack {
                                        Text("Tap to log & complete")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(customization.accentColor.color)
                                        Spacer()
                                        Image(systemName: "arrow.right.circle.fill")
                                            .foregroundStyle(customization.accentColor.color)
                                    }
                                }
                                .padding(18)
                                .liquidGlass(cornerRadius: 22)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // SIDEQUEST FEED
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("SIDEQUESTS FOR YOU")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(filteredActivities.count) Available")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 22)
                        
                        if uncompletedActivities.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.green)
                                Text("All caught up! 🎉")
                                    .font(.headline)
                                Text("You have completed all available sidequests. Great work!")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .liquidGlass(cornerRadius: 20)
                            .padding(.horizontal, 20)
                        } else if filteredActivities.isEmpty {
                            Text("No quests match '\(selectedFilter.rawValue)' right now.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 24)
                        } else {
                            ForEach(filteredActivities) { act in
                                realActivityCard(act: act)
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                        }
                    }
                    
                    Spacer().frame(height: 50)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: userCompletedActivityIDs)
            .onAppear {
                fetchUserDataAndBookmarks()
                listenToFriendsActivity()
            }
            
            // PINNED TOP CONTROLS (SEARCH, DROPDOWN, CUSTOMIZER, ADD BUTTON)
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    // Search Bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        
                        TextField("Search all activities...", text: $searchText)
                            .focused($isSearchFocused)
                            .submitLabel(.search)
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .liquidGlass(cornerRadius: 16)
                    
                    // Filter Dropdown Menu
                    Menu {
                        ForEach(QuestFilterOption.allCases) { option in
                            Button {
                                withAnimation {
                                    selectedFilter = option
                                }
                            } label: {
                                Label(option.rawValue, systemImage: option.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: selectedFilter.icon)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(selectedFilter == .all ? .primary : customization.accentColor.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 11)
                        .liquidGlass(cornerRadius: 16)
                    }
                    
                    // Theme Customizer Button
                    Button {
                        showCustomizationSheet = true
                    } label: {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(customization.accentColor.color)
                            .padding(11)
                            .liquidGlass(cornerRadius: 16)
                    }
                    
                    // ADD NEW ACTIVITY BUTTON
                    Button {
                        showCreateActivitySheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(11)
                            .background(
                                LinearGradient(
                                    colors: [customization.accentColor.color, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .shadow(color: customization.accentColor.color.opacity(0.3), radius: 6, y: 2)
                    }
                    
                    if isSearching {
                        Button("Done") {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isSearching = false
                                isSearchFocused = false
                                searchText = ""
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(customization.accentColor.color)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(.ultraThinMaterial.opacity(0.85))
                
                if isSearching {
                    HomeSearchOverlay(
                        activities: uncompletedActivities,
                        searchText: searchText,
                        onSelect: { selected in
                            withAnimation {
                                isSearching = false
                                isSearchFocused = false
                            }
                            activityToComplete = selected
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .onChange(of: isSearchFocused) { focused in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if focused {
                        isSearching = true
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateActivitySheet) {
            CreateActivitySheet()
                .environmentObject(customization)
        }
        .sheet(isPresented: $showCategorySheet) {
            HomeCategorySheet(
                title: selectedCategoryTitle ?? "Activities",
                activities: selectedCategoryActivities,
                onSelect: { chosen in
                    showCategorySheet = false
                    activityToComplete = chosen
                }
            )
            .environmentObject(customization)
        }
        .sheet(isPresented: $showStatsSheet) {
            HomeStatsSheet(
                displayName: displayName,
                completedCount: userCompletedActivityIDs.count,
                availableCount: uncompletedActivities.count
            )
            .environmentObject(customization)
        }
        .sheet(isPresented: $showCustomizationSheet) {
            HomeThemeCustomizationSheet()
                .environmentObject(customization)
        }
        .sheet(item: $activityToComplete) { activity in
            ActivityCompletionSheet(activity: activity)
                .environmentObject(customization)
        }
    }
    
    // MARK: - Activity Card
    
    private func realActivityCard(act: Activity) -> some View {
        let isFriendFavorite = friendCompletedActivityIDs.contains(act.id)
        let isBookmarked = bookmarkedIDs.contains(act.id)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                if isFriendFavorite {
                    HStack(spacing: 5) {
                        Image(systemName: "person.2.fill")
                        Text("Friend Completed")
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Capsule())
                } else if act.completedCount > 0 {
                    Text("\(act.completedCount) Completed")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("+\(act.points) pts")
                    .font(.caption.bold())
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.18))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
            }
            
            Text(act.name)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
            
            if !act.description.isEmpty {
                Text(act.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            HStack(spacing: 12) {
                Label(act.time, systemImage: "clock")
                Label(act.physical, systemImage: "figure.walk")
                Label(act.shelter, systemImage: "house")
                Label(act.cost, systemImage: "dollarsign.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                Button {
                    activityToComplete = act
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Log Quest")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [customization.accentColor.color, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                
                Button {
                    toggleBookmark(for: act.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(isBookmarked ? customization.accentColor.color : .secondary)
                        Text(isBookmarked ? "Saved" : "Save")
                            .font(.caption.bold())
                            .foregroundStyle(isBookmarked ? customization.accentColor.color : .secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground), in: Capsule())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                ShareLink(item: "Check out this quest on Pandora: \(act.name) for \(act.points) points!") {
                    Image(systemName: "paperplane")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
        .padding(18)
        .liquidGlass(cornerRadius: 20)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Firestore Sync
    
    private func fetchUserDataAndBookmarks() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(uid).addSnapshotListener { snapshot, _ in
            guard let data = snapshot?.data() else { return }
            
            if let completed = data["completedActivities"] as? [String] {
                self.userCompletedActivityIDs = Set(completed)
            }
            if let saved = data["bookmarkedActivities"] as? [String] {
                self.bookmarkedIDs = Set(saved)
            }
        }
    }
    
    private func listenToFriendsActivity() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(uid).getDocument { snapshot, _ in
            guard let data = snapshot?.data(),
                  let friendUsernames = data["friends"] as? [String],
                  !friendUsernames.isEmpty else { return }
            
            db.collection("users")
                .whereField("username", in: friendUsernames)
                .addSnapshotListener { querySnapshot, _ in
                    guard let docs = querySnapshot?.documents else { return }
                    var friendActs = Set<String>()
                    for doc in docs {
                        if let completed = doc.data()["completedActivities"] as? [String] {
                            friendActs.formUnion(completed)
                        }
                    }
                    self.friendCompletedActivityIDs = friendActs
                }
        }
    }
    
    private func toggleBookmark(for activityID: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let userRef = db.collection("users").document(uid)
        
        if bookmarkedIDs.contains(activityID) {
            bookmarkedIDs.remove(activityID)
            userRef.updateData([
                "bookmarkedActivities": FieldValue.arrayRemove([activityID])
            ])
        } else {
            bookmarkedIDs.insert(activityID)
            userRef.updateData([
                "bookmarkedActivities": FieldValue.arrayUnion([activityID])
            ])
        }
    }
    
    private func bubbleButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [color.opacity(0.8), color.opacity(0.15), Color.white.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 68, height: 68)
                    
                    Circle()
                        .fill(color.opacity(0.16))
                        .frame(width: 58, height: 58)
                        .background(.ultraThinMaterial, in: Circle())
                    
                    Image(systemName: icon)
                        .font(.title3.bold())
                        .foregroundStyle(color)
                }
                .shadow(color: color.opacity(0.25), radius: 8, y: 3)
                
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func openCategory(title: String, filter: (Activity) -> Bool) {
        selectedCategoryTitle = title
        selectedCategoryActivities = uncompletedActivities.filter(filter)
        showCategorySheet = true
    }
}

// MARK: - Create Activity Sheet (User Adds Activities to Firestore)

struct CreateActivitySheet: View {
    @EnvironmentObject private var customization: AppCustomization
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var descriptionText: String = ""
    @State private var time: String = "15-30 mins"
    @State private var shelter: String = "Outdoor"
    @State private var physical: String = "Low"
    @State private var cost: String = "Free"
    @State private var points: Int = 15
    @State private var age: String = "Any"
    @State private var requirement: String = "None"
    
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var errorMessage = ""
    
    private let db = Firestore.firestore()
    
    private let timeOptions = ["15-30 mins", "30-60 mins", "1hr+"]
    private let shelterOptions = ["Outdoor", "Indoor", "Both"]
    private let physicalOptions = ["Low", "Moderate", "High"]
    private let costOptions = ["Free", "$", "$$"]
    private let pointsOptions = [10, 15, 20, 25, 30]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Banner
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NEW SIDEQUEST")
                            .font(.caption.bold())
                            .foregroundStyle(customization.accentColor.color)
                        Text("Create an Activity")
                            .font(.title2.bold())
                        Text("Add a fun quest to the community board for other explorers to discover.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .liquidGlass(cornerRadius: 18)
                    
                    // Name & Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ACTIVITY DETAILS")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        
                        TextField("Quest title (e.g. Find 3 local street murals)", text: $name)
                            .padding()
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        
                        TextField("Brief description or instructions (optional)", text: $descriptionText, axis: .vertical)
                            .lineLimit(2...4)
                            .padding()
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Activity Properties
                    VStack(alignment: .leading, spacing: 14) {
                        Text("SETTINGS & TAGS")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        
                        // Estimated Time
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Estimated Time")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            Picker("Time", selection: $time) {
                                ForEach(timeOptions, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // Shelter
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Environment")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            Picker("Shelter", selection: $shelter) {
                                ForEach(shelterOptions, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // Physical Intensity
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Physical Intensity")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            Picker("Physical", selection: $physical) {
                                ForEach(physicalOptions, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // Cost
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Cost")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            Picker("Cost", selection: $cost) {
                                ForEach(costOptions, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // Points Reward
                        VStack(alignment: .leading, spacing: 6) {
                            Text("XP / Points Reward")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            Picker("Points", selection: $points) {
                                ForEach(pointsOptions, id: \.self) { Text("+\($0) pts").tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding(16)
                    .liquidGlass(cornerRadius: 18)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    
                    // Submit Button
                    Button {
                        submitActivity()
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                Text("Publish Sidequest")
                                    .fontWeight(.bold)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [customization.accentColor.color, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                    .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
                }
                .padding(20)
            }
            .navigationTitle("Add Sidequest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Sidequest Created! 🎉", isPresented: $showSuccessAlert) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your activity is now live and can be explored and logged by other players!")
            }
        }
    }
    
    private func submitActivity() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be logged in to create a quest."
            return
        }
        
        isSubmitting = true
        errorMessage = ""
        
        let newActivityData: [String: Any] = [
            "name": cleanName,
            "description": descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            "age": age,
            "physical": physical,
            "cost": cost,
            "shelter": shelter,
            "time": time,
            "requirement": requirement,
            "points": points,
            "completedCount": 0,
            "createdBy": uid,
            "createdAt": Timestamp(date: Date())
        ]
        
        let newDocRef = db.collection("activities").document()
        newDocRef.setData(newActivityData) { error in
            if let error = error {
                isSubmitting = false
                errorMessage = error.localizedDescription
                return
            }
            
            // Record creator activity in user document
            db.collection("users").document(uid).updateData([
                "activitiesCreated": FieldValue.increment(Int64(1)),
                "createdActivities": FieldValue.arrayUnion([newDocRef.documentID])
            ]) { _ in
                isSubmitting = false
                showSuccessAlert = true
            }
        }
    }
}

// MARK: - Search List Overlay

private struct HomeSearchOverlay: View {
    let activities: [Activity]
    let searchText: String
    let onSelect: (Activity) -> Void
    
    var filtered: [Activity] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return activities
        }
        return activities.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.shelter.localizedCaseInsensitiveContains(searchText) ||
            $0.physical.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AVAILABLE ACTIVITIES (\(filtered.count))")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 22)
                .padding(.top, 10)
            
            List(filtered) { act in
                Button {
                    onSelect(act)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(act.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            
                            HStack(spacing: 8) {
                                Text(act.shelter)
                                Text("•")
                                Text(act.time)
                                Text("•")
                                Text(act.cost)
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("+\(act.points) pts")
                            .font(.caption.bold())
                            .foregroundStyle(.purple)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Category Filter Sheet

private struct HomeCategorySheet: View {
    let title: String
    let activities: [Activity]
    let onSelect: (Activity) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(activities) { act in
                Button {
                    onSelect(act)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(act.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("+\(act.points) pts")
                                .font(.subheadline.bold())
                                .foregroundStyle(.purple)
                        }
                        
                        HStack(spacing: 12) {
                            Label(act.time, systemImage: "clock")
                            Label(act.physical, systemImage: "figure.walk")
                            Label(act.cost, systemImage: "dollarsign.circle")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Player Stats Sheet

private struct HomeStatsSheet: View {
    let displayName: String
    let completedCount: Int
    let availableCount: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 72, height: 72)
                        .overlay(Text("⚡️").font(.title))
                    
                    Text(displayName.isEmpty ? "Adventurer" : displayName)
                        .font(.title2.bold())
                    
                    Text("Sidequester Explorer")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)
                
                HStack(spacing: 16) {
                    statBox(title: "Completed", value: "\(completedCount)")
                    statBox(title: "Available", value: "\(availableCount)")
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationTitle("Your Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func statBox(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .liquidGlass(cornerRadius: 16)
    }
}

// MARK: - Customization Sheet

private struct HomeThemeCustomizationSheet: View {
    @EnvironmentObject private var customization: AppCustomization
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Accent Theme Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(AppThemeColor.allCases) { theme in
                            Button {
                                customization.accentColor = theme
                                customization.scheduleSync()
                            } label: {
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(theme.color)
                                        .frame(width: 44, height: 44)
                                        .overlay {
                                            if customization.accentColor == theme {
                                                Image(systemName: "checkmark")
                                                    .font(.headline.bold())
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                    
                                    Text(theme.displayName)
                                        .font(.caption2)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Liquid Glass Styling") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Glass Opacity")
                            Spacer()
                            Text("\(Int(customization.glassOpacity * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $customization.glassOpacity, in: 0.2...1.0)
                            .tint(customization.accentColor.color)
                            .onChange(of: customization.glassOpacity) { _ in customization.scheduleSync() }
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Liquid Blur")
                            Spacer()
                            Text("\(Int(customization.glassBlur)) pt")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $customization.glassBlur, in: 5...35)
                            .tint(customization.accentColor.color)
                            .onChange(of: customization.glassBlur) { _ in customization.scheduleSync() }
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Corner Smoothness")
                            Spacer()
                            Text("\(Int(customization.glassCornerRadius)) pt")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $customization.glassCornerRadius, in: 12...34)
                            .tint(customization.accentColor.color)
                            .onChange(of: customization.glassCornerRadius) { _ in customization.scheduleSync() }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        customization.reset()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Reset Theme to Default")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Customization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Activity Completion Sheet

struct ActivityCompletionSheet: View {
    let activity: Activity
    
    @EnvironmentObject private var customization: AppCustomization
    @Environment(\.dismiss) private var dismiss
    
    @State private var proofMode: Int = 0
    @State private var textNote: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedPhotoData: Data? = nil
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(activity.shelter.uppercased())
                                .font(.caption.bold())
                                .foregroundStyle(customization.accentColor.color)
                            Spacer()
                            Text("+\(activity.points) PTS")
                                .font(.headline.bold())
                                .foregroundStyle(.purple)
                        }
                        
                        Text(activity.name)
                            .font(.title3.bold())
                        
                        HStack(spacing: 14) {
                            Label(activity.time, systemImage: "clock")
                            Label(activity.physical, systemImage: "figure.walk")
                            Label(activity.cost, systemImage: "dollarsign.circle")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .liquidGlass(cornerRadius: 18)
                    
                    Text("LOG COMPLETION PROOF")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    
                    Picker("Proof Mode", selection: $proofMode) {
                        Text("✍️ Text Note (Instant)").tag(0)
                        Text("📷 Photo Proof").tag(1)
                    }
                    .pickerStyle(.segmented)
                    
                    if proofMode == 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Enter quick details (ideal for simulator testing):")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            TextField("e.g. Completed during my afternoon walk!", text: $textNote, axis: .vertical)
                                .lineLimit(3...5)
                                .padding()
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                        }
                    } else {
                        VStack(spacing: 12) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                HStack {
                                    Image(systemName: "photo")
                                    Text(selectedPhotoData == nil ? "Choose Photo from Library" : "Change Photo")
                                }
                                .font(.subheadline.bold())
                                .foregroundStyle(customization.accentColor.color)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(customization.accentColor.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                            }
                            .onChange(of: selectedPhotoItem) { newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                        selectedPhotoData = data
                                    }
                                }
                            }
                            
                            if let data = selectedPhotoData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                    
                    Button {
                        completeActivity()
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Text("Complete & Claim \(activity.points) Points")
                                    .fontWeight(.bold)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [customization.accentColor.color, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                    .disabled(isSubmitting)
                }
                .padding(20)
            }
            .navigationTitle("Sidequest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Quest Complete! 🎉", isPresented: $showSuccessAlert) {
                Button("Awesome!") { dismiss() }
            } message: {
                Text("You earned +\(activity.points) points and logged this activity to your account!")
            }
        }
    }
    
    private func completeActivity() {
        guard let uid = Auth.auth().currentUser?.uid else {
            showSuccessAlert = true
            return
        }
        
        isSubmitting = true
        let userRef = db.collection("users").document(uid)
        
        userRef.updateData([
            "points": FieldValue.increment(Int64(activity.points)),
            "completedActivities": FieldValue.arrayUnion([activity.id]),
            "lifetimeCompletedActivities": FieldValue.increment(Int64(1)),
            "lastCompletedAt": Timestamp(date: Date())
        ]) { error in
            isSubmitting = false
            showSuccessAlert = true
            
            db.collection("activities").document(activity.id).updateData([
                "completedCount": FieldValue.increment(Int64(1))
            ])
        }
    }
}
