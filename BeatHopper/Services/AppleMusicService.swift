import Foundation
import MusicKit

class AppleMusicService: ObservableObject {
    static let shared = AppleMusicService()
    
    @Published var isConnected = false
    @Published var authorizationStatus: MusicAuthorization.Status = .notDetermined
    
    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        await MainActor.run {
            authorizationStatus = status
            isConnected = (status == .authorized)
        }
    }
    
    func fetchTopArtists() async throws -> [Artist] {
        guard isConnected else { throw AppleMusicError.notConnected }

        var request = MusicRecentlyPlayedRequest<MusicKit.Track>()
        request.limit = 100
        let response = try await request.response()

        var seen = Set<String>()
        var artists: [Artist] = []

        for track in response.items {
            let artistName = track.artistName
            guard !seen.contains(artistName), artists.count < 100 else { continue }
            seen.insert(artistName)
            artists.append(Artist(
                id: "am_\(artistName.lowercased().replacingOccurrences(of: " ", with: "_"))",
                name: artistName,
                genres: [],
                imageURL: track.artwork?.url(width: 300, height: 300)?.absoluteString,
                source: .appleMusic
            ))
        }
        return artists
    }
    
    func disconnect() {
        isConnected = false
        UserDefaults.standard.removeObject(forKey: "appleMusicConnected")
    }
}

enum AppleMusicError: LocalizedError {
    case notConnected, fetchFailed, notAuthorized
    
    var errorDescription: String? {
        switch self {
        case .notConnected:  return "Not connected to Apple Music"
        case .fetchFailed:   return "Failed to fetch artists from Apple Music"
        case .notAuthorized: return "Apple Music access not authorized"
        }
    }
}
