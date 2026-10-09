import IslandSources
import SwiftUI

struct YandexConnectionCard: View {
  @ObservedObject var connection: YandexMusicConnection
  @State private var confirmsConnect = false
  @State private var confirmsDisconnect = false

  var body: some View {
    SettingsCard(title: "Yandex Music connection") {
      VStack(alignment: .leading, spacing: 10) {
        Text(status).font(.system(size: 12)).foregroundStyle(.secondary)
        if let error = connection.commandError {
          Text(error).font(.system(size: 12)).foregroundStyle(.red)
        }
        HStack {
          Button("Connect…") { confirmsConnect = true }
            .disabled(connection.isBusy || connection.state == .appNotFound || connection.state == .connected)
          Button("Disconnect…") { confirmsDisconnect = true }
            .disabled(connection.isBusy || connection.state == .appNotFound)
        }
        Text("The local debugging port stays open until Yandex Music restarts normally, even after Oasis quits.")
          .font(.system(size: 11)).foregroundStyle(.secondary)
      }
    }
    .alert("Connect Yandex Music?", isPresented: $confirmsConnect) {
      Button("Cancel", role: .cancel) {}
      Button("Restart and connect") { Task { await connection.connect() } }
    } message: {
      Text(
        "Yandex Music will restart and may lose its current playback position. This opens a local debugging port that other processes on this Mac can use to access the client."
      )
    }
    .alert("Disconnect Yandex Music?", isPresented: $confirmsDisconnect) {
      Button("Cancel", role: .cancel) {}
      Button("Restart normally", role: .destructive) { Task { await connection.disconnect() } }
    } message: {
      Text("Yandex Music will restart without debugging to close the integration port. Its current playback position may be lost.")
    }
  }

  private var status: String {
    if connection.isBusy { return "Restarting Yandex Music…" }
    switch connection.state {
    case .appNotFound: return "Yandex Music is not installed."
    case .appClosed: return "Yandex Music is closed. Connect to launch it with integration enabled."
    case .requiresConnection: return "Connection requires an explicit restart."
    case .connecting: return "Connecting…"
    case .connected: return "Connected to the desktop player."
    case .notReady: return "The player is not ready. Check sign-in and playback in Yandex Music."
    case .incompatibleVersion: return "This version of the player is not supported."
    case .failed(let message): return message
    case .commandFailed(_, let message): return message
    }
  }
}
