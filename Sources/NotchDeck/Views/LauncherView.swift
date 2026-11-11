import SwiftUI

struct LauncherView: View {
    @ObservedObject var launcher: LauncherModel

    var body: some View {
        Card {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)], spacing: 10) {
                    ForEach(launcher.apps, id: \.self) { url in
                        Button { launcher.open(url) } label: {
                            AppTile(icon: Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)),
                                    name: url.deletingPathExtension().lastPathComponent)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Remove from Apps") { launcher.remove(url) }
                        }
                    }
                    Button { launcher.addViaPanel() } label: {
                        AppTile(icon: Image(systemName: "plus.circle.fill"), name: "Add")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct AppTile: View {
    let icon: Image
    let name: String

    var body: some View {
        VStack(spacing: 4) {
            icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundStyle(.secondary)
            Text(name)
                .font(.system(size: 10))
                .lineLimit(1)
                .frame(width: 64)
        }
        .contentShape(Rectangle())
    }
}
