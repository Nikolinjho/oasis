import CoreGraphics
import Foundation

/// Яркость встроенного дисплея через приватный DisplayServices. Может сломаться с апдейтом macOS
public final class BrightnessControl: @unchecked Sendable {
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let getBrightness: GetBrightness
    private let setBrightness: SetBrightness
    private let display: CGDirectDisplayID

    /// nil, если DisplayServices недоступен или встроенного дисплея нет
    public init?() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW),
              let get = dlsym(handle, "DisplayServicesGetBrightness"),
              let set = dlsym(handle, "DisplayServicesSetBrightness"),
              let display = Self.builtinDisplay() else { return nil }
        getBrightness = unsafeBitCast(get, to: GetBrightness.self)
        setBrightness = unsafeBitCast(set, to: SetBrightness.self)
        self.display = display
    }

    public var level: Double? {
        var value: Float = 0
        return getBrightness(display, &value) == 0 ? Double(value) : nil
    }

    /// Шаг клавиши. Возвращает новый уровень или nil, если установить не вышло
    @discardableResult
    public func step(up: Bool, fine: Bool) -> Double? {
        guard let current = level else { return nil }
        let next = LevelStep.apply(current, up: up, fine: fine)
        return setBrightness(display, Float(next)) == 0 ? next : nil
    }

    private static func builtinDisplay() -> CGDirectDisplayID? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &ids, &count) == .success else { return nil }
        return ids.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }
}
