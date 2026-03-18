import SwiftUI

@main
struct BeatHopperApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    handleSpotifyCallback(url: url)
                }
        }
    }

    private func handleSpotifyCallback(url: URL) {
        guard url.scheme == "beathopper" else { return }
        Task {
            await SpotifyService.shared.handleCallback(url: url)

            guard SpotifyService.shared.isConnected else { return }
            do {
                let artists = try await SpotifyService.shared.fetchTopArtists()
                await MainActor.run {
                    for artist in artists {
                        appState.addArtist(artist)
                    }
                    appState.connectMusicService(.spotify)
                }
            } catch {
                print("Spotify import error: \(error)")
            }
        }
    }
}
