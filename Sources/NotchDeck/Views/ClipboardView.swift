import SwiftUI

struct ClipboardView: View {
    @ObservedObject var clipboard: ClipboardModel
    @State private var copied: String?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Clipboard history", systemImage: "doc.on.clipboard").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if copied != nil {
                        Text("Copied").font(.caption).foregroundStyle(.green)
                    }
                    if !clipboard.items.isEmpty {
                        Button("Clear") { clipboard.clear() }
                            .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if clipboard.items.isEmpty {
                    Text("Text you copy shows up here. Click an entry to copy it again.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(clipboard.items, id: \.self) { item in
                                ClipRow(text: item,
                                        onCopy: { clipboard.copy(item); showCopied(item) },
                                        onDelete: { clipboard.remove(item) })
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
    let text: String
    let onCopy: () -> Void
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Text(text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces))
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            if hovering {
                Button(action: onDelete) {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(hovering ? 0.1 : 0)))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: onCopy)
    }
}
