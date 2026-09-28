import CoreAudio
import Testing
@testable import IslandSources

struct ListenedDeviceTests {
    private let quiet = VolumeState(volume: 0.56, muted: false)

    @Test("Первое устройство: снимать слушателей не с кого")
    func firstAttach() {
        var listened = ListenedDevice()
        let change = listened.switchTo(91, baseline: quiet)
        #expect(change == ListenedDevice.Switch(attach: 91, detach: nil))
        #expect(listened.current == 91)
    }

    @Test("Смена дефолтного выхода: снять с прежнего, повесить на новое")
    func switchDevice() {
        var listened = ListenedDevice()
        _ = listened.switchTo(91, baseline: quiet)
        let change = listened.switchTo(105, baseline: quiet)
        #expect(change == ListenedDevice.Switch(attach: 105, detach: 91))
        #expect(listened.current == 105)
    }

    @Test("Повторное уведомление о том же устройстве ничего не меняет")
    func sameDevice() {
        var listened = ListenedDevice()
        _ = listened.switchTo(91, baseline: quiet)
        let change = listened.switchTo(91, baseline: quiet)
        #expect(change == nil)
    }

    @Test("Уведомление без изменения уровня после подключения AirPods — не событие")
    func dropsUnchangedAfterSwitch() {
        var listened = ListenedDevice()
        _ = listened.switchTo(91, baseline: VolumeState(volume: 0.3, muted: false))
        _ = listened.switchTo(151, baseline: quiet)
        let first = listened.report(quiet)
        let second = listened.report(quiet)
        #expect(!first && !second)
    }

    @Test("Громкость изменилась — событие, повтор того же уровня — нет")
    func emitsRealChange() {
        var listened = ListenedDevice()
        _ = listened.switchTo(91, baseline: quiet)
        let louder = VolumeState(volume: 0.62, muted: false)
        let changed = listened.report(louder)
        let repeated = listened.report(louder)
        #expect(changed && !repeated)
    }

    @Test("Mute на нулевой громкости — событие, хотя уровень HUD остаётся 0")
    func emitsMuteAtZero() {
        var listened = ListenedDevice()
        _ = listened.switchTo(91, baseline: VolumeState(volume: 0, muted: false))
        let muted = listened.report(VolumeState(volume: 0, muted: true))
        let unmuted = listened.report(VolumeState(volume: 0, muted: false))
        #expect(muted && unmuted)
    }

    @Test("Уровень HUD: при mute — 0, без громкости — 0")
    func level() {
        #expect(VolumeState(volume: 0.5, muted: true).level == 0)
        #expect(VolumeState(volume: nil, muted: false).level == 0)
        #expect(VolumeState(volume: 0.5, muted: false).level == 0.5)
    }
}
