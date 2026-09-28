import Foundation
@preconcurrency import IOBluetooth
import Testing
@testable import IslandSources

@MainActor
struct BluetoothWatcherTests {
    @Test("Уведомление о подключении с фоновой очереди не падает: IOBluetooth шлёт его не с главного потока")
    func connectedOffMain() async {
        let watcher = BluetoothWatcher()
        let device = IOBluetoothDevice(addressString: "AA-BB-CC-DD-EE-FF")
        // так вызывает IOBluetooth: селектор с очереди CoreBluetooth (краш 28.09 в проверке изоляции MainActor)
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            DispatchQueue.global().async {
                _ = watcher.perform(NSSelectorFromString("connected:device:"), with: nil, with: device)
                done.resume()
            }
        }
    }
}
