import SwiftUI
import GuidestoopCore
import GuidestoopStorage

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
            Text("Guidestoop")
                .font(.title)
            Text("Core v\(GuidestoopCoreVersion.current) · Storage v\(GuidestoopStorageVersion.current)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
