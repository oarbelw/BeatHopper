import Foundation
import CoreLocation

// MARK: - MusicService Enum (used in AppState)
enum MusicService: String, Codable {
    case none, spotify, appleMusic

    var displayName: String {
        switch self {
        case .none:       return "None"
        case .spotify:    return "Spotify"
        case .appleMusic: return "Apple Music"
        }
    }

    var iconName: String {
        switch self {
        case .none:       return "music.note"
        case .spotify:    return "music.quarternote.3"
        case .appleMusic: return "applelogo"
        }
    }
}

// MARK: - Artist
struct Artist: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var genres: [String]
    var imageURL: String?
    var spotifyID: String?
    var appleMusicID: String?
    var popularity: Int?
    var source: ArtistSource

    init(id: String = UUID().uuidString, name: String, genres: [String] = [],
         imageURL: String? = nil, spotifyID: String? = nil, appleMusicID: String? = nil,
         popularity: Int? = nil, source: ArtistSource = .manual) {
        self.id          = id
        self.name        = name
        self.genres      = genres
        self.imageURL    = imageURL
        self.spotifyID   = spotifyID
        self.appleMusicID = appleMusicID
        self.popularity  = popularity
        self.source      = source
    }

    enum ArtistSource: String, Codable {
        case spotify, appleMusic, manual
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Artist, rhs: Artist) -> Bool { lhs.id == rhs.id }
}

// MARK: - City
struct City: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var country: String
    var latitude: Double
    var longitude: Double

    init(id: String = UUID().uuidString, name: String, country: String, latitude: Double, longitude: Double) {
        self.id        = id
        self.name      = name
        self.country   = country
        self.latitude  = latitude
        self.longitude = longitude
    }

    var displayName: String { "\(name), \(country)" }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: City, rhs: City) -> Bool { lhs.id == rhs.id }
}

// MARK: - Concert
struct Concert: Identifiable, Codable {
    var id: String
    var artistName: String
    var venueName: String
    var venueAddress: String
    var city: String
    var country: String
    var date: String           // "YYYY-MM-DD"
    var time: String?          // "8:00 PM"
    var ticketURL: String?
    var latitude: Double?
    var longitude: Double?
    var distance: Double?      // km from tracked city
    var priceRange: String?
    var genre: String?
    var description: String?
    var isSuggestion: Bool

    init(id: String = UUID().uuidString, artistName: String, venueName: String,
         venueAddress: String = "", city: String, country: String = "",
         date: String, time: String? = nil, ticketURL: String? = nil,
         latitude: Double? = nil, longitude: Double? = nil, distance: Double? = nil,
         priceRange: String? = nil, genre: String? = nil, description: String? = nil,
         isSuggestion: Bool = false) {
        self.id          = id
        self.artistName  = artistName
        self.venueName   = venueName
        self.venueAddress = venueAddress
        self.city        = city
        self.country     = country
        self.date        = date
        self.time        = time
        self.ticketURL   = ticketURL
        self.latitude    = latitude
        self.longitude   = longitude
        self.distance    = distance
        self.priceRange  = priceRange
        self.genre       = genre
        self.description = description
        self.isSuggestion = isSuggestion
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var parsedDate: Date? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.date(from: date)
    }
}

// MARK: - LocalVenue
struct LocalVenue: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var genre: String?
    var tonightEvent: String?
    var priceRange: String?
    var coverCharge: String?
    var rating: Double?
    var description: String?

    init(id: String = UUID().uuidString, name: String, address: String,
         latitude: Double, longitude: Double, genre: String? = nil,
         tonightEvent: String? = nil, priceRange: String? = nil,
         coverCharge: String? = nil, rating: Double? = nil, description: String? = nil) {
        self.id           = id
        self.name         = name
        self.address      = address
        self.latitude     = latitude
        self.longitude    = longitude
        self.genre        = genre
        self.tonightEvent = tonightEvent
        self.priceRange   = priceRange
        self.coverCharge  = coverCharge
        self.rating       = rating
        self.description  = description
    }

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

// MARK: - ShowSuggestion
struct ShowSuggestion: Identifiable, Codable {
    var id: String
    var artistName: String
    var venueName: String
    var city: String
    var date: String
    var ticketURL: String?
    var whyRecommended: String
    var similarTo: [String]
    var genre: String?

    init(id: String = UUID().uuidString, artistName: String, venueName: String,
         city: String, date: String, ticketURL: String? = nil,
         whyRecommended: String = "", similarTo: [String] = [], genre: String? = nil) {
        self.id               = id
        self.artistName       = artistName
        self.venueName        = venueName
        self.city             = city
        self.date             = date
        self.ticketURL        = ticketURL
        self.whyRecommended   = whyRecommended
        self.similarTo        = similarTo
        self.genre            = genre
    }
}
