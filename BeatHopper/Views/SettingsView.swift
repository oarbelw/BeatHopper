import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAPIKeySheet = false
    @State private var showClearAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                BHColors.background.ignoresSafeArea()

                List {
                    // API Key Section
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("Gemini API Key", systemImage: "key.fill")
                                    .foregroundColor(BHColors.textPrimary)
                                Spacer()
                                if !appState.openAIKey.isEmpty {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(BHColors.accentGreen)
                                }
                            }

                            Button(appState.openAIKey.isEmpty ? "Add API Key" : "Update API Key") {
                                showAPIKeySheet = true
                            }
                            .foregroundColor(BHColors.accent)
                            if !appState.openAIKey.isEmpty {
                                Text("Key: ****\(String(appState.openAIKey.suffix(4)))")
                                    .font(.caption)
                                    .foregroundColor(BHColors.textSecondary)
                            }
                        }
                        .padding(.vertical, 6)
                    } header: {
                        Text("API Configuration").foregroundColor(BHColors.textSecondary)
                    }
                    .listRowBackground(BHColors.surfaceElevated)

                    // Music Service
                    Section {
                        HStack {
                            Label("Connected Service", systemImage: appState.musicServiceConnected.iconName)
                                .foregroundColor(BHColors.textPrimary)
                            Spacer()
                            Text(appState.musicServiceConnected.displayName)
                                .foregroundColor(appState.musicServiceConnected == .none ? BHColors.textSecondary : BHColors.accentGreen)
                        }
                        NavigationLink(destination: ArtistsView()) {
                            Label("Manage Artists (\(appState.favoriteArtists.count))", systemImage: "person.2.fill")
                                .foregroundColor(BHColors.textPrimary)
                        }
                        NavigationLink(destination: CitiesSelectionView()) {
                            Label("Manage Cities (\(appState.trackedCities.count))", systemImage: "globe")
                                .foregroundColor(BHColors.textPrimary)
                        }
                    } header: {
                        Text("Your Setup").foregroundColor(BHColors.textSecondary)
                    }
                    .listRowBackground(BHColors.surfaceElevated)

                    // App Info
                    Section {
                        HStack {
                            Text("Version").foregroundColor(BHColors.textPrimary)
                            Spacer()
                            Text("1.0.0").foregroundColor(BHColors.textSecondary)
                        }
                        HStack {
                            Text("Artists Tracked").foregroundColor(BHColors.textPrimary)
                            Spacer()
                            Text("\(appState.favoriteArtists.count) / 100").foregroundColor(BHColors.textSecondary)
                        }
                        HStack {
                            Text("Cities Tracked").foregroundColor(BHColors.textPrimary)
                            Spacer()
                            Text("\(appState.trackedCities.count) / 5").foregroundColor(BHColors.textSecondary)
                        }
                    } header: {
                        Text("About BeatHopper").foregroundColor(BHColors.textSecondary)
                    }
                    .listRowBackground(BHColors.surfaceElevated)

                    // Danger Zone
                    Section {
                        Button(role: .destructive) { showClearAlert = true } label: {
                            Label("Clear All Data", systemImage: "trash.fill")
                                .foregroundColor(.red)
                        }
                    } header: {
                        Text("Danger Zone").foregroundColor(BHColors.textSecondary)
                    }
                    .listRowBackground(BHColors.surfaceElevated)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showAPIKeySheet) {
                APIKeyEntrySheet(
                    onSave: { key in
                        appState.saveOpenAIKey(key)
                        showAPIKeySheet = false
                    },
                    onCancel: { showAPIKeySheet = false }
                )
            }
            .alert("Clear All Data?", isPresented: $showClearAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    appState.favoriteArtists = []
                    appState.trackedCities   = []
                    appState.musicServiceConnected = .none
                    appState.saveArtists()
                    appState.saveCities()
                    appState.connectMusicService(.none)
                    SpotifyService.shared.disconnect()
                    AppleMusicService.shared.disconnect()
                }
            } message: {
                Text("This will remove all your artists, cities and settings. This cannot be undone.")
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - API Key entry sheet (own state so Save always has the value)
private struct APIKeyEntrySheet: View {
    @State private var keyInput = ""
    let onSave: (String) -> Void
    let onCancel: () -> Void

    private var trimmedKey: String { keyInput.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { trimmedKey.count >= 10 }

    var body: some View {
        NavigationView {
            ZStack {
                BHColors.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Text("Paste your Gemini API key from aistudio.google.com")
                        .font(.subheadline)
                        .foregroundColor(BHColors.textSecondary)
                    TextField("AIza...", text: $keyInput)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(BHColors.textPrimary)
                        .padding(12)
                        .background(BHColors.surfaceElevated)
                        .cornerRadius(10)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .textContentType(.password)
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Gemini API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(BHColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard canSave else { return }
                        onSave(trimmedKey)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(BHColors.accent)
                    .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
