//
//  SheetImporter.swift
//  Sidequester
//
//  Imports activities from the published Google Sheet
//  into Firestore.
//

import Foundation
import FirebaseFirestore

struct SheetImportResult {
    let found: Int
    let imported: Int
}

enum SheetImporterError: LocalizedError {
    case invalidResponse
    case notCSV
    case noValidActivities
    case firestoreWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The Google Sheet returned an invalid response."

        case .notCSV:
            return "The Google Sheet did not return CSV data."

        case .noValidActivities:
            return "No valid activities were found in the sheet."

        case .firestoreWriteFailed(let message):
            return "Firestore import failed: \(message)"
        }
    }
}

struct SheetImporter {

    // MARK: - Google Sheet

    static let sidequesterSheetURL =
        "https://docs.google.com/spreadsheets/d/e/2PACX-1vT7g9MXU0G2IaBbRLBIibkNousoKgkKchOSOJDOnne0bliq-DQIwZpK2lloMTlq_dw77hFxGDbT1y1h/pub?gid=0&single=true&output=csv"

    // MARK: - Import

    static func importIntoFirestore(
        fromPublishedSheetURL urlString: String
    ) async throws -> SheetImportResult {

        print("")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("SIDEQUESTER SHEET IMPORT")
        print("")
        print("URL:")
        print(urlString)
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        guard let url = URL(string: urlString) else {
            throw SheetImporterError.invalidResponse
        }

        // Add a cache-buster so iOS does not reuse an old CSV response.
        var components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )

        var queryItems = components?.queryItems ?? []

        queryItems.append(
            URLQueryItem(
                name: "_sidequester_cache",
                value: UUID().uuidString
            )
        )

        components?.queryItems = queryItems

        guard let finalURL = components?.url else {
            throw SheetImporterError.invalidResponse
        }

        var request = URLRequest(url: finalURL)

        request.httpMethod = "GET"

        request.setValue(
            "text/csv, text/plain, */*",
            forHTTPHeaderField: "Accept"
        )

        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SheetImporterError.invalidResponse
        }

        let statusCode = httpResponse.statusCode

        let mimeType =
            httpResponse.mimeType ?? "unknown"

        print("")
        print("HTTP STATUS: \(statusCode)")
        print("MIME TYPE: \(mimeType)")
        print("CONTENT LENGTH: \(data.count)")

        guard (200...299).contains(statusCode) else {
            throw SheetImporterError.invalidResponse
        }

        // Google Sheets normally returns UTF-8.
        // Strip a possible UTF-8 BOM.
        guard var csvText = String(
            data: data,
            encoding: .utf8
        ) else {
            throw SheetImporterError.invalidResponse
        }

        csvText = csvText.replacingOccurrences(
            of: "\u{FEFF}",
            with: ""
        )

        print("")
        print("CSV PREVIEW:")
        print(
            csvText.prefix(1000)
        )
        print("")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Make sure Google actually returned CSV.
        let lowercasedPreview = csvText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()

        if lowercasedPreview.contains("<html") ||
            lowercasedPreview.contains("<!doctype") {

            throw SheetImporterError.notCSV
        }

        // MARK: Parse CSV

        let rows = parseCSV(csvText)

        print("")
        print("TOTAL CSV ROWS: \(rows.count)")

        guard !rows.isEmpty else {
            throw SheetImporterError.noValidActivities
        }

        // First row is the header.
        let rawHeaders = rows[0]

        let headers = rawHeaders.map {
            normalizeHeader($0)
        }

        print("")
        print("DETECTED HEADERS:")
        print(headers)

        guard let nameIndex = findHeader(
            headers,
            names: [
                "name",
                "activity",
                "activity name"
            ]
        ) else {

            print("")
            print("❌ Could not find Name column.")

            throw SheetImporterError.noValidActivities
        }

        let ageIndex = findHeader(
            headers,
            names: [
                "age",
                "age range",
                "filters age"
            ]
        )

        let effortIndex = findHeader(
            headers,
            names: [
                "effort",
                "physical",
                "physical activity",
                "effort level"
            ]
        )

        let costIndex = findHeader(
            headers,
            names: [
                "cost",
                "price"
            ]
        )

        let shelterIndex = findHeader(
            headers,
            names: [
                "sheltered",
                "shelter",
                "indoors outdoors"
            ]
        )

        let durationIndex = findHeader(
            headers,
            names: [
                "duration",
                "time",
                "time required"
            ]
        )

        let requirementIndex = findHeader(
            headers,
            names: [
                "requirement",
                "requirements"
            ]
        )

        let pointsIndex = findHeader(
            headers,
            names: [
                "points",
                "point"
            ]
        )

        print("")
        print("COLUMN INDICES:")
        print("Name: \(String(describing: nameIndex))")
        print("Age: \(String(describing: ageIndex))")
        print("Effort: \(String(describing: effortIndex))")
        print("Cost: \(String(describing: costIndex))")
        print("Shelter: \(String(describing: shelterIndex))")
        print("Duration: \(String(describing: durationIndex))")
        print("Requirement: \(String(describing: requirementIndex))")
        print("Points: \(String(describing: pointsIndex))")

        // MARK: Convert rows into dictionaries

        var activityDictionaries:
            [[String: Any]] = []

        for row in rows.dropFirst() {

            // Ignore completely empty rows.
            if row.allSatisfy({
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
            }) {
                continue
            }

            guard nameIndex < row.count else {
                continue
            }

            let name = cleanValue(
                row[nameIndex]
            )

            // Every valid activity needs a name.
            guard !name.isEmpty else {
                continue
            }

            let age = value(
                from: row,
                index: ageIndex
            )

            let effort = value(
                from: row,
                index: effortIndex
            )

            let cost = value(
                from: row,
                index: costIndex
            )

            let shelter = value(
                from: row,
                index: shelterIndex
            )

            let duration = value(
                from: row,
                index: durationIndex
            )

            let requirement = value(
                from: row,
                index: requirementIndex
            )

            let points = parseInt(
                value(
                    from: row,
                    index: pointsIndex
                )
            )

            let dictionary: [String: Any] = [

                "name": name,

                "description": "",

                "age": normalizeAge(age),

                "physical": normalizeEffort(effort),

                "cost": normalizeCost(cost),

                "shelter": normalizeShelter(shelter),

                "time": normalizeDuration(duration),

                "requirement": requirement,

                "points": points,

                "completedCount": 0,

                "updatedAt": Timestamp(
                    date: Date()
                )
            ]

            activityDictionaries.append(
                dictionary
            )
        }

        print("")
        print(
            "DATA ROWS: \(max(0, rows.count - 1))"
        )

        print(
            "DICTIONARIES CREATED: \(activityDictionaries.count)"
        )

        guard !activityDictionaries.isEmpty else {

            print("")
            print("❌ NO VALID ACTIVITIES FOUND")

            throw SheetImporterError.noValidActivities
        }

        print("")
        print(
            "FOUND ROWS: \(activityDictionaries.count)"
        )

        // MARK: Firestore

        let db = Firestore.firestore()

        var importedCount = 0

        print("")
        print("STARTING FIRESTORE IMPORT...")
        print("")

        for activity in activityDictionaries {

            guard let name = activity["name"] as? String else {
                continue
            }

            do {

                // Search for an existing activity with the same name.
                let snapshot = try await db
                    .collection("activities")
                    .whereField(
                        "name",
                        isEqualTo: name
                    )
                    .limit(to: 1)
                    .getDocuments()

                if let existingDocument =
                    snapshot.documents.first {

                    print(
                        "↻ Updating: \(name)"
                    )

                    try await db
                        .collection("activities")
                        .document(existingDocument.documentID)
                        .setData(
                            activity,
                            merge: true
                        )

                } else {

                    print(
                        "＋ Creating: \(name)"
                    )

                    var newActivity = activity

                    newActivity["createdAt"] =
                        Timestamp(
                            date: Date()
                        )

                    try await db
                        .collection("activities")
                        .addDocument(
                            data: newActivity
                        )
                }

                importedCount += 1

            } catch {

                print("")
                print(
                    "❌ FIRESTORE FAILED FOR: \(name)"
                )

                print(
                    "ERROR: \(error.localizedDescription)"
                )

                print("")

                throw SheetImporterError
                    .firestoreWriteFailed(
                        error.localizedDescription
                    )
            }
        }

        print("")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("IMPORT COMPLETE")
        print("")
        print(
            "FOUND: \(activityDictionaries.count)"
        )
        print(
            "IMPORTED: \(importedCount)"
        )
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("")

        return SheetImportResult(
            found: activityDictionaries.count,
            imported: importedCount
        )
    }

    // MARK: - CSV Parser

    private static func parseCSV(
        _ text: String
    ) -> [[String]] {

        // Google Sheets commonly uses CRLF.
        // Normalize every line ending first.
        let normalizedText = text
            .replacingOccurrences(
                of: "\r\n",
                with: "\n"
            )
            .replacingOccurrences(
                of: "\r",
                with: "\n"
            )

        var rows: [[String]] = []

        var currentRow: [String] = []

        var currentField = ""

        var insideQuotes = false

        let characters = Array(
            normalizedText
        )

        var index = 0

        while index < characters.count {

            let character = characters[index]

            if insideQuotes {

                if character == "\"" {

                    // Escaped quote: ""
                    if index + 1 < characters.count,
                       characters[index + 1] == "\"" {

                        currentField.append("\"")

                        index += 1

                    } else {

                        insideQuotes = false
                    }

                } else {

                    currentField.append(
                        character
                    )
                }

            } else {

                switch character {

                case "\"":

                    insideQuotes = true

                case ",":

                    currentRow.append(
                        currentField
                    )

                    currentField = ""

                case "\n":

                    currentRow.append(
                        currentField
                    )

                    let isEmptyRow =
                        currentRow.allSatisfy {
                            $0.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty
                        }

                    if !isEmptyRow {
                        rows.append(
                            currentRow
                        )
                    }

                    currentRow = []

                    currentField = ""

                default:

                    currentField.append(
                        character
                    )
                }
            }

            index += 1
        }

        // Add final row.
        if !currentField.isEmpty ||
            !currentRow.isEmpty {

            currentRow.append(
                currentField
            )

            let isEmptyRow =
                currentRow.allSatisfy {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                }

            if !isEmptyRow {
                rows.append(
                    currentRow
                )
            }
        }

        return rows
    }

    // MARK: - Header Helpers

    private static func normalizeHeader(
        _ header: String
    ) -> String {

        header
            .replacingOccurrences(
                of: "\u{FEFF}",
                with: ""
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
    }

    private static func findHeader(
        _ headers: [String],
        names: [String]
    ) -> Int? {

        for name in names {

            if let index = headers.firstIndex(
                of: name
            ) {
                return index
            }
        }

        return nil
    }

    // MARK: - Value Helpers

    private static func value(
        from row: [String],
        index: Int?
    ) -> String {

        guard let index,
              index >= 0,
              index < row.count
        else {
            return ""
        }

        return cleanValue(
            row[index]
        )
    }

    private static func cleanValue(
        _ value: String
    ) -> String {

        value
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .replacingOccurrences(
                of: "\u{FEFF}",
                with: ""
            )
    }

    private static func parseInt(
        _ value: String
    ) -> Int {

        let cleaned = value
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if let number = Int(cleaned) {
            return number
        }

        // Handles values such as "2.0"
        if let doubleValue = Double(cleaned) {
            return Int(doubleValue)
        }

        return 0
    }

    // MARK: - Normalization

    private static func normalizeAge(
        _ value: String
    ) -> String {

        let lower = value
            .lowercased()
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if lower.contains("13") {
            return "Teens"
        }

        if lower.contains("kid") {
            return "Kids"
        }

        if lower.contains("senior") {
            return "Seniors"
        }

        if lower.contains("adult") {
            return "Adults"
        }

        return value.isEmpty
            ? "Any"
            : value
    }

    private static func normalizeEffort(
        _ value: String
    ) -> String {

        let lower = value.lowercased()

        if lower.contains("high") ||
            lower.contains("tiring") {

            return "High"
        }

        if lower.contains("moderate") {

            return "Moderate"
        }

        if lower.contains("leisure") ||
            lower.contains("relax") {

            return "Low"
        }

        if lower.contains("low") {

            return "Low"
        }

        return value.isEmpty
            ? "Low"
            : value
    }

    private static func normalizeCost(
        _ value: String
    ) -> String {

        let lower = value.lowercased()

        if lower == "free" {
            return "Free"
        }

        if lower.contains("25") {
            return "$$$"
        }

        if lower.contains("10") {
            return "$"
        }

        return value.isEmpty
            ? "Free"
            : value
    }

    private static func normalizeShelter(
        _ value: String
    ) -> String {

        let lower = value.lowercased()

        if lower.contains("both") ||
            lower.contains("depends") {

            return "Both"
        }

        if lower.contains("indoor") {
            return "Indoor"
        }

        if lower.contains("outdoor") {
            return "Outdoor"
        }

        return value.isEmpty
            ? "Both"
            : value
    }

    private static func normalizeDuration(
        _ value: String
    ) -> String {

        let lower = value.lowercased()

        if lower.contains("30") &&
            lower.contains("mins") {

            return "30-60 mins"
        }

        if lower.contains("2 hrs") ||
            lower.contains("1 hr") {

            return "1 hour+"
        }

        if lower.contains("15") {

            return "15-30 mins"
        }

        if lower.contains("30") {

            return "30-60 mins"
        }

        return value.isEmpty
            ? "15-30 mins"
            : value
    }
}
