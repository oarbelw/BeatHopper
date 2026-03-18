import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0
    @State private var apiKey = ""
    @State private var showAPIKeyPage = false
    
    var body: some View {
        ZStack {
            BHColors.background.ignoresSafeArea()
            
            if showAPIKeyPage {
                APIKeyEntryView(apiKey: $apiKey) {
                    let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    appState.saveOpenAIKey(key)
                    appState.saveOnboarding()
                }
            } else {
                onboardingPages
            }
        }
    }
    
    var onboardingPages: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                OnboardingPage(
                    icon: "🎵",
                    title: "Welcome to\nBeatHopper",
                    subtitle: "Never miss your favorite artists when they come to your city.",
                    gradient: [Color(hex: "#FF2D55"), Color(hex: "#FF6B6B")]
                ).tag(0)
                
                OnboardingPage(
                    icon: "📍",
                    title: "Track Your Cities",
                    subtitle: "Select up to 5 cities. We'll alert you when artists play within 50km.",
                    gradient: [Color(hex: "#BF5AF2"), Color(hex: "#0A84FF")]
                ).tag(1)
                
                OnboardingPage(
                    icon: "🎤",
                    title: "Follow Your Artists",
                    subtitle: "Connect Spotify or Apple Music, or manually add up to 100 favorite artists.",
                    gradient: [Color(hex: "#32D74B"), Color(hex: "#0A84FF")]
                ).tag(2)
                
                OnboardingPage(
                    icon: "🗺️",
                    title: "Find Local Music",
                    subtitle: "Discover live music happening tonight near your current location.",
                    gradient: [Color(hex: "#FF9500"), Color(hex: "#FF2D55")]
                ).tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<4) { i in
                    Capsule()
                        .fill(i == currentPage ? BHColors.accent : BHColors.divider)
                        .frame(width: i == currentPage ? 24 : 8, height: 8)
                        .animation(.spring(), value: currentPage)
                }
            }
            .padding(.vertical, 24)
            
            VStack(spacing: 12) {
                if currentPage == 3 {
                    BHButton("Get Started") {
                        withAnimation { showAPIKeyPage = true }
                    }
                } else {
                    BHButton("Next") {
                        withAnimation { currentPage += 1 }
                    }
                }
                
                if currentPage < 3 {
                    Button("Skip") {
                        withAnimation { showAPIKeyPage = true }
                    }
                    .foregroundColor(BHColors.textSecondary)
                    .font(.subheadline)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

struct OnboardingPage: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)
                    .opacity(0.4)
                
                Text(icon)
                    .font(.system(size: 80))
            }
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(BHColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(BHColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            Spacer()
        }
    }
}

struct APIKeyEntryView: View {
    @Binding var apiKey: String
    @EnvironmentObject var appState: AppState
    let onComplete: () -> Void
    
    @State private var isSecure = true
    @State private var showHelp = false
    
    var isValid: Bool {
        let k = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return (k.hasPrefix("AIza") && k.count > 30) || (k.hasPrefix("sk-") && k.count > 20)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer().frame(height: 60)
                
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(BHColors.gradient)
                            .frame(width: 80, height: 80)
                            .blur(radius: 20)
                            .opacity(0.4)
                        Image(systemName: "key.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(BHColors.gradient)
                    }
                    
                    Text("Gemini API Key")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(BHColors.textPrimary)
                    
                    Text("BeatHopper uses Google Gemini to find concerts and discover music. Add your API key to get started.")
                        .font(.body)
                        .foregroundColor(BHColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                VStack(spacing: 12) {
                    HStack {
                        if isSecure {
                            SecureField("AIza...", text: $apiKey)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(BHColors.textPrimary)
                        } else {
                            TextField("AIza...", text: $apiKey)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(BHColors.textPrimary)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                        
                        Button(action: { isSecure.toggle() }) {
                            Image(systemName: isSecure ? "eye" : "eye.slash")
                                .foregroundColor(BHColors.textSecondary)
                        }
                    }
                    .padding()
                    .background(BHColors.surfaceElevated)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isValid ? BHColors.accentGreen.opacity(0.6) : BHColors.divider, lineWidth: 1)
                    )
                    
                    if !apiKey.isEmpty && !isValid {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Use a Gemini key (starts with AIza) from aistudio.google.com")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Spacer()
                        }
                    }
                    
                    Button(action: { showHelp = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "questionmark.circle")
                            Text("How to get an API key")
                        }
                        .font(.caption)
                        .foregroundColor(BHColors.accentBlue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)
                
                VStack(spacing: 12) {
                    BHButton("Continue", icon: "arrow.right") {
                        onComplete()
                    }
                    .disabled(!isValid)
                    .opacity(isValid ? 1 : 0.5)
                    .padding(.horizontal, 24)
                }
            }
        }
        .background(BHColors.background.ignoresSafeArea())
        .sheet(isPresented: $showHelp) {
            APIKeyHelpView()
        }
    }
}

struct APIKeyHelpView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Go to platform.openai.com")
                            .font(.headline)
                            .foregroundColor(BHColors.textPrimary)
                        Text("Create an account or get an API key from Google AI Studio.")
                            .foregroundColor(BHColors.textSecondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("2. Navigate to API Keys")
                            .font(.headline)
                            .foregroundColor(BHColors.textPrimary)
                        Text("Go to Settings → API Keys in the left sidebar.")
                            .foregroundColor(BHColors.textSecondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("3. Create a new key")
                            .font(.headline)
                            .foregroundColor(BHColors.textPrimary)
                        Text("Click 'Create new secret key', give it a name like 'BeatHopper', and copy it.")
                            .foregroundColor(BHColors.textSecondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("4. Add billing")
                            .font(.headline)
                            .foregroundColor(BHColors.textPrimary)
                        Text("Gemini API has a free tier. Get your key at aistudio.google.com.")
                            .foregroundColor(BHColors.textSecondary)
                    }
                    
                    BHCard {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(BHColors.accentGreen)
                            Text("Your API key is stored securely on your device and never shared.")
                                .font(.caption)
                                .foregroundColor(BHColors.textSecondary)
                        }
                        .padding()
                    }
                }
                .padding(24)
            }
            .background(BHColors.background.ignoresSafeArea())
            .navigationTitle("Getting Your API Key")
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
