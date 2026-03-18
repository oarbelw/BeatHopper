import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ArtistsViewModel()
    @State private var showSearch = false
    @State private var showMusicServiceSheet = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                BHColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Connect music service banner
                    if appState.musicServiceConnected == .none {
                        ConnectMusicServiceBanner {
                            showMusicServiceSheet = true
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    
                    // Count indicator
                    HStack {
                        Text("\(appState.favoriteArtists.count)/100 artists")
                            .font(.caption)
                            .foregroundColor(BHColors.textSecondary)
                        Spacer()
                        if appState.musicServiceConnected != .none {
                            Label(appState.musicServiceConnected.displayName, systemImage: appState.musicServiceConnected.iconName)
                                .font(.caption)
                                .foregroundColor(BHColors.accentGreen)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    
                    if appState.favoriteArtists.isEmpty {
                        BHEmptyState(
                            icon: "person.2.fill",
                            title: "No Artists Yet",
                            subtitle: "Connect Spotify/Apple Music or add artists by name to track.",
                            actionTitle: "Add Artists",
                            action: { showSearch = true }
                        )
                    } else {
                        artistsList
                    }
                }
            }
            .navigationTitle("My Artists")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSearch = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(BHColors.gradient)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if appState.musicServiceConnected != .none {
                        Button(action: { showMusicServiceSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                                Text("Sync")
                                    .font(.caption)
                            }
                            .foregroundColor(BHColors.accentGreen)
                        }
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                ArtistSearchView()
            }
            .sheet(isPresented: $showMusicServiceSheet) {
                MusicServiceSheet(viewModel: viewModel)
            }
        }
    }
    
    var artistsList: some View {
        List {
            ForEach(appState.favoriteArtists) { artist in
                ArtistRow(artist: artist)
                    .listRowBackground(BHColors.surfaceElevated)
                    .listRowSeparatorTint(BHColors.divider)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation { appState.removeArtist(artist) }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    appState.removeArtist(appState.favoriteArtists[index])
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

struct ArtistRow: View {
    let artist: Artist
    
    var body: some View {
        HStack(spacing: 12) {
            ArtistThumbnail(artist: artist)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(artist.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(BHColors.textPrimary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

/// Shows Spotify/Apple Music artist image when available; otherwise the letter-in-circle placeholder.
struct ArtistThumbnail: View {
    let artist: Artist
    
    var body: some View {
        ZStack {
            Circle()
                .fill(BHColors.gradient)
                .frame(width: 44, height: 44)
            
            Text(String(artist.name.prefix(1)))
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .overlay {
            if let urlString = artist.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        Color.clear
                    @unknown default:
                        Color.clear
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            }
        }
        .frame(width: 44, height: 44)
    }
}

struct ArtistSearchView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var manualName = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                BHColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    addByNameSection
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 48))
                            .foregroundColor(BHColors.textSecondary)
                        Text("Enter an artist name above to add them to your list.")
                            .font(.subheadline)
                            .foregroundColor(BHColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Add Artists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(BHColors.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    var addByNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Artist name")
                .font(.caption)
                .foregroundColor(BHColors.textSecondary)
                .padding(.horizontal, 16)
            HStack(spacing: 8) {
                TextField("Artist name", text: $manualName)
                    .foregroundColor(BHColors.textPrimary)
                    .autocapitalization(.words)
                    .padding(12)
                    .background(BHColors.surfaceElevated)
                    .cornerRadius(10)
                Button(action: addManualArtist) {
                    Text("Add")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(manualName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? BHColors.textSecondary : BHColors.accent)
                        .cornerRadius(10)
                }
                .disabled(manualName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.favoriteArtists.count >= 100)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .padding(.top, 8)
    }
    
    private func addManualArtist() {
        let name = manualName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, appState.favoriteArtists.count < 100 else { return }
        let artist = Artist(id: UUID().uuidString, name: name, genres: [], popularity: nil, source: .manual)
        appState.addArtist(artist)
        manualName = ""
    }
}

struct ConnectMusicServiceBanner: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "music.note.list")
                    .foregroundStyle(BHColors.gradient)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import from Spotify or Apple Music")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(BHColors.textPrimary)
                    Text("Auto-import your top 100 artists")
                        .font(.caption2)
                        .foregroundColor(BHColors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(BHColors.textSecondary)
            }
            .padding(12)
            .background(BHColors.surfaceElevated)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(BHColors.divider, lineWidth: 1))
        }
    }
}

struct MusicServiceSheet: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: ArtistsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isImporting = false
    @State private var importError: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                BHColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Connect a Music Service")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(BHColors.textPrimary)
                            .padding(.top, 20)
                        
                        Text("Import your top 100 artists from the past year to automatically track upcoming shows.")
                            .font(.body)
                            .foregroundColor(BHColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        if let error = importError {
                            BHErrorBanner(message: error) { importError = nil }
                                .padding(.horizontal, 16)
                        }
                        
                        // Spotify
                        ServiceButton(
                            name: "Spotify",
                            icon: "music.note.list",
                            color: Color(hex: "#1DB954"),
                            isConnected: appState.musicServiceConnected == .spotify,
                            isLoading: isImporting
                        ) {
                            Task { await connectSpotify() }
                        }
                        
                        // Apple Music
                        ServiceButton(
                            name: "Apple Music",
                            icon: "applelogo",
                            color: .pink,
                            isConnected: appState.musicServiceConnected == .appleMusic,
                            isLoading: isImporting
                        ) {
                            Task { await connectAppleMusic() }
                        }
                        
                        if appState.musicServiceConnected != .none {
                            Button(action: { disconnectService() }) {
                                Text("Disconnect \(appState.musicServiceConnected.displayName)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .padding(.top, 8)
                        }
                        
                        Divider().background(BHColors.divider).padding(.horizontal, 32)
                        
                        Text("You can also add artists by name in the Artists tab.")
                            .font(.caption)
                            .foregroundColor(BHColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(BHColors.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    func connectSpotify() async {
        guard let authURL = SpotifyService.shared.buildAuthURL() else {
            importError = "Spotify is not configured. Open SpotifyService.swift and replace YOUR_SPOTIFY_CLIENT_ID with your real Client ID from developer.spotify.com."
            return
        }
        // Open Spotify login in Safari
        await UIApplication.shared.open(authURL)
        // After the user authenticates, the app receives a callback via the
        // beathopper:// URL scheme. The token is parsed in BeatHopperApp.swift.
        // We dismiss here — the artist import happens via onOpenURL.
        dismiss()
    }
    
    func connectAppleMusic() async {
        isImporting = true
        do {
            await AppleMusicService.shared.requestAuthorization()
            if AppleMusicService.shared.isConnected {
                let artists = try await AppleMusicService.shared.fetchTopArtists()
                for artist in artists {
                    appState.addArtist(artist)
                }
                appState.connectMusicService(.appleMusic)
                dismiss()
            } else {
                importError = "Apple Music access was denied. Please allow access in Settings."
            }
        } catch {
            importError = error.localizedDescription
        }
        isImporting = false
    }
    
    func disconnectService() {
        switch appState.musicServiceConnected {
        case .spotify: SpotifyService.shared.disconnect()
        case .appleMusic: AppleMusicService.shared.disconnect()
        case .none: break
        }
        appState.connectMusicService(.none)
    }
}

struct ServiceButton: View {
    let name: String
    let icon: String
    let color: Color
    let isConnected: Bool
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.2))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .fontWeight(.semibold)
                        .foregroundColor(BHColors.textPrimary)
                    Text(isConnected ? "Connected ✓" : "Tap to connect")
                        .font(.caption)
                        .foregroundColor(isConnected ? BHColors.accentGreen : BHColors.textSecondary)
                }
                
                Spacer()
                
                if isLoading {
                    SpinningLoader()
                } else if isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(BHColors.accentGreen)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(BHColors.textSecondary)
                }
            }
            .padding(16)
            .background(BHColors.surfaceElevated)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isConnected ? color.opacity(0.4) : BHColors.divider, lineWidth: 1))
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - ViewModels
class ArtistsViewModel: ObservableObject {
    @Published var isImporting = false
    @Published var importError: String?
}

