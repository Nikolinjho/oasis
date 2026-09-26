import AppKit
import IslandSources

/// Меню кнопки 💻: устройства вывода, текущее с галочкой
@MainActor
enum OutputMenu {
    static func make(devices: OutputDevices) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(.sectionHeader(title: "Output"))
        let list = devices.list()
        if list.isEmpty {
            let empty = NSMenuItem(title: "No Output Devices", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        for device in list {
            // громкость и HUD нового устройства подхватит слушатель VolumeControl
            let item = ClosureMenuItem(device.name) { devices.select(device.id) }
            item.state = device.isDefault ? .on : .off
            menu.addItem(item)
        }
        return menu
    }
}
