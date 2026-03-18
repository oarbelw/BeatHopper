import SwiftUI
import MapKit

struct ConcertsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ConcertsViewModel()
    @State private var showCityPicker = false
    @State private var viewMode: ViewMode = .list
    
    enum ViewMode { case list, map }
    
    var body: some View {
        NavigationView {
            ZStack {
                BHColors.background.ignoresSafeArea()
                
                if appState.trackedCities.isEmpty || appState.favoriteArtists.isEmpty {
                    emptySetupView
                } else {
                    mainContent
                }
            }
            .navigationTitle("My Shows")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .sheet(isPresented: $viewModel.showDebugSheet) {
                AIDebugSheet()
            }
            .onAppear {
                if !appState.cachedConcerts.isEmpty && viewModel.concerts.isEmpty && !viewModel.isLoading {
                    viewModel.concerts = appState.cachedConcerts
                }
                if appState.shouldAutoRefreshConcerts() && !appState.favoriteArtists.isEmpty && !appState.trackedCities.isEmpty {
                    Task {
                        await viewModel.fetchConcerts(artists: appState.favoriteArtists, cities: appState.trackedCities, apiKey: appState.openAIKey)
                        appState.saveCachedConcerts(viewModel.concerts)
                    }
                }
            }
        }
    }
    
    var mainContent: some View {
        VStack(spacing: 0) {
            // City chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(appState.trackedCities) { city in
                        CityChip(city: city, isSelected: viewModel.selectedCity?.id == city.id) {
                            viewModel.selectedCity = viewModel.selectedCity?.id == city.id ? nil : city
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
            
            // View mode toggle
            Picker("View", selection: $viewMode) {
                Image(systemName: "list.bullet").tag(ViewMode.list)
                Image(systemName: "map").tag(ViewMode.map)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            if viewModel.isLoading {
                LoadingConcertsView(status: viewModel.loadingStatus)
            } else if let error = viewModel.errorMessage {
                ScrollView {
                    VStack(spacing: 16) {
                        BHErrorBanner(message: error) { viewModel.errorMessage = nil }
                            .padding(.horizontal, 16)
                        BHButton("Check Again", icon: "arrow.clockwise", style: .secondary) {
                            Task {
                                await viewModel.fetchConcerts(artists: appState.favoriteArtists, cities: appState.trackedCities, apiKey: appState.openAIKey)
                                appState.saveCachedConcerts(viewModel.concerts)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 16)
                }
            } else if viewModel.filteredConcerts.isEmpty {
                BHEmptyState(
                    icon: "music.mic.circle",
                    title: "No Shows Loaded",
                    subtitle: "Tap Check to search for upcoming concerts for your artists near your cities.",
                    actionTitle: "Check",
                    action: {
                        Task {
                            await viewModel.fetchConcerts(artists: appState.favoriteArtists, cities: appState.trackedCities, apiKey: appState.openAIKey)
                            appState.saveCachedConcerts(viewModel.concerts)
                        }
                    }
                )
            } else {
                switch viewMode {
                case .list: concertListView
                case .map: concertMapView
                }
            }
        }
    }
    
    var concertListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredConcerts) { concert in
                    ConcertCard(concert: concert)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
    
    var concertMapView: some View {
        ConcertsMapView(concerts: viewModel.filteredConcerts, cities: appState.trackedCities)
    }
    
    var emptySetupView: some View {
        VStack(spacing: 24) {
            Image(systemName: "music.mic.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(BHColors.gradient)
            
            Text("Set up BeatHopper")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(BHColors.textPrimary)
            
            VStack(spacing: 12) {
                SetupStep(number: 1, title: "Add your artists", isComplete: !appState.favoriteArtists.isEmpty, destination: AnyView(ArtistsView()))
                SetupStep(number: 2, title: "Select cities to track", isComplete: !appState.trackedCities.isEmpty, destination: AnyView(CitiesSelectionView()))
            }
            .padding(.horizontal, 24)
        }
    }
    
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if appState.concertsLastRefreshedAt != nil, let next = appState.concertsNextRefreshAt {
                Text(nextRefreshLabel(next))
                    .font(.caption)
                    .foregroundColor(BHColors.textSecondary)
            } else {
                Button(action: {
                    Task {
                        await viewModel.fetchConcerts(artists: appState.favoriteArtists, cities: appState.trackedCities, apiKey: appState.openAIKey)
                        appState.saveCachedConcerts(viewModel.concerts)
                    }
                }) {
                    Text("Check")
                        .fontWeight(.semibold)
                        .foregroundColor(BHColors.accent)
                }
                .disabled(viewModel.isLoading)
                Button(action: { viewModel.showDebugSheet = true }) {
                    Image(systemName: "ladybug.fill")
                        .font(.caption)
                        .foregroundColor(BHColors.textSecondary)
                }
            }
        }
    }

    private func nextRefreshLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, h:mm a"
        return "Next refresh: \(f.string(from: date))"
    }
}

struct CityChip: View {
    let city: City
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption)
                Text(city.name)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? BHColors.accent : BHColors.surfaceElevated)
            .foregroundColor(isSelected ? .white : BHColors.textSecondary)
            .cornerRadius(20)
        }
    }
}

struct ConcertCard: View {
    let concert: Concert
    @State private var isExpanded = false
    
    var body: some View {
        BHCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    // Date block
                    VStack(spacing: 2) {
                        Text(monthString)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(BHColors.accent)
                            .textCase(.uppercase)
                        Text(dayString)
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundColor(BHColors.textPrimary)
                    }
                    .frame(width: 48, height: 56)
                    .background(BHColors.accent.opacity(0.12))
                    .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(concert.artistName)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(BHColors.textPrimary)
                        
                        Text(concert.venueName)
                            .font(.subheadline)
                            .foregroundColor(BHColors.textSecondary)
                        
                        HStack(spacing: 12) {
                            Label(concert.city, systemImage: "mappin")
                                .font(.caption)
                                .foregroundColor(BHColors.textSecondary)
                            
                            if let distance = concert.distance {
                                Label("\(Int(distance)) km", systemImage: "location.circle")
                                    .font(.caption)
                                    .foregroundColor(BHColors.accentBlue)
                            }
                            
                            if let time = concert.time {
                                Label(time, systemImage: "clock")
                                    .font(.caption)
                                    .foregroundColor(BHColors.textSecondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(BHColors.textSecondary)
                    }
                }
                .padding(16)
                
                if isExpanded {
                    Divider()
                        .background(BHColors.divider)
                        .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        if let desc = concert.description {
                            Text(desc)
                                .font(.caption)
                                .foregroundColor(BHColors.textSecondary)
                        }
                        
                        Text(concert.venueAddress)
                            .font(.caption)
                            .foregroundColor(BHColors.textSecondary)
                        
                        if let ticketURL = concert.ticketURL, let url = URL(string: ticketURL) {
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
                    .padding(.top, -4)
                }
            }
        }
    }
    
    var monthString: String {
        let parts = concert.date.split(separator: "-")
        guard parts.count >= 2, let month = Int(parts[1]) else { return "" }
        let months = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
        return months[safe: month - 1] ?? ""
    }
    
    var dayString: String {
        let parts = concert.date.split(separator: "-")
        guard parts.count >= 3 else { return "--" }
        return String(parts[2])
    }
}

struct ConcertsMapView: View {
    let concerts: [Concert]
    let cities: [City]
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 43.65, longitude: -79.38),
        span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
    )
    @State private var selectedConcert: Concert?
    
    var annotations: [VenueAnnotation] {
        var anns: [VenueAnnotation] = []
        for concert in concerts {
            if let coord = concert.coordinate {
                anns.append(VenueAnnotation(id: concert.id, coordinate: coord, title: concert.artistName, subtitle: concert.venueName, type: .concert))
            }
        }
        for city in cities {
            anns.append(VenueAnnotation(id: "city_\(city.id)", coordinate: city.coordinate, title: city.name, subtitle: "Tracked City", type: .city))
        }
        return anns
    }
    
    var body: some View {
        Map(position: .constant(.region(region))) {
            ForEach(annotations) { item in
                Annotation(item.title, coordinate: item.coordinate) {
                    ConcertMapPin(annotation: item, isSelected: selectedConcert?.id == item.id) {
                        DispatchQueue.main.async { selectedConcert = concerts.first { $0.id == item.id } }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear { Task { @MainActor in fitMapToAnnotations() } }
        .overlay(alignment: .bottom) {
            if let concert = selectedConcert {
                ConcertMapCard(concert: concert) { selectedConcert = nil }
                    .transition(.move(edge: .bottom))
                    .animation(.spring(), value: selectedConcert != nil)
            }
        }
    }
    
    func fitMapToAnnotations() {
        guard !concerts.isEmpty else { return }
        let coords = concerts.compactMap { $0.coordinate }
        guard !coords.isEmpty else { return }
        let minLat = coords.map { $0.latitude }.min()!
        let maxLat = coords.map { $0.latitude }.max()!
        let minLon = coords.map { $0.longitude }.min()!
        let maxLon = coords.map { $0.longitude }.max()!
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: max(abs(maxLat - minLat) * 1.4, 1.0), longitudeDelta: max(abs(maxLon - minLon) * 1.4, 1.0))
        )
    }
}

struct ConcertMapPin: View {
    let annotation: VenueAnnotation
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(annotation.type == .city ? BHColors.accentBlue : BHColors.accent)
                        .frame(width: isSelected ? 44 : 32, height: isSelected ? 44 : 32)
                    
                    Image(systemName: annotation.type == .city ? "mappin.circle.fill" : "music.mic")
                        .font(isSelected ? .headline : .subheadline)
                        .foregroundColor(.white)
                }
                
                if isSelected {
                    Text(annotation.title)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(BHColors.accent)
                        .cornerRadius(4)
                }
            }
            .animation(.spring(), value: isSelected)
        }
    }
}

struct ConcertMapCard: View {
    let concert: Concert
    let onDismiss: () -> Void
    
    var body: some View {
        BHCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(concert.artistName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(BHColors.textPrimary)
                    Text(concert.venueName)
                        .font(.subheadline)
                        .foregroundColor(BHColors.textSecondary)
                    Text(concert.date)
                        .font(.caption)
                        .foregroundColor(BHColors.accent)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(BHColors.textSecondary)
                    }
                    
                    if let ticketURL = concert.ticketURL, let url = URL(string: ticketURL) {
                        Link(destination: url) {
                            Text("Tickets")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(BHColors.gradient)
                                .cornerRadius(6)
                        }
                    }
                }
            }
            .padding(16)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }
}

struct LoadingConcertsView: View {
    var status: String? = nil
    @State private var dots = ""
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(BHColors.gradient, lineWidth: 2)
                        .frame(width: CGFloat(60 + i * 30), height: CGFloat(60 + i * 30))
                        .opacity(0.3 - Double(i) * 0.08)
                        .scaleEffect(1.0)
                }
                
                Image(systemName: "music.mic")
                    .font(.system(size: 32))
                    .foregroundStyle(BHColors.gradient)
            }
            .frame(width: 120, height: 120)
            
            VStack(spacing: 8) {
                Text(status ?? "Searching for shows\(dots)")
                    .font(.headline)
                    .foregroundColor(BHColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Checking your artists across all tracked cities...")
                    .font(.caption)
                    .foregroundColor(BHColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .onReceive(timer) { _ in
            DispatchQueue.main.async {
                if status == nil { dots = dots.count >= 3 ? "" : dots + "." }
            }
        }
    }
}

struct SetupStep: View {
    let number: Int
    let title: String
    let isComplete: Bool
    let destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isComplete ? BHColors.accentGreen : BHColors.surfaceElevated)
                        .frame(width: 36, height: 36)
                    
                    if isComplete {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    } else {
                        Text("\(number)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(BHColors.textSecondary)
                    }
                }
                
                Text(title)
                    .fontWeight(.medium)
                    .foregroundColor(BHColors.textPrimary)
                
                Spacer()
                
                Image(systemName: isComplete ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundColor(isComplete ? BHColors.accentGreen : BHColors.textSecondary)
            }
            .padding(16)
            .background(BHColors.surfaceElevated)
            .cornerRadius(12)
        }
    }
}

// MARK: - ViewModel
class ConcertsViewModel: ObservableObject {
    @Published var concerts: [Concert] = []
    @Published var isLoading = false
    @Published var loadingStatus: String? = nil
    @Published var errorMessage: String?
    @Published var selectedCity: City?
    @Published var showDebugSheet = false
    
    var filteredConcerts: [Concert] {
        guard let city = selectedCity else { return concerts }
        return concerts.filter { $0.city.localizedCaseInsensitiveContains(city.name) }
    }
    
    func fetchConcerts(artists: [Artist], cities: [City], apiKey: String) async {
        guard !artists.isEmpty, !cities.isEmpty else {
            await MainActor.run { isLoading = false; loadingStatus = nil }
            return
        }
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            loadingStatus = "Checking for shows..."
            concerts = []
        }
        
        let batchSize = 5
        let batches = stride(from: 0, to: artists.count, by: batchSize).map {
            Array(artists[$0..<min($0 + batchSize, artists.count)])
        }
        var allConcerts: [Concert] = []
        var seen = Set<String>()
        
        for (index, batch) in batches.enumerated() {
            let artistsSoFar = min((index + 1) * batchSize, artists.count)
            let currentCount = allConcerts.count
            await MainActor.run {
                if currentCount > 0 {
                    loadingStatus = "Found \(currentCount) show\(currentCount == 1 ? "" : "s"). Checking... (\(artistsSoFar)/\(artists.count))"
                } else {
                    loadingStatus = "Checking... (\(artistsSoFar)/\(artists.count) artists)"
                }
            }
            
            do {
                let batchConcerts = try await OpenAIService.shared.findConcertsForArtistsBatch(artists: batch, cities: cities, apiKey: apiKey)
                for concert in batchConcerts {
                    let key = "\(concert.artistName.lowercased())|\(concert.date)|\(concert.venueName.lowercased())"
                    if seen.insert(key).inserted {
                        allConcerts.append(concert)
                    }
                }
                let sorted = allConcerts.sorted { $0.date < $1.date }
                await MainActor.run {
                    concerts = sorted
                }
            } catch {
                // Continue with next batch
            }
        }
        
        let finalList = allConcerts.sorted { $0.date < $1.date }
        await MainActor.run {
            concerts = finalList
            isLoading = false
            loadingStatus = nil
            if !finalList.isEmpty {
                NotificationService.shared.sendConcertsFoundNotification(count: finalList.count)
            }
        }
    }
}

// Safe array subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
