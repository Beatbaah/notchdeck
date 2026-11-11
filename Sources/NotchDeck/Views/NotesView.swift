import SwiftUI

struct NotesView: View {
    @AppStorage("notes.text") private var text = ""

    var body: some View {
        Card {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Jot something down… (saved automatically)")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.glassTertiary)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
        }
    }
}
