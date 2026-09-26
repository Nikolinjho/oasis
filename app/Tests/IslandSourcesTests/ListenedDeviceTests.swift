import CoreAudio
import Testing
@testable import IslandSources

struct ListenedDeviceTests {
    @Test("Первое устройство: снимать слушателей не с кого")
    func firstAttach() {
        var listened = ListenedDevice()
        #expect(listened.switchTo(91) == ListenedDevice.Switch(attach: 91, detach: nil))
        #expect(listened.current == 91)
    }

    @Test("Смена дефолтного выхода: снять с прежнего, повесить на новое")
    func switchDevice() {
        var listened = ListenedDevice()
        _ = listened.switchTo(91)
        #expect(listened.switchTo(105) == ListenedDevice.Switch(attach: 105, detach: 91))
        #expect(listened.current == 105)
    }

    @Test("Повторное уведомление о том же устройстве ничего не меняет")
    func sameDevice() {
        var listened = ListenedDevice()
        _ = listened.switchTo(91)
        #expect(listened.switchTo(91) == nil)
    }

    @Test("Смена выхода — событие громкости, первое подключение — нет")
    func emitsOnlyOnChange() {
        #expect(ListenedDevice.Switch(attach: 105, detach: 91).isDeviceChange)
        #expect(!ListenedDevice.Switch(attach: 91, detach: nil).isDeviceChange)
    }
}
