import SwiftUI

struct SuggestionsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SuggestionsViewModel()
    /// Single city to generate for. When multiple cities, user picks; when one, use it.
    @State private var selectedCity: City?
    
    var body: some View {
        NavigationView {
            ZStack {
                BHColors.background.ignoresSafeArea()
                
                if appState.favoriteArtists.isEmpty || appState.trackedCities.isEmpty {
                    BHEmptyState(
                        icon: "sparkles",
                        title: "Add Artists & Cities",
                        subtitle: "Add at least one artist and one city to get personalized show suggestions.",
                        actionTitle: nil,
                        action: nil
                    )
                } else {
                    mainContent
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if appState.trackedCities.count > 1, let selected = selectedCity {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            ForEach(appState.trackedCities) { city in
                                Button(action: {
                                    if city.id != selected.id {
                                        selectedCity = city
                                        viewModel.suggestions = []
                                        appState.saveCachedSuggestions([])
                                    }
                                }) {
                                    HStack {
                                        Text("\(city.name), \(city.country)")
                                        if city.id == selected.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selected.name)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundColor(BHColors.accent)
                        }
                    }
                }
            }
            .onAppear {
                if selectedCity == nil {
                    selectedCity = appState.trackedCities.first
                }
                // Restore persisted Discover cache (same pattern as My Shows / Local Music).
                if !appState.cachedSuggestions.isEmpty && viewModel.suggestions.isEmpty {
                    if let cachedId = appState.cachedDiscoverCityId {
                        if appState.trackedCities.count == 1 || selectedCity?.id == cachedId {
                            viewModel.suggestions = appState.cachedSuggestions
                        } else if let cityForCache = appState.trackedCities.first(where: { $0.id == cachedId }) {
                            selectedCity = cityForCache
                            viewModel.suggestions = appState.cachedSuggestions
                        }
                    } else {
                        viewModel.suggestions = appState.cachedSuggestions
                    }
                }
            }
        }
    }
    
    var mainContent: some View {
        Group {
            if let city = selectedCity {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero suggestion button
                    if !viewModel.isLoading && viewModel.suggestions.isEmpty {
                        VStack(spacing: 20) {
                            Spacer().frame(height: 40)
                            
                            ZStack {
                                ForEach(0..<4) { i in
                                    Circle()
                                        .fill(BHColors.gradient)
                                        .frame(width: CGFloat(60 + i * 35), height: CGFloat(60 + i * 35))
                                        .opacity(0.06 - Double(i) * 0.01)
                                }
                                Image(systemName: "sparkles")
                                    .font(.system(size: 48))
                                    .foregroundStyle(BHColors.gradient)
                            }
                            .frame(width: 200, height: 200)
                            
                            VStack(spacing: 8) {
                                Text("Find Your Next Show")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(BHColors.textPrimary)
                                
                                Text("Based on your \(appState.favoriteArtists.count) artists in \(city.name), \(city.country). We'll find shows you'll love.")
                                    .font(.body)
                                    .foregroundColor(BHColors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                            
                            BHButton("Generate Suggestions ✨") {
                                guard appState.canRegenerateDiscover() else { return }
                                Task {
                                    await viewModel.fetchSuggestions(artists: appState.favoriteArtists, cities: [city], apiKey: appState.openAIKey)
                                    if !viewModel.suggestions.isEmpty {
                                        appState.saveCachedSuggestions(viewModel.suggestions, cityId: city.id)
                                        appState.recordDiscoverRegenerate()
                                    }
                                }
                            }
                            .disabled(!appState.canRegenerateDiscover())
                            .opacity(appState.canRegenerateDiscover() ? 1 : 0.6)
                            .padding(.horizontal, 32)
                        }
                    } else if viewModel.isLoading {
                    VStack(spacing: 24) {
                        SpinningLoader()
                            .scaleEffect(1.5)
                        Text("Finding suggestions...")
                            .font(.subheadline)
                            .foregroundColor(BHColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    VStack(spacing: 0) {
                        // Artist tags used for matching
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Based on your taste in:")
                                .font(.caption)
                                .foregroundColor(BHColors.textSecondary)
                                .padding(.horizontal, 16)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(appState.favoriteArtists.prefix(8)) { artist in
                                        Text(artist.name)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 5)
                                            .background(BHColors.accent.opacity(0.15))
                                            .foregroundColor(BHColors.accent)
                                            .cornerRadius(20)
                                    }
                                    if appState.favoriteArtists.count > 8 {
                                        Text("+\(appState.favoriteArtists.count - 8) more")
                                            .font(.caption)
                                            .foregroundColor(BHColors.textSecondary)
                                            .padding(.horizontal, 12)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 12)
                        
                        if let error = viewModel.errorMessage {
                            BHErrorBanner(message: error) { viewModel.errorMessage = nil }
                                .padding(.horizontal, 16)
                        }
                        
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.suggestions) { suggestion in
                                SuggestionCard(suggestion: suggestion)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Regenerate button (max 3/day)
                        VStack(spacing: 6) {
                            Text("\(appState.discoverRegeneratesRemainingToday()) regenerates left today")
                                .font(.caption)
                                .foregroundColor(BHColors.textSecondary)
                            BHButton("Regenerate", icon: "arrow.clockwise", style: .secondary) {
                                guard appState.canRegenerateDiscover() else { return }
                                Task {
                                    await viewModel.fetchSuggestions(artists: appState.favoriteArtists, cities: [city], apiKey: appState.openAIKey)
                                    if !viewModel.suggestions.isEmpty {
                                        appState.saveCachedSuggestions(viewModel.suggestions, cityId: city.id)
                                        appState.recordDiscoverRegenerate()
                                    }
                                }
                            }
                            .disabled(!appState.canRegenerateDiscover())
                            .opacity(appState.canRegenerateDiscover() ? 1 : 0.6)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                }
            }
            }
            } else {
                EmptyView()
            }
        }
    }
}

struct SuggestionCard: View {
    let suggestion: ShowSuggestion
    @State private var isExpanded = false
    
    var body: some View {
        BHCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(BHColors.gradient)
                            .frame(width: 48, height: 48)
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestion.artistName)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(BHColors.textPrimary)
                        
                        Text(suggestion.venueName)
                            .font(.subheadline)
                            .foregroundColor(BHColors.textSecondary)
                        
                        HStack(spacing: 12) {
                            Label(suggestion.city, systemImage: "mappin")
                                .font(.caption)
                                .foregroundColor(BHColors.textSecondary)
                            
                            Label(suggestion.date, systemImage: "calendar")
                                .font(.caption)
                                .foregroundColor(BHColors.accent)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(BHColors.textSecondary)
                    }
                }
                .padding(16)
                
                if isExpanded {
                    Divider().background(BHColors.divider).padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Why recommended
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                Text("Why you'd love this")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(BHColors.textSecondary)
                            }
                            
                            Text(suggestion.whyRecommended)
                                .font(.caption)
                                .foregroundColor(BHColors.textPrimary)
                        }
                        
                        // Similar to
                        if !suggestion.similarTo.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Similar to:")
                                    .font(.caption)
                                    .foregroundColor(BHColors.textSecondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(suggestion.similarTo, id: \.self) { artist in
                                            Text(artist)
                                                .font(.caption2)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(BHColors.accentPurple.opacity(0.2))
                                                .foregroundColor(BHColors.accentPurple)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Ticket link
                        if let ticketURL = suggestion.ticketURL, let url = URL(string: ticketURL) {
                            Link(destination: url) {
                                HStack(spacing: 6) {
                                    Image(systemName: "ticket.fill")
                                    Text("Get Tickets")
                                        .fontWeight(.semibold)
                                }
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(BHColors.gradient)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}

struct SuggestionsLoadingView: View {
    @State private var phase = 0
    let messages = [
        "Analyzing your music taste...",
        "Finding similar artists...",
        "Checking upcoming shows...",
        "Curating your suggestions..."
    ]
    let timer = Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                ForEach(0..<3) { i in
                    let scale: CGFloat = 1.0 + CGFloat(i) * 0.3
                    Circle()
                        .stroke(BHColors.gradient, lineWidth: 1.5)
                        .frame(width: 60, height: 60)
                        .scaleEffect(scale)
                        .opacity(0.3 - Double(i) * 0.08)
                }
                
                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundStyle(BHColors.gradient)
            }
            .frame(width: 120, height: 120)
            
            Text(messages[phase % messages.count])
                .font(.headline)
                .foregroundColor(BHColors.textSecondary)
                .animation(.easeInOut, value: phase)
            
            Spacer()
        }
        .onReceive(timer) { _ in
            phase += 1
        }
    }
}

// MARK: - ViewModel
class SuggestionsViewModel: ObservableObject {
    @Published var suggestions: [ShowSuggestion] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchSuggestions(artists: [Artist], cities: [City], apiKey: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            suggestions = []
        }
        
        do {
            let results = try await OpenAIService.shared.generateShowSuggestions(artists: artists, cities: cities, apiKey: apiKey)
            await MainActor.run {
                suggestions = results
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
