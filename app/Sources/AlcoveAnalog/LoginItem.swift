import AppKit
import ServiceManagement

@MainActor
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            // при ad-hoc подписи регистрация не проходит: показываем причину, а не молчим
            let alert = NSAlert()
            alert.messageText = "Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
