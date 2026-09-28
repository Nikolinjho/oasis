import AppKit
import IslandCore

/// Пункты события вверху меню menu bar и правого клика по острову: иконка сервиса, иконка Calendar, крестик
/// (скрин меню Alcove 28.09)
@MainActor
enum CalendarMenuSection {
    struct Actions {
        let join: (URL) -> Void
        let open: (CalendarMenuModel) -> Void
        let dismiss: (String) -> Void
    }

    static func items(for model: CalendarMenuModel?, actions: Actions) -> [NSMenuItem] {
        guard let model else { return [] }
        var items: [NSMenuItem] = []
        if let url = model.meeting, let title = model.joinTitle {
            let join = ClosureMenuItem(title) { actions.join(url) }
            join.image = serviceIcon(model.service)
            items.append(join)
        }
        let open = ClosureMenuItem(CalendarMenuModel.openTitle) { actions.open(model) }
        open.image = appIcon(bundleID: "com.apple.iCal") ?? symbol("calendar")
        items.append(open)
        let dismiss = ClosureMenuItem(CalendarMenuModel.dismissTitle) { actions.dismiss(model.event.id) }
        dismiss.image = symbol("xmark.circle.fill")
        items.append(dismiss)
        return items
    }

    /// Open in Calendar: событие в Calendar.app, не открылось — сам Calendar.app
    static func open(_ model: CalendarMenuModel) {
        if let url = model.calendarURL, NSWorkspace.shared.open(url) { return }
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    /// Meet — иконка из бандла Alcove (Icons/google-meet.png, кладёт bundle.sh). Zoom и Teams — иконки установленных
    /// приложений. Нет ни того, ни другого, и у Telemost — video.fill
    static func serviceIcon(_ service: MeetingService?) -> NSImage {
        let icon: NSImage? = switch service {
        case .googleMeet: sized(Bundle.main.resourceURL.flatMap { NSImage(contentsOf: $0.appendingPathComponent("Icons/google-meet.png")) })
        case .zoom: appIcon(bundleID: "us.zoom.xos")
        case .teams: appIcon(bundleID: "com.microsoft.teams2")
        case .telemost, nil: nil
        }
        return icon ?? symbol("video.fill")
    }

    static func appIcon(bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return sized(NSWorkspace.shared.icon(forFile: url.path))
    }

    /// 18×18 — размер иконок меню Alcove (*AppIcon18x18.png в его бандле)
    static func sized(_ image: NSImage?) -> NSImage? {
        guard let copy = image?.copy() as? NSImage else { return nil }
        copy.size = NSSize(width: 18, height: 18)
        return copy
    }

    /// SF Symbol, нарисованный в квадрат 18×18 цветом labelColor. Шаблонный символ (и как есть, и копией с новым size)
    /// в этом меню не рисовался: живая проверка 28.09, у Dismiss Event не было иконки. Картинка с drawing handler
    /// перерисовывается под светлую и тёмную тему
    static func symbol(_ name: String) -> NSImage {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            // 14 pt — замера нет, оценка: крестик у Alcove чуть меньше иконок приложений
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            guard let glyph = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
            else { return false }
            let size = glyph.size
            glyph.draw(in: NSRect(
                x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height))
            // монохромный глиф красим поверх его же альфы: вырез крестика в круге остаётся прозрачным.
            // paletteColors с одним цветом заливал и крестик (живая проверка 28.09)
            NSColor.labelColor.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        image.isTemplate = false
        return image
    }
}
