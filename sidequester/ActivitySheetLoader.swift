import Foundation

enum ActivitySheetLoader {
    private static let url = URL(string: "https://docs.google.com/spreadsheets/d/e/2PACX-1vT7g9MXU0G2IaBbRLBIibkNousoKgkKchOSOJDOnne0bliq-DQIwZpK2lloMTlq_dw77hFxGDbT1y1h/pub?gid=626237042&single=true&output=csv")!

    static func loadActivities() async throws -> [Activity] {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return parse(String(decoding: data, as: UTF8.self))
    }

    private static func parse(_ csv: String) -> [Activity] {
        let rows = csv.split(whereSeparator: \.isNewline).map { parseRow(String($0)) }
        guard let header = rows.first else { return [] }
        let keys = header.map { $0.lowercased().filter { $0.isLetter || $0.isNumber } }

        func field(_ row: [String], _ names: [String], default fallback: String) -> String {
            for name in names {
                if let index = keys.firstIndex(of: name), index < row.count, !row[index].isEmpty { return row[index] }
            }
            return fallback
        }

        return rows.dropFirst().enumerated().compactMap { index, row in
            let name = field(row, ["name", "activity", "activityname", "title"], default: "")
            guard !name.isEmpty else { return nil }
            let pointsText = field(row, ["points", "point", "xp"], default: "10")
            return Activity(id: "sheet-\(index)", name: name, description: field(row, ["description", "details"], default: ""), age: field(row, ["age", "agegroup"], default: "Any"), physical: field(row, ["physical", "effort", "difficulty"], default: "Low"), cost: field(row, ["cost", "price"], default: "Free"), shelter: field(row, ["shelter", "location", "indooroutdoor"], default: "Both"), time: field(row, ["time", "duration"], default: "Flexible"), requirement: field(row, ["requirement", "requirements"], default: "None"), points: Int(pointsText.filter(\.isNumber)) ?? 10, completedCount: 0)
        }
    }

    private static func parseRow(_ line: String) -> [String] {
        var values: [String] = []; var value = ""; var quoted = false
        for character in line {
            if character == "\"" { quoted.toggle() }
            else if character == "," && !quoted { values.append(value); value = "" }
            else { value.append(character) }
        }
        values.append(value); return values
    }
}
