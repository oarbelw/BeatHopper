import Foundation

/// Row from worldcities.csv for search (city_ascii, city, admin_name).
private struct CSVCityRow {
    let city: String
    let cityAscii: String
    let adminName: String
    let country: String
    let lat: Double
    let lng: Double
    let id: String
    var toCity: City {
        City(id: id, name: city.isEmpty ? cityAscii : city, country: country, latitude: lat, longitude: lng)
    }
}

/// Loads worldcities.csv from the app bundle and provides local search (no API).
final class WorldCitiesService {
    static let shared = WorldCitiesService()
    private var rows: [CSVCityRow] = []
    private let lock = NSLock()
    private let maxResults = 50

    private init() {}

    private func loadIfNeeded() {
        lock.lock()
        if !rows.isEmpty {
            lock.unlock()
            return
        }
        lock.unlock()

        guard let url = Bundle.main.url(forResource: "worldcities", withExtension: "csv") else {
            print("WorldCitiesService: worldcities.csv not found in bundle")
            return
        }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        let lines = content.components(separatedBy: .newlines)
        guard lines.count > 1 else { return }
        var parsed: [CSVCityRow] = []
        for (index, line) in lines.enumerated() {
            if index == 0 { continue }
            let fields = parseCSVLine(line)
            guard fields.count >= 11,
                  let lat = Double(fields[2]),
                  let lng = Double(fields[3]) else { continue }
            let city = fields[0]
            let cityAscii = fields[1]
            let country = fields[4]
            let adminName = fields.count > 7 ? fields[7] : ""
            let id = fields[10].isEmpty ? UUID().uuidString : fields[10]
            parsed.append(CSVCityRow(city: city, cityAscii: cityAscii, adminName: adminName, country: country, lat: lat, lng: lng, id: id))
        }
        lock.lock()
        rows = parsed
        lock.unlock()
    }

    /// Parse a single CSV line with quoted fields (e.g. "Tokyo","Tokyo","35.6870",...).
    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
            } else if (ch == "," && !inQuotes) {
                result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(ch)
            }
        }
        result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        return result
    }

    /// Search: first by city_ascii, then by city, then by admin_name. Returns up to maxResults.
    func search(query: String) -> [City] {
        loadIfNeeded()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard q.count >= 2 else { return [] }
        lock.lock()
        let list = rows
        lock.unlock()
        guard !list.isEmpty else { return [] }
        var result: [CSVCityRow] = []
        result = list.filter { $0.cityAscii.lowercased().contains(q) }
        if result.isEmpty {
            result = list.filter { $0.city.lowercased().contains(q) }
        }
        if result.isEmpty {
            result = list.filter { $0.adminName.lowercased().contains(q) }
        }
        return Array(result.prefix(maxResults)).map(\.toCity)
    }
}
