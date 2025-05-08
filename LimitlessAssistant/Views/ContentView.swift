import SwiftUI

struct ContentView: View {
    @StateObject private var syncController = SyncController()

    var body: some View {
        VStack(spacing: 15) {
            Text("Limitless Assistant")
                .font(.largeTitle)
                .padding(.top)

            if syncController.isSyncing {
                ProgressView("Syncing...")
            } else {
                Button {
                    Task {
                        await syncController.syncNow()
                    }
                } label: {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                }
                .padding(.vertical)
            }

            VStack(alignment: .leading, spacing: 8) {
                if let lastSync = syncController.lastSyncDate {
                    Text("Last Sync: \(lastSync, formatter: dateFormatter)")
                } else {
                    Text("Last Sync: Never")
                }
                
                if let error = syncController.lastSyncError {
                    Text("Last Error: \(error.localizedDescription)")
                        .foregroundColor(.red)
                }
            }
            .font(.caption)

            Spacer()
        }
        .padding()
        .frame(minWidth: 450, idealWidth: 500, minHeight: 300, idealHeight: 350)
        .background(.thinMaterial) // Applying glassmorphism effect
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

#Preview {
    ContentView()
} 