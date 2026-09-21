import SwiftUI
import FirebaseFirestore

/// The old "Activities" tab's content, now embedded directly into Home
/// instead of living in its own tab — search, filters, add/import, and the
/// full activity list.
struct BrowseActivitiesSection: View {
    let activities: [Activity]

    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var activityToDelete: Activity?
    @State private var activityToEdit: Activity?
    private let db = Firestore.firestore()

    @State private var selectedAge = "Any"
    @State private var selectedEffort = "Any"
    @State private var selectedTime = "Any"
    @State private var selectedCost = "Any"
    @State private var selectedShelter = "Any"
    @State private var selectedCompleted = "Any"

    @State private var isImporting = false
    @State private var importMessage: String?
    @State private var importSucceeded = false

    let ageOptions = ["Any", "Kids", "Teens", "Adults", "Seniors"]
    let effortOptions = ["Any", "Low", "Moderate", "High"]
    let timeOptions = ["Any", "<15 mins", "15-30 mins", "30-60 mins", "1 hour+"]
    let costOptions = ["Any", "Free", "$", "$$", "$$$"]
    let shelterOptions = ["Any", "Indoor", "Outdoor", "Both"]
    let completedOptions = ["Any", "0-10", "11-50", "51-100", "100+"]

    var filteredActivities: [Activity] {
        activities.filter { activity in
            (searchText.isEmpty || activity.name.localizedCaseInsensitiveContains(searchText)) &&
            (selectedAge == "Any" || activity.age == selectedAge) &&
            (selectedEffort == "Any" || activity.physical == selectedEffort) &&
            (selectedTime == "Any" || activity.time == selectedTime) &&
            (selectedCost == "Any" || activity.cost == selectedCost) &&
            (selectedShelter == "Any" || activity.shelter == selectedShelter) &&
            selectedCompleted == "Any"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Browse All Quests", systemImage: "magnifyingglass")
                .font(.title3.bold())

            HStack(spacing: 10) {
                TextField("Search activities...", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 30))
                }
                .accessibilityLabel("Add a new activity")

                Button {
                    importFromSheet()
                } label: {
                    if isImporting {
                        ProgressView()
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title2)
                    }
                }
                .disabled(isImporting)
                .accessibilityLabel("Import activities from the Google Sheet")
            }

            if let importMessage {
                HStack(spacing: 8) {
                    Image(systemName: importSucceeded ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    Text(importMessage)
                }
                .font(.footnote)
                .foregroundStyle(importSucceeded ? .green : .red)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(title: "Age", selection: $selectedAge, options: ageOptions)
                    filterChip(title: "Effort", selection: $selectedEffort, options: effortOptions)
                    filterChip(title: "Time", selection: $selectedTime, options: timeOptions)
                    filterChip(title: "Cost", selection: $selectedCost, options: costOptions)
                    filterChip(title: "Shelter", selection: $selectedShelter, options: shelterOptions)
                    filterChip(title: "Completed", selection: $selectedCompleted, options: completedOptions)
                }
                .padding(.vertical, 2)
            }

            GlassCard {
                VStack(spacing: 12) {
                    if filteredActivities.isEmpty {
                        Text("No activities match those filters.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(Array(filteredActivities.enumerated()), id: \.element.id) { index, activity in
                            NavigationLink(destination: ActivityDetailView(activity: activity)) {
                                ActivityCard(activity: activity)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    activityToEdit = activity
                                } label: {
                                    Label("Edit Activity", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    activityToDelete = activity
                                } label: {
                                    Label("Delete Activity", systemImage: "trash")
                                }
                            }

                            if index != filteredActivities.count - 1 {
                                Divider().opacity(0.3)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddActivityView()
        }
        .sheet(isPresented: Binding(
            get: { activityToEdit != nil },
            set: { if !$0 { activityToEdit = nil } }
        )) {
            if let activity = activityToEdit {
                EditActivityView(activity: activity)
            }
        }
        .confirmationDialog(
            "Delete Activity?",
            isPresented: Binding(
                get: { activityToDelete != nil },
                set: { if !$0 { activityToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let activity = activityToDelete {
                    db.collection("activities").document(activity.id).delete { error in
                        if let error = error {
                            print("Failed to delete activity: \(error.localizedDescription)")
                        }
                    }
                }
                activityToDelete = nil
            }

            Button("Cancel", role: .cancel) {
                activityToDelete = nil
            }
        } message: {
            if let activity = activityToDelete {
                Text("Delete '\(activity.name)' from Firestore?")
            }
        }
    }

    /// Compact pill-shaped filter control — a Menu-backed Picker so the
    /// whole filter row fits on one horizontally-scrollable line instead of
    /// six stacked header+picker blocks.
    private func filterChip(title: String, selection: Binding<String>, options: [String]) -> some View {
        let isActive = selection.wrappedValue != "Any"

        return Menu {
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(isActive ? selection.wrappedValue : title)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                isActive ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground),
                in: Capsule()
            )
            .foregroundStyle(isActive ? Color.accentColor : Color.primary)
        }
    }

    /// Imports (or refreshes) activities from the published Google Sheet
    /// into Firestore's "activities" collection. Existing activities are
    /// matched by name and updated in place; new rows are added.
    private func importFromSheet() {
        isImporting = true
        importMessage = nil

        Task {
            do {
                let result = try await SheetImporter.importIntoFirestore(
                    fromPublishedSheetURL: SheetImporter.sidequesterSheetURL
                )

                await MainActor.run {
                    isImporting = false
                    if result.found == 0 {
                        importSucceeded = false
                        importMessage = "The sheet fetch worked, but 0 rows were found — check the URL is pointing at the right tab."
                    } else if result.imported == 0 {
                        importSucceeded = false
                        importMessage = "Found \(result.found) row(s) in the sheet, but none had a usable name — check the sheet's column headers."
                    } else {
                        importSucceeded = true
                        importMessage = "Imported \(result.imported) of \(result.found) activities from the sheet."
                    }
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    importSucceeded = false
                    importMessage = error.localizedDescription
                }
            }
        }
    }
}

struct AddActivityView: View {
    @Environment(\.dismiss) private var dismiss
    private let db = Firestore.firestore()

    @State private var name = ""
    @State private var requirement = ""
    @State private var description = ""
    @State private var completedCount = 0

    @State private var age = "Any"
    @State private var physical = "Low"
    @State private var cost = "Free"
    @State private var shelter = "Outdoor"
    @State private var time = "15-30 mins"

    let ages = ["Any", "Kids", "Teens", "Adults", "Seniors"]
    let physicalLevels = ["Low", "Moderate", "High"]
    let costs = ["Free", "$", "$$", "$$$"]
    let shelters = ["Indoor", "Outdoor", "Both"]
    let times = ["<15 mins", "15-30 mins", "30-60 mins", "1hr+"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("Activity Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                    TextField("Requirement", text: $requirement)
                    Stepper("Completed: \(completedCount)", value: $completedCount, in: 0...10000)
                }

                Section("Filters") {
                    Picker("Age", selection: $age) {
                        ForEach(ages, id: \.self) { Text($0) }
                    }
                    Picker("Physical Activity", selection: $physical) {
                        ForEach(physicalLevels, id: \.self) { Text($0) }
                    }
                    Picker("Cost", selection: $cost) {
                        ForEach(costs, id: \.self) { Text($0) }
                    }
                    Picker("Shelter", selection: $shelter) {
                        ForEach(shelters, id: \.self) { Text($0) }
                    }
                    Picker("Time", selection: $time) {
                        ForEach(times, id: \.self) { Text($0) }
                    }
                }

                Button("Submit Activity") {
                    let points: Int
                    switch physical {
                    case "High":
                        points = 30
                    case "Moderate":
                        points = 20
                    default:
                        points = 10
                    }

                    db.collection("activities").addDocument(data: [
                        "name": name,
                        "description": description,
                        "age": age,
                        "physical": physical,
                        "cost": cost,
                        "shelter": shelter,
                        "time": time,
                        "requirement": requirement,
                        "points": points,
                        "completedCount": completedCount,
                        "createdAt": Timestamp(date: Date())
                    ]) { error in
                        if let error = error {
                            print("Failed to add activity: \(error.localizedDescription)")
                        } else {
                            dismiss()
                        }
                    }
                }
                .disabled(name.isEmpty)
            }
            .navigationTitle("Add Activity")
        }
    }
}

struct EditActivityView: View {
    @Environment(\.dismiss) private var dismiss
    private let db = Firestore.firestore()

    let activity: Activity

    @State private var name: String
    @State private var description: String
    @State private var requirement: String
    @State private var age: String
    @State private var physical: String
    @State private var cost: String
    @State private var shelter: String
    @State private var time: String
    @State private var completedCount: Int

    let ages = ["Any", "Kids", "Teens", "Adults", "Seniors"]
    let physicalLevels = ["Low", "Moderate", "High"]
    let costs = ["Free", "$", "$$", "$$$"]
    let shelters = ["Indoor", "Outdoor", "Both"]
    let times = ["<15 mins", "15-30 mins", "30-60 mins", "1hr+"]

    init(activity: Activity) {
        self.activity = activity
        _name = State(initialValue: activity.name)
        _description = State(initialValue: "")
        _requirement = State(initialValue: activity.requirement)
        _age = State(initialValue: activity.age)
        _physical = State(initialValue: activity.physical)
        _cost = State(initialValue: activity.cost)
        _shelter = State(initialValue: activity.shelter)
        _time = State(initialValue: activity.time)
        _completedCount = State(initialValue: 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("Activity Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Requirement", text: $requirement)
                    Stepper("Completed: \(completedCount)", value: $completedCount, in: 0...10000)
                }

                Section("Filters") {
                    Picker("Age", selection: $age) {
                        ForEach(ages, id: \.self) { Text($0) }
                    }
                    Picker("Physical Activity", selection: $physical) {
                        ForEach(physicalLevels, id: \.self) { Text($0) }
                    }
                    Picker("Cost", selection: $cost) {
                        ForEach(costs, id: \.self) { Text($0) }
                    }
                    Picker("Shelter", selection: $shelter) {
                        ForEach(shelters, id: \.self) { Text($0) }
                    }
                    Picker("Time", selection: $time) {
                        ForEach(times, id: \.self) { Text($0) }
                    }
                }

                Button("Save Changes") {
                    db.collection("activities").document(activity.id).updateData([
                        "name": name,
                        "description": description,
                        "requirement": requirement,
                        "age": age,
                        "physical": physical,
                        "cost": cost,
                        "shelter": shelter,
                        "time": time,
                        "completedCount": completedCount,
                    ]) { error in
                        if let error = error {
                            print("Failed to edit activity: \(error.localizedDescription)")
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Edit Activity")
        }
    }
}
