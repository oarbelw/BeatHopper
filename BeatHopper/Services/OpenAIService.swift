import Foundation
import CoreLocation

class OpenAIService: ObservableObject {
    static let shared = OpenAIService()

    private let geminiModel = "gemini-3-flash-preview"
    private let geminiBase = "https://generativelanguage.googleapis.com/v1beta/models"

    /// URLSession: long timeouts so thinking + search batches don't hit -1001 (request timed out).
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 240
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    // MARK: - Core Chat (Gemini 3 API — matches browser config: thinking_level high, topP/topK, google_search)
    func chat(apiKey: String, system: String, user: String, maxTokens: Int = 65536, temperature: Double = 1.0) async throws -> String {
        guard !apiKey.isEmpty else { throw BHError.missingAPIKey }

        struct Part: Codable {
            let text: String?
            let thought: Bool?
        }
        struct Content: Codable { let parts: [Part] }
        struct ThinkingConfig: Codable {
            let thinkingLevel: String?
        }
        struct GenConfig: Codable {
            let maxOutputTokens: Int?
            let temperature: Double?
            let topP: Double?
            let topK: Int?
            let thinkingConfig: ThinkingConfig?
            enum CodingKeys: String, CodingKey {
                case maxOutputTokens, temperature, topP, topK, thinkingConfig
            }
        }
        struct GoogleSearchTool: Codable {
            let google_search: EmptyDict?
            struct EmptyDict: Codable {}
        }
        struct Req: Codable {
            let systemInstruction: Content?
            let contents: [Content]
            let generationConfig: GenConfig?
            let tools: [GoogleSearchTool]?
        }
        struct Res: Codable {
            struct Candidate: Codable {
                struct Content: Codable {
                    let parts: [Part]?
                }
                let content: Content?
            }
            let candidates: [Candidate]?
        }

        let url = URL(string: "\(geminiBase)/\(geminiModel):generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        let body = Req(
            systemInstruction: Content(parts: [Part(text: system, thought: nil)]),
            contents: [Content(parts: [Part(text: user, thought: nil)])],
            generationConfig: GenConfig(
                maxOutputTokens: maxTokens,
                temperature: temperature,
                topP: 0.95,
                topK: 64,
                thinkingConfig: ThinkingConfig(thinkingLevel: "high")
            ),
            tools: [GoogleSearchTool(google_search: GoogleSearchTool.EmptyDict())]
        )
        request.httpBody = try JSONEncoder().encode(body)

        var lastError: Error?
        for attempt in 0..<3 {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw BHError.apiError }
                guard http.statusCode == 200 else {
                    if let bodyStr = String(data: data, encoding: .utf8) { print("Gemini error (\(http.statusCode)): \(bodyStr)") }
                    throw BHError.apiError
                }

                let decoded = try JSONDecoder().decode(Res.self, from: data)
                guard let candidates = decoded.candidates,
                      let first = candidates.first,
                      let content = first.content,
                      let parts = content.parts, !parts.isEmpty else {
                    lastError = BHError.apiError
                    if attempt < 2 { try await Task.sleep(nanoseconds: 1_500_000_000); continue }
                    throw BHError.apiError
                }
                // Gemini 3 with thinking: parts can be [thought, answer]. Use non-thought part(s), else last/first part.
                let nonThoughtTexts = parts.compactMap { p -> String? in
                    guard let t = p.text, !t.isEmpty, p.thought != true else { return nil }; return t
                }
                let text: String = !nonThoughtTexts.isEmpty ? nonThoughtTexts.joined(separator: "\n")
                    : (parts.last?.text).flatMap { $0.isEmpty ? nil : $0 }
                    ?? (parts.first?.text).flatMap { $0.isEmpty ? nil : $0 }
                    ?? ""
                if !text.isEmpty { return text }
                lastError = BHError.apiError
                if attempt < 2 { try await Task.sleep(nanoseconds: 1_500_000_000) }
                continue
            } catch {
                lastError = error
                if attempt < 2 { try? await Task.sleep(nanoseconds: 1_500_000_000) }
            }
        }
        throw lastError ?? BHError.apiError
    }

    // MARK: - Find Concerts (batch of 5 artists; smaller batches + low temp + high token budget for completeness)
    func findConcertsForArtistsBatch(artists: [Artist], cities: [City], apiKey: String) async throws -> [Concert] {
        guard !artists.isEmpty else { return [] }
        let cityList = cities.map { "\($0.name), \($0.country)" }.joined(separator: ", ")
        let today    = todayString()
        let oneYear  = oneYearFromNowString()
        let artistList = artists.map { $0.name }.joined(separator: ", ")

        let system = """
        You are a concert fact-checker. You answer ONLY with a JSON array. No markdown, no explanation, no preamble.
        For EACH of the following artists, check if they have any CONFIRMED upcoming concert within 50km of any of the given cities, between \(today) and \(oneYear). Only include a show if you are certain (real venue, real date, actually announced — not guessed).
        Each show object must have: id (string), artistName (string), venueName (string), venueAddress (string), city (string), country (string), date (string YYYY-MM-DD), time (string or null), ticketURL (string or null), latitude (number), longitude (number), distance (number), priceRange (string or null), genre (string or null), description (string or null), isSuggestion (false).
        CRITICAL: Return EVERY confirmed show you find. Do not omit shows you have verified. Use search to check each artist's tour dates and include all matches. Prefer a complete list over a short one. If an artist has no such show or you are not certain, omit only that artist. Do NOT invent or guess.
        """

        let user = "Artists to check: \(artistList). Cities (within 50km): \(cityList). Date range: \(today) to \(oneYear). Return the complete JSON array of ALL shows you find (empty array only if none)."

        let label = "Artists: \(artistList)"
        let entryId = AIDebugStore.shared.logThinking(label: label, systemPrompt: system, userPrompt: user)
        let start = Date()

        do {
            let raw = try await chat(apiKey: apiKey, system: system, user: user, maxTokens: 16384, temperature: 0.4)
            let durationMs = Int(Date().timeIntervalSince(start) * 1000)
            await MainActor.run {
                AIDebugStore.shared.complete(entryId: entryId, response: raw, durationMs: durationMs)
            }
            return parseConcerts(raw)
        } catch {
            let durationMs = Int(Date().timeIntervalSince(start) * 1000)
            await MainActor.run {
                AIDebugStore.shared.complete(entryId: entryId, response: "Error: \(error.localizedDescription)", durationMs: durationMs)
            }
            throw error
        }
    }

    // MARK: - Find Local Music Tonight
    func findLocalMusic(latitude: Double, longitude: Double, apiKey: String) async throws -> [LocalVenue] {
        let today = todayString()
        let system = """
        You are a local nightlife guide. Return ONLY a valid JSON array, no markdown fences.
        Each element must have:
          id (string UUID), name (string), address (string), latitude (number), longitude (number),
          genre (string or null), tonightEvent (string or null), priceRange (string or null),
          rating (number 1.0-5.0 or null), description (string or null)
        Return real venues near the given coordinates that likely have live music tonight (\(today)).
        Return up to 10 results. If unsure, return well-known live music venues in the area.
        """
        let user = "Find live music venues near lat:\(latitude) lon:\(longitude) tonight (\(today)). Return JSON only."
        let raw  = try await chat(apiKey: apiKey, system: system, user: user)
        return parseVenues(raw)
    }

    // MARK: - Generate Show Suggestions
    func generateShowSuggestions(artists: [Artist], cities: [City], apiKey: String) async throws -> [ShowSuggestion] {
        let artistList = artists.map { $0.name }.joined(separator: ", ")
        let genres     = Array(Set(artists.flatMap { $0.genres })).prefix(8).joined(separator: ", ")
        let cityList   = cities.map { $0.name }.joined(separator: ", ")
        let today      = todayString()

        let system = """
        You are a live music curator. Return ONLY a valid JSON array, no markdown fences.
        Each element must have:
          id (string UUID), artistName (string), venueName (string), city (string),
          date (string YYYY-MM-DD), ticketURL (string or null),
          whyRecommended (string — 1 sentence explaining why they'd love it),
          similarTo (array of strings — artist names from the USER'S list that this artist is similar to),
          genre (string or null)
        CRITICAL RULES:
        - Suggest ONLY artists who are NOT already in the user's list. The user already follows the artists they gave you — do NOT suggest those. Suggest NEW artists they might like.
        - Only include shows you can VERIFY are real: real venue, real date, actually announced. Do NOT invent or guess. If you are not certain a show exists, omit it.
        - Return fewer results (or an empty array) rather than fabricating shows. No fake dates or venues.
        - Set ticketURL to null unless you know the real ticketing URL.
        - similarTo must be artist names FROM the user's list (artists they already follow). The suggested artist should be similar to those.
        - Today is \(today). Only include shows dated after today.
        - Only suggest shows in the user's cities: \(cityList).
        """
        let user = "Artists the user ALREADY follows (do NOT suggest these): \(artistList). Genres they like: \(genres.isEmpty ? "various" : genres). My cities: \(cityList). Suggest 6–8 OTHER artists (not in that list) with real upcoming shows in those cities. Return JSON only."
        let raw  = try await chat(apiKey: apiKey, system: system, user: user)
        return parseSuggestions(raw)
    }

    // MARK: - Search Artists
    func searchArtists(query: String, apiKey: String) async throws -> [Artist] {
        let system = """
        You are a music database. Return ONLY a valid JSON array, no markdown fences.
        Each element must have:
          id (string unique), name (string), genres (array of strings), popularity (number 0-100)
        Return up to 8 artists matching the search query. Be accurate.
        """
        let user = "Search for artists matching: '\(query)'. Return JSON only."
        let raw  = try await chat(apiKey: apiKey, system: system, user: user, maxTokens: 1000)

        let cleaned = cleanJSON(raw)
        guard let data = cleaned.data(using: .utf8),
              let arr  = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { obj -> Artist? in
            guard let name = obj["name"] as? String else { return nil }
            return Artist(
                id:         obj["id"] as? String ?? UUID().uuidString,
                name:       name,
                genres:     obj["genres"] as? [String] ?? [],
                popularity: obj["popularity"] as? Int,
                source:     .manual
            )
        }
    }

    // MARK: - Search Cities
    func searchCities(query: String, apiKey: String) async throws -> [City] {
        let system = """
        You are a geography database. Return ONLY a valid JSON array, no markdown fences.
        Each element must have: id (string), name (string), country (string), latitude (number), longitude (number).
        Return up to 6 real cities matching the query.
        """
        let user = "Find cities matching: '\(query)'. Return JSON only."
        let raw  = try await chat(apiKey: apiKey, system: system, user: user, maxTokens: 800)

        let cleaned = cleanJSON(raw)
        guard let data = cleaned.data(using: .utf8),
              let arr  = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { obj -> City? in
            guard let name    = obj["name"] as? String,
                  let country = obj["country"] as? String,
                  let lat     = obj["latitude"] as? Double,
                  let lon     = obj["longitude"] as? Double else { return nil }
            return City(id: obj["id"] as? String ?? UUID().uuidString, name: name, country: country, latitude: lat, longitude: lon)
        }
    }

    // MARK: - Parsers
    private func parseConcerts(_ raw: String) -> [Concert] {
        let cleaned = cleanJSON(raw)
        guard let data = cleaned.data(using: .utf8),
              let arr  = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { obj -> Concert? in
            let artistName = (obj["artistName"] as? String ?? obj["artist_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let venueName  = (obj["venueName"] as? String ?? obj["venue_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let artistName = artistName, !artistName.isEmpty,
                  let venueName  = venueName, !venueName.isEmpty else { return nil }
            let dateStr = concertDateString(from: obj["date"] ?? obj["dateTime"])
            guard let dateStr = dateStr, !dateStr.isEmpty else { return nil }
            return Concert(
                id:           obj["id"] as? String ?? UUID().uuidString,
                artistName:   artistName,
                venueName:    venueName,
                venueAddress: (obj["venueAddress"] as? String) ?? "",
                city:         (obj["city"] as? String) ?? "",
                country:      (obj["country"] as? String) ?? "",
                date:         dateStr,
                time:         obj["time"] as? String,
                ticketURL:    obj["ticketURL"] as? String,
                latitude:     numberFrom(obj["latitude"]),
                longitude:    numberFrom(obj["longitude"]),
                distance:     numberFrom(obj["distance"]),
                priceRange:   obj["priceRange"] as? String,
                genre:        obj["genre"] as? String,
                description:  obj["description"] as? String,
                isSuggestion: false
            )
        }
    }

    /// Coerce date from API (string "YYYY-MM-DD", ISO date-time, or number timestamp) to "YYYY-MM-DD".
    private func concertDateString(from value: Any?) -> String? {
        if let s = value as? String, !s.isEmpty {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count >= 10, trimmed.contains("-") { return String(trimmed.prefix(10)) }
            return trimmed
        }
        if let n = value as? NSNumber {
            let t = n.doubleValue
            if t > 1e12 { return isoDate(from: Date(timeIntervalSince1970: t / 1000)) }
            if t > 1e9  { return isoDate(from: Date(timeIntervalSince1970: t)) }
        }
        return nil
    }
    private func isoDate(from d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: d)
    }
    private func numberFrom(_ value: Any?) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private func parseVenues(_ raw: String) -> [LocalVenue] {
        let cleaned = cleanJSON(raw)
        guard let data = cleaned.data(using: .utf8),
              let arr  = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { obj -> LocalVenue? in
            guard let name = obj["name"] as? String,
                  let lat  = obj["latitude"] as? Double,
                  let lon  = obj["longitude"] as? Double else { return nil }
            return LocalVenue(
                id:           obj["id"] as? String ?? UUID().uuidString,
                name:         name,
                address:      obj["address"] as? String ?? "",
                latitude:     lat,
                longitude:    lon,
                genre:        obj["genre"] as? String,
                tonightEvent: obj["tonightEvent"] as? String,
                priceRange:   obj["priceRange"] as? String,
                rating:       obj["rating"] as? Double,
                description:  obj["description"] as? String
            )
        }
    }

    private func parseSuggestions(_ raw: String) -> [ShowSuggestion] {
        let cleaned = cleanJSON(raw)
        guard let data = cleaned.data(using: .utf8),
              let arr  = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { obj -> ShowSuggestion? in
            guard let artistName = obj["artistName"] as? String,
                  let venueName  = obj["venueName"] as? String,
                  let city       = obj["city"] as? String,
                  let date       = obj["date"] as? String else { return nil }
            return ShowSuggestion(
                id:               obj["id"] as? String ?? UUID().uuidString,
                artistName:       artistName,
                venueName:        venueName,
                city:             city,
                date:             date,
                ticketURL:        obj["ticketURL"] as? String,
                whyRecommended:   obj["whyRecommended"] as? String ?? "",
                similarTo:        obj["similarTo"] as? [String] ?? [],
                genre:            obj["genre"] as? String
            )
        }
    }

    private func cleanJSON(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```json") { s = String(s.dropFirst(7)) }
        if s.hasPrefix("```")     { s = String(s.dropFirst(3)) }
        if s.hasSuffix("```")     { s = String(s.dropLast(3)) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func todayString() -> String {
        let f = DateFormatter(); f.dateStyle = .full; return f.string(from: Date())
    }
    
    private func oneYearFromNowString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Calendar.current.date(byAdding: .year, value: 1, to: Date())!)
    }
}

// MARK: - BHError
enum BHError: LocalizedError {
    case missingAPIKey, apiError, locationUnavailable

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:       return "Gemini API key is missing. Add it in Settings."
        case .apiError:            return "Could not reach the Gemini API. Check your key and internet connection."
        case .locationUnavailable: return "Location is unavailable. Please allow location access."
        }
    }
}
