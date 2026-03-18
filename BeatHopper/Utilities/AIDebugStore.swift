import Foundation
import SwiftUI

struct AIDebugEntry: Identifiable {
    let id: UUID
    let label: String
    let systemPrompt: String
    let userPrompt: String
    var status: Status
    var response: String?
    var durationMs: Int?

    enum Status {
        case thinking
        case completed
    }
}

final class AIDebugStore: ObservableObject {
    static let shared = AIDebugStore()

    @Published private(set) var entries: [AIDebugEntry] = []
    private let maxEntries = 50

    private init() {}

    @discardableResult
    func logThinking(label: String, systemPrompt: String, userPrompt: String) -> UUID {
        let id = UUID()
        let entry = AIDebugEntry(
            id: id,
            label: label,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            status: .thinking
        )
        Task { @MainActor in
            entries.insert(entry, at: 0)
            if entries.count > maxEntries { entries.removeLast() }
        }
        return id
    }

    func complete(entryId: UUID, response: String, durationMs: Int) {
        Task { @MainActor in
            if let idx = entries.firstIndex(where: { $0.id == entryId }) {
                entries[idx].status = .completed
                entries[idx].response = response
                entries[idx].durationMs = durationMs
            }
        }
    }

    func clear() {
        Task { @MainActor in entries.removeAll() }
    }
}

// MARK: - Debug Sheet UI
struct AIDebugSheet: View {
    @ObservedObject private var store = AIDebugStore.shared
    @Environment(\.dismiss) var dismiss
    @State private var expandedId: UUID?

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0D0D12").ignoresSafeArea()
                if store.entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "ladybug")
                            .font(.largeTitle)
                            .foregroundColor(BHColors.textSecondary)
                        Text("No AI calls yet")
                            .foregroundColor(BHColors.textSecondary)
                        Text("Tap Check in My Shows to search; each batch will appear here.")
                            .font(.caption)
                            .foregroundColor(BHColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(store.entries) { entry in
                                AIDebugEntryRow(entry: entry, isExpanded: expandedId == entry.id) {
                                    withAnimation { expandedId = expandedId == entry.id ? nil : entry.id }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("AI Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        store.clear()
                    }
                    .foregroundColor(BHColors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(BHColors.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct AIDebugEntryRow: View {
    let entry: AIDebugEntry
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onTap) {
                HStack {
                    Image(systemName: entry.status == .thinking ? "brain.head.profile" : "checkmark.circle.fill")
                        .foregroundColor(entry.status == .thinking ? .orange : BHColors.accentGreen)
                    Text(entry.label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(BHColors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    if let ms = entry.durationMs {
                        Text("\(ms)ms")
                            .font(.caption2)
                            .foregroundColor(BHColors.textSecondary)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(BHColors.textSecondary)
                }
                .padding(12)
                .background(BHColors.surfaceElevated)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Group {
                        Text("System prompt").font(.caption).fontWeight(.semibold).foregroundColor(BHColors.accent)
                        Text(entry.systemPrompt)
                            .font(.caption)
                            .foregroundColor(BHColors.textSecondary)
                    }
                    Group {
                        Text("User prompt").font(.caption).fontWeight(.semibold).foregroundColor(BHColors.accent)
                        Text(entry.userPrompt)
                            .font(.caption)
                            .foregroundColor(BHColors.textSecondary)
                    }
                    if entry.status == .thinking {
                        HStack(spacing: 4) {
                            ProgressView().scaleEffect(0.7).tint(BHColors.accent)
                            Text("AI thinking...").font(.caption).foregroundColor(BHColors.textSecondary)
                        }
                    } else if let response = entry.response {
                        Group {
                            Text("AI response").font(.caption).fontWeight(.semibold).foregroundColor(BHColors.accentGreen)
                            Text(response)
                                .font(.caption)
                                .foregroundColor(BHColors.textPrimary)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BHColors.surfaceElevated.opacity(0.8))
                .cornerRadius(8)
            }
        }
    }
}
