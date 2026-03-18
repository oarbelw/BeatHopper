import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ConcertsView()
                .tabItem {
                    Label("My Shows", systemImage: "music.mic")
                }
                .tag(0)
            
            LocalMusicView()
                .tabItem {
                    Label("Local Music", systemImage: "map.fill")
                }
                .tag(1)
            
            SuggestionsView()
                .tabItem {
                    Label("Discover", systemImage: "sparkles")
                }
                .tag(2)
            
            ArtistsView()
                .tabItem {
                    Label("Artists", systemImage: "person.2.fill")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .accentColor(BHColors.accent)
        .preferredColorScheme(.dark)
    }
}
