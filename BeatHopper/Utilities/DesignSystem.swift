import SwiftUI

// MARK: - BHColors
enum BHColors {
    // Backgrounds
    static let background      = Color(hex: "#0D0D12")
    static let surface         = Color(hex: "#14141C")
    static let surfaceElevated = Color(hex: "#1C1C28")
    static let divider         = Color.white.opacity(0.08)

    // Text
    static let textPrimary   = Color.white
    static let textSecondary = Color(hex: "#8E8EA0")

    // Accents
    static let accent       = Color(hex: "#FF4F00")   // BeatHopper orange
    static let accentGreen  = Color(hex: "#32D74B")
    static let accentBlue   = Color(hex: "#0A84FF")
    static let accentPurple = Color(hex: "#BF5AF2")

    // Gradient
    static let gradient = LinearGradient(
        colors: [Color(hex: "#FF4F00"), Color(hex: "#FF9500")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Color Hex Init
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - BHButton
struct BHButton: View {
    enum Style { case primary, secondary, destructive }

    let title: String
    let icon: String?
    let style: Style
    let action: () -> Void

    init(_ title: String, icon: String? = nil, style: Style = .primary, action: @escaping () -> Void) {
        self.title  = title
        self.icon   = icon
        self.style  = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.subheadline) }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(fgColor)
            .background(bgView)
            .cornerRadius(14)
        }
    }

    private var fgColor: Color {
        switch style {
        case .primary:     return .black
        case .secondary:   return BHColors.accent
        case .destructive: return .red
        }
    }

    @ViewBuilder
    private var bgView: some View {
        switch style {
        case .primary:
            BHColors.gradient
        case .secondary:
            RoundedRectangle(cornerRadius: 14)
                .stroke(BHColors.accent, lineWidth: 1.5)
                .background(Color.clear)
        case .destructive:
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.red, lineWidth: 1.5)
                .background(Color.clear)
        }
    }
}

// MARK: - BHCard
struct BHCard<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        content()
            .background(BHColors.surfaceElevated)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(BHColors.divider, lineWidth: 1))
    }
}

// MARK: - BHEmptyState
struct BHEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(BHColors.textSecondary)
            VStack(spacing: 8) {
                Text(title)
                    .font(.title3).fontWeight(.bold)
                    .foregroundColor(BHColors.textPrimary)
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(BHColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            if let actionTitle, let action {
                BHButton(actionTitle, action: action)
                    .padding(.horizontal, 48)
            }
            Spacer()
        }
    }
}

// MARK: - BHLoadingView
struct BHLoadingView: View {
    let message: String
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
                .tint(BHColors.accent)
            Text(message)
                .font(.subheadline)
                .foregroundColor(BHColors.textSecondary)
            Spacer()
        }
    }
}

// MARK: - BHErrorBanner
struct BHErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            Text(message).font(.caption).foregroundColor(BHColors.textPrimary)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.caption).foregroundColor(BHColors.textSecondary)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - SpinningLoader
struct SpinningLoader: View {
    @State private var angle: Double = 0
    var body: some View {
        Circle()
            .trim(from: 0.1, to: 0.9)
            .stroke(BHColors.gradient, lineWidth: 2.5)
            .frame(width: 22, height: 22)
            .rotationEffect(.degrees(angle))
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}

// MARK: - VenueAnnotation (shared map model)
struct VenueAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let subtitle: String
    let type: AnnotationType

    enum AnnotationType { case concert, city, localVenue }
}

// MARK: - BeatButtonStyle (legacy compat)
struct BeatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(configuration.isPressed ? BHColors.accent.opacity(0.7) : BHColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - CoreLocation import for VenueAnnotation
import CoreLocation
