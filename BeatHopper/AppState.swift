import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var isOnboarded: Bool = UserDefaults.standard.bool(forKey: "isOnboarded")
    @Published var openAIKey: String = ""
    @Published var selectedTab: Int = 0

    @Published var favoriteArtists: [Artist] = []
    @Published var trackedCities: [City] = []
    @Published var musicServiceConnected: MusicService = .none

    // My Shows: cache + 5-day auto refresh
    @Published var cachedConcerts: [Concert] = []
    @Published var concertsLastRefreshedAt: Date?

    // Discover: cache + 3 regenerates/day (persisted like My Shows / Local Music)
    @Published var cachedSuggestions: [ShowSuggestion] = []
    /// City id for which cachedSuggestions were generated; nil if cache is empty or cleared.
    private(set) var cachedDiscoverCityId: String?
    private let cachedDiscoverCityIdKey: String = "cachedDiscoverCityId"
    private(set) var discoverRegeneratesToday: Int = 0
    private var discoverRegenerateDayKey: String { "discoverRegenerateDay" }
    private var discoverRegenerateCountKey: String { "discoverRegenerateCount" }

    // Local Music Tonight: 5 generates/day, cached
    @Published var cachedLocalMusicVenues: [LocalVenue] = []
    private var localMusicRefreshDayKey: String { "localMusicRefreshDay" }
    private var localMusicRefreshCountKey: String { "localMusicRefreshCount" }
    private let localMusicCacheKey: String = "cachedLocalMusicVenues"

    init() {
        openAIKey = KeychainHelper.loadAPIKey()
            ?? UserDefaults.standard.string(forKey: "openAIKey")
            ?? ""
        if !openAIKey.isEmpty {
            _ = KeychainHelper.saveAPIKey(openAIKey)
        }
        loadArtists()
        loadCities()
        loadMusicService()
        loadCachedConcerts()
        loadCachedSuggestions()
        loadCachedLocalMusicVenues()
    }

    /// Day boundary at 3am: generate tokens reset every day at 3am (Local Music + Discover).
    private func dayStringFor3AMReset(_ date: Date = Date()) -> String {
        let calendar = Calendar.current
        guard let shifted = calendar.date(byAdding: .hour, value: -3, to: date) else {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = TimeZone.current
            return f.string(from: date)
        }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = TimeZone.current
        return f.string(from: shifted)
    }

    private func loadCachedConcerts() {
        if let data = UserDefaults.standard.data(forKey: "cachedConcerts"),
           let list = try? JSONDecoder().decode([Concert].self, from: data) {
            cachedConcerts = list
        }
        concertsLastRefreshedAt = UserDefaults.standard.object(forKey: "concertsLastRefreshedAt") as? Date
    }

    func saveCachedConcerts(_ list: [Concert]) {
        cachedConcerts = list
        concertsLastRefreshedAt = Date()
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: "cachedConcerts")
        }
        UserDefaults.standard.set(concertsLastRefreshedAt, forKey: "concertsLastRefreshedAt")
    }

    /// Next automatic refresh is 5 days after last refresh.
    var concertsNextRefreshAt: Date? {
        guard let last = concertsLastRefreshedAt else { return nil }
        return Calendar.current.date(byAdding: .day, value: 5, to: last)
    }

    func shouldAutoRefreshConcerts() -> Bool {
        guard let next = concertsNextRefreshAt else { return false }
        return Date() >= next
    }

    private func loadCachedSuggestions() {
        if let data = UserDefaults.standard.data(forKey: "cachedSuggestions"),
           let list = try? JSONDecoder().decode([ShowSuggestion].self, from: data) {
            cachedSuggestions = list
        }
        cachedDiscoverCityId = UserDefaults.standard.string(forKey: cachedDiscoverCityIdKey)
        updateDiscoverRegenerateCountIfNewDay()
    }

    /// Saves Discover results so they persist like My Shows and Local Music. Pass cityId when saving results for a city.
    func saveCachedSuggestions(_ list: [ShowSuggestion], cityId: String? = nil) {
        cachedSuggestions = list
        cachedDiscoverCityId = list.isEmpty ? nil : cityId
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: "cachedSuggestions")
        }
        if let id = cachedDiscoverCityId {
            UserDefaults.standard.set(id, forKey: cachedDiscoverCityIdKey)
        } else {
            UserDefaults.standard.removeObject(forKey: cachedDiscoverCityIdKey)
        }
    }

    private func updateDiscoverRegenerateCountIfNewDay() {
        let today = dayStringFor3AMReset()
        let storedDay = UserDefaults.standard.string(forKey: discoverRegenerateDayKey)
        if storedDay != today {
            UserDefaults.standard.set(today, forKey: discoverRegenerateDayKey)
            UserDefaults.standard.set(0, forKey: discoverRegenerateCountKey)
            discoverRegeneratesToday = 0
        } else {
            discoverRegeneratesToday = UserDefaults.standard.integer(forKey: discoverRegenerateCountKey)
        }
    }

    func canRegenerateDiscover() -> Bool {
        updateDiscoverRegenerateCountIfNewDay()
        return discoverRegeneratesToday < 3
    }

    func recordDiscoverRegenerate() {
        updateDiscoverRegenerateCountIfNewDay()
        discoverRegeneratesToday += 1
        let today = dayStringFor3AMReset()
        UserDefaults.standard.set(today, forKey: discoverRegenerateDayKey)
        UserDefaults.standard.set(discoverRegeneratesToday, forKey: discoverRegenerateCountKey)
    }

    func discoverRegeneratesRemainingToday() -> Int {
        updateDiscoverRegenerateCountIfNewDay()
        return max(0, 3 - discoverRegeneratesToday)
    }

    private func loadCachedLocalMusicVenues() {
        if let data = UserDefaults.standard.data(forKey: localMusicCacheKey),
           let list = try? JSONDecoder().decode([LocalVenue].self, from: data) {
            cachedLocalMusicVenues = list
        }
    }

    func saveCachedLocalMusicVenues(_ list: [LocalVenue]) {
        cachedLocalMusicVenues = list
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: localMusicCacheKey)
        }
    }

    func clearCachedLocalMusicVenues() {
        cachedLocalMusicVenues = []
        UserDefaults.standard.removeObject(forKey: localMusicCacheKey)
    }

    /// True if user has not used any Local Music generate today (5 left).
    func hasAllLocalMusicGeneratesLeftToday() -> Bool {
        localMusicRefreshesRemainingToday() == 5
    }

    func canRefreshLocalMusic() -> Bool {
        let today = dayStringFor3AMReset()
        let storedDay = UserDefaults.standard.string(forKey: localMusicRefreshDayKey)
        if storedDay != today {
            return true
        }
        return UserDefaults.standard.integer(forKey: localMusicRefreshCountKey) < 5
    }

    func localMusicRefreshesRemainingToday() -> Int {
        let today = dayStringFor3AMReset()
        let storedDay = UserDefaults.standard.string(forKey: localMusicRefreshDayKey)
        if storedDay != today { return 5 }
        return max(0, 5 - UserDefaults.standard.integer(forKey: localMusicRefreshCountKey))
    }

    func recordLocalMusicRefresh() {
        let today = dayStringFor3AMReset()
        let storedDay = UserDefaults.standard.string(forKey: localMusicRefreshDayKey)
        let count: Int
        if storedDay != today {
            count = 1
            UserDefaults.standard.set(today, forKey: localMusicRefreshDayKey)
        } else {
            count = UserDefaults.standard.integer(forKey: localMusicRefreshCountKey) + 1
        }
        UserDefaults.standard.set(count, forKey: localMusicRefreshCountKey)
    }

    func saveOnboarding() {
        UserDefaults.standard.set(true, forKey: "isOnboarded")
        if !openAIKey.isEmpty { _ = KeychainHelper.saveAPIKey(openAIKey) }
        isOnboarded = true
    }

    func saveOpenAIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        _ = KeychainHelper.saveAPIKey(trimmed)
        if Thread.isMainThread {
            openAIKey = trimmed
            objectWillChange.send()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.openAIKey = trimmed
                self?.objectWillChange.send()
            }
        }
    }
    
    func loadArtists() {
        if let data = UserDefaults.standard.data(forKey: "favoriteArtists"),
           let artists = try? JSONDecoder().decode([Artist].self, from: data) {
            favoriteArtists = artists
        }
    }
    
    func saveArtists() {
        if let data = try? JSONEncoder().encode(favoriteArtists) {
            UserDefaults.standard.set(data, forKey: "favoriteArtists")
        }
    }
    
    func addArtist(_ artist: Artist) {
        guard favoriteArtists.count < 100,
              !favoriteArtists.contains(where: { $0.id == artist.id }) else { return }
        favoriteArtists.append(artist)
        saveArtists()
    }
    
    func removeArtist(_ artist: Artist) {
        favoriteArtists.removeAll { $0.id == artist.id }
        saveArtists()
    }
    
    func loadCities() {
        if let data = UserDefaults.standard.data(forKey: "trackedCities"),
           let cities = try? JSONDecoder().decode([City].self, from: data) {
            trackedCities = cities
        }
    }
    
    func saveCities() {
        if let data = try? JSONEncoder().encode(trackedCities) {
            UserDefaults.standard.set(data, forKey: "trackedCities")
        }
    }
    
    func addCity(_ city: City) {
        guard trackedCities.count < 5,
              !trackedCities.contains(where: { $0.id == city.id }) else { return }
        trackedCities.append(city)
        saveCities()
    }
    
    func removeCity(_ city: City) {
        trackedCities.removeAll { $0.id == city.id }
        saveCities()
    }
    
    func loadMusicService() {
        if let raw = UserDefaults.standard.string(forKey: "musicService"),
           let service = MusicService(rawValue: raw) {
            musicServiceConnected = service
        }
    }
    
    func connectMusicService(_ service: MusicService) {
        musicServiceConnected = service
        UserDefaults.standard.set(service.rawValue, forKey: "musicService")
    }
}
