import Foundation
import IOKit.ps
import IslandCore

/// Питание через IOKit power sources и режим энергосбережения. onChange зовётся на главном потоке
/// на каждое изменение, в том числе на смену процента: что из этого уведомление, решает PowerNotices
@MainActor
public final class PowerSource {
    public var onChange: (PowerState) -> Void = { _ in }
    private var runLoopSource: CFRunLoopSource?
    private var lowPowerObserver: NSObjectProtocol?

    public init() {}

    public func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        // C-колбэк без захватов: объект приходит через context. Источник добавлен в главный run loop
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let source = Unmanaged<PowerSource>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { source.emit() }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = source
        }
        lowPowerObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.emit() }
        }
        emit()
    }

    public var current: PowerState? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        let descriptions = list.compactMap {
            IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any]
        }
        return PowerStateParser.parse(descriptions: descriptions, isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled)
    }

    private func emit() {
        if let state = current { onChange(state) }
    }
}
