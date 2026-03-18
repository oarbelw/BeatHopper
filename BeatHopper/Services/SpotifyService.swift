import Foundation
import CryptoKit

class SpotifyService: ObservableObject {
    static let shared = SpotifyService()

    private let clientID = "1cfc251424184e8b8ce798909c12e3bc" // My real Client ID
    private let redirectURI = "beathopper://spotify-callback"
    private let scopes = "user-top-read user-read-private"

    private let codeVerifierKey = "spotifyPKCECodeVerifier"

    @Published var isConnected = false
    @Published var accessToken: String?

    // PKCE values — generated fresh each auth attempt (in-memory + persisted so callback works after app relaunch)
    private var codeVerifier: String = ""
    private var codeChallenge: String = ""
    private var state: String = ""

    init() {
        // Restore token so we show "Connected" after app relaunch
        if let token = UserDefaults.standard.string(forKey: "spotifyToken"), !token.isEmpty {
            accessToken = token
            isConnected = true
        }
    }

    func buildAuthURL() -> URL? {
        // Generate PKCE values and persist verifier so token exchange works when user returns from Safari (app may have been terminated)
        codeVerifier = generateCodeVerifier()
        codeChallenge = generateCodeChallenge(from: codeVerifier)
        state = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        UserDefaults.standard.set(codeVerifier, forKey: codeVerifierKey)

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id",             value: clientID),
            URLQueryItem(name: "response_type",         value: "code"),
            URLQueryItem(name: "redirect_uri",          value: redirectURI),
            URLQueryItem(name: "scope",                 value: scopes),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge",        value: codeChallenge),
            URLQueryItem(name: "state",                 value: state),
            URLQueryItem(name: "show_dialog",           value: "true")
        ]
        return components?.url
    }

    // Called from BeatHopperApp.onOpenURL after Spotify redirects back
    func handleCallback(url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else { return }

        await exchangeCodeForToken(code: code)
    }

    private func exchangeCodeForToken(code: String) async {
        // Use persisted verifier if app was terminated while user was in Safari (in-memory verifier would be lost)
        let verifier = UserDefaults.standard.string(forKey: codeVerifierKey) ?? codeVerifier
        UserDefaults.standard.removeObject(forKey: codeVerifierKey)
        codeVerifier = ""

        guard !verifier.isEmpty, let url = URL(string: "https://accounts.spotify.com/api/token") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type":    "authorization_code",
            "code":          code,
            "redirect_uri":  redirectURI,
            "client_id":     clientID,
            "code_verifier": verifier
        ]
        .map { "\($0.key)=\($0.value)" }
        .joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["access_token"] as? String {
                await MainActor.run {
                    self.accessToken = token
                    self.isConnected = true
                    UserDefaults.standard.set(token, forKey: "spotifyToken")
                }
            } else {
                print("Spotify token exchange failed: \(String(data: data, encoding: .utf8) ?? "")")
            }
        } catch {
            print("Spotify token request error: \(error)")
        }
    }

    func fetchTopArtists() async throws -> [Artist] {
        guard let token = accessToken else { throw SpotifyError.notConnected }

        // First 85: most listened in last 6 months (medium_term). API returns max 50 per request, so paginate.
        let mediumPage1 = try await fetchArtists(token: token, timeRange: "medium_term", limit: 50, offset: 0)
        let mediumPage2 = try await fetchArtists(token: token, timeRange: "medium_term", limit: 35, offset: 50)
        var merged: [Artist] = []
        var seen = Set<String>()
        for artist in (mediumPage1 + mediumPage2) {
            if seen.insert(artist.id).inserted {
                merged.append(artist)
                if merged.count >= 85 { break }
            }
        }

        // Last 15: fill to 100 with all-time (long_term) artists not already in the list
        let long = try await fetchArtists(token: token, timeRange: "long_term", limit: 50, offset: 0)
        for artist in long where merged.count < 100 {
            if seen.insert(artist.id).inserted {
                merged.append(artist)
            }
        }
        return merged
    }

    private func fetchArtists(token: String, timeRange: String, limit: Int, offset: Int = 0) async throws -> [Artist] {
        var components = URLComponents(string: "https://api.spotify.com/v1/me/top/artists")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "time_range", value: timeRange)
        ]
        guard let url = components.url else { throw SpotifyError.fetchFailed }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SpotifyError.fetchFailed
        }
        let decoded = try JSONDecoder().decode(SpotifyTopArtistsResponse.self, from: data)
        return decoded.items.map { item in
            Artist(
                id:         item.id,
                name:       item.name,
                genres:     item.genres ?? [],
                imageURL:   item.images?.first?.url,
                spotifyID:  item.id,
                popularity: item.popularity,
                source:     .spotify
            )
        }
    }

    func disconnect() {
        accessToken = nil
        isConnected = false
        codeVerifier = ""
        UserDefaults.standard.removeObject(forKey: "spotifyToken")
        UserDefaults.standard.removeObject(forKey: codeVerifierKey)
    }

    // MARK: - PKCE Helpers
    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .prefix(128).description
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Response Models
struct SpotifyTopArtistsResponse: Codable {
    let items: [SpotifyArtist]
}

struct SpotifyArtist: Codable {
    let id: String
    let name: String
    let genres: [String]?
    let images: [SpotifyImage]?
    let popularity: Int?
}
struct SpotifyImage: Codable {
    let url: String; let height: Int?; let width: Int?
}
enum SpotifyError: LocalizedError {
    case notConnected, fetchFailed
    var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to Spotify"
        case .fetchFailed:  return "Failed to fetch artists from Spotify"
        }
    }
}
