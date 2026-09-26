import AppKit
import os

/// Перехват медиаклавиш через CGEventTap: съедает громкость и яркость, чтобы система не показывала свой OSD.
/// Без Accessibility tap не создаётся
@MainActor
public final class MediaKeyTap {
    /// Возвращает true, если клавиша обработана и событие надо съесть
    public typealias Handler = @MainActor (MediaKeyPress) -> Bool

    private let handler: Handler
    private var tap: CFMachPort?
    private let log = SourceLog.logger("keys")

    public init(handler: @escaping Handler) {
        self.handler = handler
    }

    public var isRunning: Bool { tap != nil }

    /// false, если Accessibility не выдан
    @discardableResult
    public func start() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask(1) << 14  // NX_SYSDEFINED
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, info in
                guard let info else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<MediaKeyTap>.fromOpaque(info).takeUnretainedValue()
                // tap висит на main run loop, колбэк приходит на главном потоке
                let swallow = MainActor.assumeIsolated { owner.shouldSwallow(type, event) }
                return swallow ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque())
        else {
            log.error("event tap not created: no Accessibility")
            return false
        }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        log.info("event tap started")
        return true
    }

    private func shouldSwallow(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            log.info("event tap re-enabled after \(type.rawValue)")
            return false
        }
        guard let nsEvent = NSEvent(cgEvent: event), nsEvent.type == .systemDefined,
              let press = MediaKeyPress.decode(subtype: Int(nsEvent.subtype.rawValue), data1: nsEvent.data1, flags: event.flags)
        else { return false }
        return handler(press)
    }
}
