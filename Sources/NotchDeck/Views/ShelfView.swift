import SwiftUI
import UniformTypeIdentifiers

struct ShelfView: View {
    @ObservedObject var shelf: ShelfModel
    @State private var targeted = false

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("File Shelf", systemImage: "tray.full").font(.caption).foregroundStyle(Color.glassSecondary)
                    Spacer()
                    if !shelf.files.isEmpty {
                        Button("Clear") { shelf.clear() }
                            .buttonStyle(.plain).font(.caption).foregroundStyle(Color.glassSecondary)
                    }
                }
                if shelf.files.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "tray.and.arrow.down").font(.title2)
                        Text("Drag files onto the notch to keep them here,")
                        Text("then drag them out wherever you need them.")
                    }
                    .font(.callout)
                    .foregroundStyle(Color.glassSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(shelf.files, id: \.self) { url in
                                ShelfItem(url: url) { shelf.remove(url) }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(targeted ? Color.accentColor : Color.clear,
                              style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        )
        .onDrop(of: [UTType.fileURL], isTargeted: $targeted) { providers in
            shelf.add(providers: providers)
        }
    }
}

struct ShelfItem: View {
    let url: URL
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 48, height: 48)
            Text(url.lastPathComponent)
                .font(.system(size: 10))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 78)
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(hovering ? 0.08 : 0)))
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white, .gray)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(url.lastPathComponent) from the shelf")
            }
        }
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(url) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(url.lastPathComponent)
        .accessibilityAction(named: "Open") { NSWorkspace.shared.open(url) }
        .accessibilityAction(named: "Remove from shelf") { onRemove() }
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(url) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            Divider()
            Button("Remove from Shelf", action: onRemove)
        }
        .help(url.path)
    }
}
