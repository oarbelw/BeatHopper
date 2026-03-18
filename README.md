# 🎵 BeatHopper

**Never miss your favorite artists when they come to your city.**

BeatHopper is a SwiftUI iOS app that tracks your favorite artists and alerts you when they're playing near your selected cities, finds live music near you tonight, and suggests shows based on your taste — all powered by OpenAI GPT-4o.

---

## Features

| Feature | Description |
|---------|-------------|
| 🎤 **Artist Tracking** | Track up to 50 artists. Import from Apple Music or Spotify, or search manually. |
| 📍 **City Tracking** | Select up to 5 cities. Get alerted to shows within 50km of each. |
| 🗺️ **Live Map View** | Concerts shown on an interactive map with list/map toggle. |
| 🎶 **Local Music Tonight** | Finds live music venues near your current location for tonight. |
| ✨ **Show Suggestions** | AI-curated shows you'd love based on your taste. |
| 🔔 **Onboarding** | Smooth 4-screen onboarding with API key setup. |

---

## Setup Instructions

### 1. Open in Xcode
```
open BeatHopper.xcodeproj
```
Requires **Xcode 15+** and **iOS 17.0+** deployment target.

### 2. Set your Team
In Xcode → BeatHopper target → Signing & Capabilities → set your Apple Developer Team.

### 3. Update the Bundle ID
Change `com.yourname.BeatHopper` to your own bundle identifier in:
- `Info.plist`
- Build Settings → Product Bundle Identifier

### 4. Enable Capabilities
In Xcode → BeatHopper target → Signing & Capabilities, add:
- **Media Library** (for Apple Music access)
- **Location When In Use** (already in Info.plist)

### 5. Get an OpenAI API Key
1. Go to [platform.openai.com](https://platform.openai.com)
2. Create an API key (GPT-4o access required)
3. Enter it in the app's onboarding or Settings tab

### 6. (Optional) Spotify Integration
1. Register at [developer.spotify.com](https://developer.spotify.com)
2. Open `Services/SpotifyService.swift`
3. Replace `YOUR_SPOTIFY_CLIENT_ID` with your real Client ID
4. Add URL scheme `beathopper` to Info.plist under `CFBundleURLSchemes`

---

## Project Structure

```
BeatHopper/
├── BeatHopperApp.swift          # App entry point
├── AppState.swift               # Global state (artists, cities, settings)
│
├── Models/
│   └── Models.swift             # Artist, City, Concert, LocalVenue, ShowSuggestion
│
├── Services/
│   ├── OpenAIService.swift      # All GPT-4o API calls (concerts, venues, suggestions, search)
│   ├── LocationService.swift    # CoreLocation wrapper (singleton)
│   ├── AppleMusicService.swift  # MusicKit integration
│   ├── SpotifyService.swift     # Spotify Web API integration
│   └── NotificationService.swift # Push notifications
│
├── Utilities/
│   └── DesignSystem.swift       # BHColors, BHButton, BHCard, BHEmptyState, VenueAnnotation
│
└── Views/
    ├── ContentView.swift         # Root: onboarding gate
    ├── MainTabView.swift         # 5-tab navigation
    ├── SettingsView.swift        # API key, service status, data management
    ├── Onboarding/
    │   └── OnboardingView.swift  # 4-page onboarding + API key entry
    ├── Concerts/
    │   └── ConcertsView.swift    # Tracked artist concerts (list + map)
    ├── Artists/
    │   └── ArtistsView.swift     # Artist management + search + music service import
    ├── Cities/
    │   └── CitiesSelectionView.swift # City management + map
    ├── LocalMusic/
    │   └── LocalMusicView.swift  # Tonight's local venues on map
    └── Suggestions/
        └── SuggestionsView.swift # AI-generated show suggestions
```

---

## Architecture

- **SwiftUI** + **Combine** for reactive UI
- **MVVM** — each major view has its own `ViewModel` class within the same file
- **AppState** (`ObservableObject`) holds all persistent user data (artists, cities, API key)
- **OpenAIService** is a shared singleton; all GPT calls go through it
- All data persisted via `UserDefaults` with `Codable` encoding

---

## OpenAI Usage

BeatHopper makes 3 types of GPT-4o calls:

| Call | Trigger | Output |
|------|---------|--------|
| `findConcertsForArtists` | "My Shows" tab refresh | Array of `Concert` |
| `findLocalMusic` | "Local Music" tab refresh | Array of `LocalVenue` |
| `generateShowSuggestions` | "Discover" tab generate button | Array of `ShowSuggestion` |
| `searchArtists` | Artist search | Array of `Artist` |
| `searchCities` | City search | Array of `City` |

All calls return structured JSON which is parsed client-side.

---

## Design System

The app uses a unified dark theme defined in `DesignSystem.swift`:

| Token | Value |
|-------|-------|
| `BHColors.background` | `#0D0D12` deep dark |
| `BHColors.surfaceElevated` | `#1C1C28` card surface |
| `BHColors.accent` | `#FF4F00` BeatHopper orange |
| `BHColors.accentGreen` | `#32D74B` |
| `BHColors.accentBlue` | `#0A84FF` |
| `BHColors.accentPurple` | `#BF5AF2` |
| `BHColors.gradient` | Orange → Yellow linear gradient |

Shared components: `BHButton`, `BHCard`, `BHEmptyState`, `BHLoadingView`, `BHErrorBanner`, `SpinningLoader`
