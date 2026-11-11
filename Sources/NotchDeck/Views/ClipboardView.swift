import SwiftUI

struct ClipboardView: View {
    @ObservedObject var clipboard: ClipboardModel
    @State private var copied: String?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Clipboard history", systemImage: "doc.on.clipboard").font(.caption).foregroundStyle(Color.glassSecondary)
                    Spacer()
                    if copied != nil {
                        Text("Copied").font(.caption).foregroundStyle(.green)
                    }
                    if !clipboard.items.isEmpty {
                        Button("Clear") { clipboard.clear() }
                            .buttonStyle(.plain).font(.caption).foregroundStyle(Color.glassSecondary)
                    }
                }
                if clipboard.blocked {
                    VStack(spacing: 6) {
                        Image(systemName: "hand.raised.fill").font(.title2)
                        Text("macOS is blocking NotchDeck from reading what you copy. Allow NotchDeck to paste from other apps in System Settings → Privacy & Security.")
                            .multilineTextAlignment(.center)
                    }
                    .font(.callout)
                    .foregroundStyle(Color.glassSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if clipboard.items.isEmpty {
                    Text("Text you copy shows up here. Click an entry to copy it again.")
                        .font(.callout)
                        .foregroundStyle(Color.glassSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(clipboard.items) { item in
                                ClipRow(preview: item.preview,
                                        onCopy: { clipboard.copy(item.text); showCopied(item.text) },
                                        onDelete: { clipboard.remove(item.text) })
                            }
                        }
                    }
                }
            }
        }
    }

    private func showCopied(_ item: String) {
        copied = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copied == item { copied = nil }
        }
    }
}

struct ClipRow: View {
    let preview: String
    let onCopy: () -> Void
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            // A real button, so VoiceOver and the keyboard can copy it too.
            Button(action: onCopy) {
                HStack {
                    Text(preview)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(preview)
            .accessibilityHint("Copies it again")
            // Delete shows on hover; VoiceOver users get it as an action on the row.
            .accessibilityAction(named: "Delete", onDelete)
            if hovering {
                Button(action: onDelete) {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.glassSecondary)
                .accessibilityLabel("Delete")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(hovering ? 0.1 : 0)))
        .onHover { hovering = $0 }
    }
}
