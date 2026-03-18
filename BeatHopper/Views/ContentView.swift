import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if !appState.isOnboarded {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut, value: appState.isOnboarded)
    }
}
