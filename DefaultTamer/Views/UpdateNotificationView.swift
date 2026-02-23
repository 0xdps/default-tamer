import SwiftUI

struct UpdateNotificationView: View {
    let update: AvailableUpdate
    let onDismiss: () -> Void
    let onDownload: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Update Available")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Version \(update.version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }
            
            if !update.name.isEmpty {
                Text(update.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack(spacing: 8) {
                if update.dmgURL != nil {
                    Button("Download") {
                        onDownload()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("View Release") {
                        if let url = URL(string: "https://github.com/0xdps/default-tamer/releases/latest") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Button("Later") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}

#Preview {
    UpdateNotificationView(
        update: AvailableUpdate(
            version: "0.0.2",
            name: "v0.0.2 - Bug fixes and improvements",
            dmgAsset: nil,
            publishedAt: "2026-02-01"
        ),
        onDismiss: { },
        onDownload: { }
    )
}
