import SwiftUI
import MapKit

struct LocalMusicView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = LocalMusicViewModel()
    @StateObject private var locationService = LocationService.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                BHColors.background.ignoresSafeArea()
                
                switch locationService.authorizationStatus {
                case .notDetermined:
                    RequestLocationView {
                        locationService.requestPermission()
                    }
                case .denied, .restricted:
                    LocationDeniedView()
                case .authorizedWhenInUse, .authorizedAlways:
                    if viewModel.isLoading {
                        BHLoadingView(message: "Finding live music near you tonight...")
                    } else {
                        mainContent
                    }
                @unknown default:
                    RequestLocationView {
                        locationService.requestPermission()
                    }
                }
            }
            .navigationTitle("Local Music Tonight")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        Text("\(appState.localMusicRefreshesRemainingToday()) generates left today")
                            .font(.caption)
                            .foregroundColor(BHColors.textSecondary)
                        Button(action: {
                            guard appState.canRefreshLocalMusic() else { return }
                            Task {
                                await viewModel.refresh(location: locationService.currentLocation, apiKey: appState.openAIKey)
                                appState.recordLocalMusicRefresh()
                                appState.saveCachedLocalMusicVenues(viewModel.venues)
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(appState.canRefreshLocalMusic() ? BHColors.accent : BHColors.textSecondary)
                        }
                        .disabled(viewModel.isLoading || !appState.canRefreshLocalMusic())
                    }
                }
            }
            .onAppear {
                if locationService.authorizationStatus == .authorizedWhenInUse || locationService.authorizationStatus == .authorizedAlways {
                    locationService.startUpdating()
                    if appState.hasAllLocalMusicGeneratesLeftToday() {
                        appState.clearCachedLocalMusicVenues()
                        viewModel.setVenues([])
                        if let loc = locationService.currentLocation {
                            Task {
                                await viewModel.fetchLocalVenues(location: loc, apiKey: appState.openAIKey)
                                appState.recordLocalMusicRefresh()
                                appState.saveCachedLocalMusicVenues(viewModel.venues)
                            }
                        }
                    } else {
                        viewModel.setVenues(appState.cachedLocalMusicVenues)
                    }
                }
            }
            .onChange(of: locationService.currentLocation) { location in
                if viewModel.venues.isEmpty, let loc = location, appState.canRefreshLocalMusic() {
                    Task {
                        await viewModel.fetchLocalVenues(location: loc, apiKey: appState.openAIKey)
                        appState.recordLocalMusicRefresh()
                        appState.saveCachedLocalMusicVenues(viewModel.venues)
                    }
                }
            }
        }
    }
    
    var mainContent: some View {
        VStack(spacing: 0) {
            if let error = viewModel.errorMessage {
                BHErrorBanner(message: error) { viewModel.errorMessage = nil }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            
            // Map
            LocalMusicMapView(venues: viewModel.venues, userLocation: locationService.currentLocation, selectedVenue: $viewModel.selectedVenue)
                .frame(height: 280)
                .cornerRadius(16)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            // Venue list
            if viewModel.venues.isEmpty {
                BHEmptyState(
                    icon: "music.note.house.fill",
                    title: "No Shows Tonight",
                    subtitle: appState.canRefreshLocalMusic()
                        ? "We couldn't find live music near your location tonight. Try again later! (\(appState.localMusicRefreshesRemainingToday()) generates left today)"
                        : "No generates left today. Try again tomorrow after 3am.",
                    actionTitle: appState.canRefreshLocalMusic() ? "Search Again" : nil,
                    action: appState.canRefreshLocalMusic() ? {
                        Task {
                            await viewModel.refresh(location: locationService.currentLocation, apiKey: appState.openAIKey)
                            appState.recordLocalMusicRefresh()
                            appState.saveCachedLocalMusicVenues(viewModel.venues)
                        }
                    } : nil
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.venues) { venue in
                                LocalVenueCard(venue: venue, isSelected: viewModel.selectedVenue?.id == venue.id) {
                                    withAnimation { viewModel.selectedVenue = venue }
                                }
                                .id(venue.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: viewModel.selectedVenue?.id) {
                        if let id = viewModel.selectedVenue?.id {
                            withAnimation {
                                proxy.scrollTo(id, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct LocalMusicMapView: View {
    let venues: [LocalVenue]
    let userLocation: CLLocation?
    @Binding var selectedVenue: LocalVenue?
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 43.65, longitude: -79.38),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    var annotations: [VenueAnnotation] {
        venues.map { venue in
            VenueAnnotation(id: venue.id, coordinate: venue.coordinate, title: venue.name, subtitle: venue.tonightEvent ?? "", type: .localVenue)
        }
    }
    
    var body: some View {
        Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: annotations) { item in
            MapAnnotation(coordinate: item.coordinate) {
                Button(action: {
                    withAnimation { selectedVenue = venues.first { $0.id == item.id } }
                }) {
                    VStack(spacing: 2) {
                        ZStack {
                            Circle()
                                .fill(selectedVenue?.id == item.id ? BHColors.accent : BHColors.accentPurple)
                                .frame(width: selectedVenue?.id == item.id ? 40 : 30, height: selectedVenue?.id == item.id ? 40 : 30)
                                .shadow(color: BHColors.accentPurple.opacity(0.5), radius: 4)
                            
                            Image(systemName: "music.note.house.fill")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    .animation(.spring(), value: selectedVenue?.id)
                }
            }
        }
        .onAppear {
            if let loc = userLocation {
                region = MKCoordinateRegion(
                    center: loc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
        }
    }
}

struct LocalVenueCard: View {
    let venue: LocalVenue
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            BHCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(BHColors.accentPurple.opacity(0.15))
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: "music.note.house.fill")
                                .font(.title3)
                                .foregroundColor(BHColors.accentPurple)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(venue.name)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(BHColors.textPrimary)
                            
                            if let event = venue.tonightEvent {
                                Text(event)
                                    .font(.subheadline)
                                    .foregroundColor(BHColors.accent)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            if let rating = venue.rating {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                    Text(String(format: "%.1f", rating))
                                        .font(.caption)
                                        .foregroundColor(BHColors.textSecondary)
                                }
                            }
                            
                            if let price = venue.priceRange {
                                Text(price)
                                    .font(.caption2)
                                    .foregroundColor(BHColors.accentGreen)
                            }
                        }
                    }
                    
                    if isSelected {
                        VStack(alignment: .leading, spacing: 8) {
                            Divider().background(BHColors.divider)
                            
                            if let desc = venue.description {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundColor(BHColors.textSecondary)
                            }
                            
                            Label(venue.address, systemImage: "mappin.circle")
                                .font(.caption)
                                .foregroundColor(BHColors.textSecondary)
                            
                            if let genre = venue.genre {
                                HStack(spacing: 4) {
                                    Image(systemName: "music.note.list")
                                        .font(.caption)
                                    Text(genre)
                                        .font(.caption)
                                }
                                .foregroundColor(BHColors.accentPurple)
                            }
                            
                            Button(action: openInMaps) {
                                HStack(spacing: 6) {
                                    Image(systemName: "map.fill")
                                    Text("Get Directions")
                                        .fontWeight(.semibold)
                                }
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(BHColors.accentPurple)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? BHColors.accentPurple : Color.clear, lineWidth: 1.5)
        )
    }
    
    func openInMaps() {
        let placemark = MKPlacemark(coordinate: venue.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = venue.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

struct RequestLocationView: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(BHColors.gradient)
            
            VStack(spacing: 8) {
                Text("Location Access")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(BHColors.textPrimary)
                
                Text("BeatHopper needs your location to find live music happening near you tonight.")
                    .font(.body)
                    .foregroundColor(BHColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            BHButton("Allow Location Access", icon: "location.fill") {
                action()
            }
            .padding(.horizontal, 32)
        }
    }
}

struct LocationDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(BHColors.textSecondary)
            
            Text("Location Denied")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(BHColors.textPrimary)
            
            Text("Please enable location access in Settings to find local music.")
                .font(.body)
                .foregroundColor(BHColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            BHButton("Open Settings", icon: "gearshape") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - ViewModel
class LocalMusicViewModel: ObservableObject {
    @Published var venues: [LocalVenue] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedVenue: LocalVenue?

    func setVenues(_ newVenues: [LocalVenue]) {
        venues = newVenues
    }

    func fetchLocalVenues(location: CLLocation, apiKey: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let results = try await OpenAIService.shared.findLocalMusic(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                apiKey: apiKey
            )
            await MainActor.run {
                venues = results
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func refresh(location: CLLocation?, apiKey: String) async {
        guard let location = location else { return }
        await fetchLocalVenues(location: location, apiKey: apiKey)
    }
}
