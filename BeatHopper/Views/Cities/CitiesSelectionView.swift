import SwiftUI
import MapKit

struct CitiesSelectionView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = CitiesViewModel()
    @State private var searchText = ""
    @State private var showSearch = false
    
    var body: some View {
        ZStack {
            BHColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Count bar
                HStack {
                    Text("\(appState.trackedCities.count)/5 cities selected")
                        .font(.caption)
                        .foregroundColor(BHColors.textSecondary)
                    Spacer()
                    if appState.trackedCities.count < 5 {
                        Button(action: { showSearch = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Add City")
                            }
                            .font(.caption)
                            .foregroundColor(BHColors.accent)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Map showing all cities
                CityTrackerMapView(cities: appState.trackedCities)
                    .frame(height: 220)
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                
                if appState.trackedCities.isEmpty {
                    BHEmptyState(
                        icon: "globe",
                        title: "No Cities Tracked",
                        subtitle: "Add up to 5 cities. BeatHopper will find concerts within 50km of each city.",
                        actionTitle: "Add a City",
                        action: { showSearch = true }
                    )
                } else {
                    List {
                        ForEach(appState.trackedCities) { city in
                            CityRow(city: city)
                                .listRowBackground(BHColors.surfaceElevated)
                                .listRowSeparatorTint(BHColors.divider)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation { appState.removeCity(city) }
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle("Tracked Cities")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if appState.trackedCities.count < 5 {
                    Button(action: { showSearch = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(BHColors.gradient)
                    }
                }
            }
        }
        .sheet(isPresented: $showSearch) {
            CitySearchView()
        }
    }
}

struct CityRow: View {
    let city: City
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(BHColors.accentBlue.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(BHColors.accentBlue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(city.name)
                    .fontWeight(.medium)
                    .foregroundColor(BHColors.textPrimary)
                Text(city.country)
                    .font(.caption)
                    .foregroundColor(BHColors.textSecondary)
            }
            
            Spacer()
            
            Text("50 km radius")
                .font(.caption2)
                .foregroundColor(BHColors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(BHColors.accentBlue.opacity(0.12))
                .cornerRadius(6)
        }
        .padding(.vertical, 4)
    }
}

struct CityTrackerMapView: View {
    let cities: [City]
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 80, longitudeDelta: 160)
    )
    
    var annotations: [VenueAnnotation] {
        cities.map { city in
            VenueAnnotation(id: city.id, coordinate: city.coordinate, title: city.name, subtitle: city.country, type: .city)
        }
    }
    
    var body: some View {
        Map(position: .constant(.region(region))) {
            ForEach(annotations) { item in
                Annotation(item.title, coordinate: item.coordinate) {
                    VStack(spacing: 2) {
                        ZStack {
                            Circle()
                                .fill(BHColors.accentBlue.opacity(0.3))
                                .frame(width: 44, height: 44)
                            Circle()
                                .fill(BHColors.accentBlue)
                                .frame(width: 18, height: 18)
                            Image(systemName: "mappin.fill")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        Text(item.title)
                            .font(.system(size: 9))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(BHColors.accentBlue)
                            .cornerRadius(3)
                    }
                }
            }
        }
        .onAppear { Task { @MainActor in fitMap() } }
        .onChange(of: cities.count) { _ in Task { @MainActor in fitMap() } }
    }
    
    func fitMap() {
        guard !cities.isEmpty else { return }
        if cities.count == 1 {
            region = MKCoordinateRegion(center: cities[0].coordinate, span: MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 3))
        } else {
            let lats = cities.map { $0.latitude }
            let lons = cities.map { $0.longitude }
            let center = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lons.min()! + lons.max()!) / 2)
            let span = MKCoordinateSpan(latitudeDelta: max(abs(lats.max()! - lats.min()!) * 2.0, 5.0), longitudeDelta: max(abs(lons.max()! - lons.min()!) * 2.0, 5.0))
            region = MKCoordinateRegion(center: center, span: span)
        }
    }
}

struct CitySearchView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = CitiesViewModel()
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                BHColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(BHColors.textSecondary)
                        
                        TextField("Search cities...", text: $searchText)
                            .foregroundColor(BHColors.textPrimary)
                            .autocapitalization(.words)
                            .onSubmit {
                                Task { await viewModel.search(query: searchText) }
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(BHColors.textSecondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(BHColors.surfaceElevated)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .onChange(of: searchText) {
                        viewModel.debounceSearch(query: searchText)
                    }
                    
                    if viewModel.isLoading {
                        BHLoadingView(message: "Searching cities...")
                    } else if !viewModel.results.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(viewModel.results.enumerated()), id: \.offset) { index, city in
                                    let key = "\(city.name.lowercased())|\(city.country.lowercased())"
                                    let alreadyAdded = appState.trackedCities.contains(where: {
                                        "\($0.name.lowercased())|\($0.country.lowercased())" == key
                                    })
                                    let isDisabled = appState.trackedCities.count >= 5 && !alreadyAdded

                                    CitySearchRow(
                                        city: city,
                                        isAdded: alreadyAdded,
                                        isDisabled: isDisabled
                                    ) {
                                        if alreadyAdded {
                                            if let existing = appState.trackedCities.first(where: {
                                                "\($0.name.lowercased())|\($0.country.lowercased())" == key
                                            }) {
                                                appState.removeCity(existing)
                                            }
                                        } else if appState.trackedCities.count < 5 {
                                            appState.addCity(city)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                    .background(BHColors.background)

                                    Divider()
                                        .background(BHColors.divider)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "globe")
                                .font(.system(size: 48))
                                .foregroundColor(BHColors.textSecondary)
                            Text("Search for a city to track")
                                .foregroundColor(BHColors.textSecondary)
                            Text("Example: Toronto, London, Tokyo")
                                .font(.caption)
                                .foregroundColor(BHColors.textSecondary)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Add City")
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
}

struct CitySearchRow: View {
    let city: City
    let isAdded: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isAdded ? BHColors.accentGreen.opacity(0.2) : BHColors.accentBlue.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(isAdded ? BHColors.accentGreen : BHColors.accentBlue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(city.name)
                        .fontWeight(.medium)
                        .foregroundColor(isDisabled && !isAdded ? BHColors.textSecondary : BHColors.textPrimary)
                    Text(city.country)
                        .font(.caption)
                        .foregroundColor(BHColors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundColor(isAdded ? BHColors.accentGreen : (isDisabled ? BHColors.textSecondary : BHColors.accent))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled && !isAdded)
    }
}

// MARK: - ViewModel
class CitiesViewModel: ObservableObject {
    @Published var results: [City] = []
    @Published var isLoading = false
    
    private var debounceTask: Task<Void, Never>?
    
    func debounceSearch(query: String) {
        debounceTask?.cancel()
        guard query.count >= 2 else { results = []; return }
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            if !Task.isCancelled {
                await search(query: query)
            }
        }
    }
    
    func search(query: String) async {
        guard !query.isEmpty else { return }
        await MainActor.run { isLoading = true }
        let cities = await Task.detached(priority: .userInitiated) {
            WorldCitiesService.shared.search(query: query)
        }.value
        await MainActor.run {
            results = cities
            isLoading = false
        }
    }
}
