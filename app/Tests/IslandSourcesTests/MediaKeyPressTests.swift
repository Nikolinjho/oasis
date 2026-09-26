import CoreGraphics
import Testing
@testable import IslandSources

struct MediaKeyPressTests {
    static func data1(code: Int, state: Int) -> Int { (code << 16) | state }

    @Test("Нажатие и отпускание громкости")
    func volumeUpDownAndRelease() {
        let down = MediaKeyPress.decode(subtype: 8, data1: Self.data1(code: 0, state: 0x0A00), flags: [])
        #expect(down == MediaKeyPress(key: .volumeUp, isDown: true, isRepeat: false, fine: false))
        let up = MediaKeyPress.decode(subtype: 8, data1: Self.data1(code: 1, state: 0x0B00), flags: [])
        #expect(up == MediaKeyPress(key: .volumeDown, isDown: false, isRepeat: false, fine: false))
    }

    @Test("Яркость, mute и автоповтор")
    func brightnessMuteRepeat() {
        #expect(MediaKeyPress.decode(subtype: 8, data1: Self.data1(code: 2, state: 0x0A00), flags: [])?.key == .brightnessUp)
        #expect(MediaKeyPress.decode(subtype: 8, data1: Self.data1(code: 3, state: 0x0A00), flags: [])?.key == .brightnessDown)
        let mute = MediaKeyPress.decode(subtype: 8, data1: Self.data1(code: 7, state: 0x0A01), flags: [])
        #expect(mute == MediaKeyPress(key: .mute, isDown: true, isRepeat: true, fine: false))
    }

    @Test("Option+Shift — мелкий шаг")
    func fineStep() {
        let press = MediaKeyPress.decode(subtype: 8, data1: Self.data1(code: 0, state: 0x0A00), flags: [.maskAlternate, .maskShift])
        #expect(press?.fine == true)
    }

    @Test("Чужие клавиши и подтипы не трогаем")
    func ignored() {
        // 16 — NX_KEYTYPE_PLAY
        #expect(MediaKeyPress.decode(subtype: 8, data1: Self.data1(code: 16, state: 0x0A00), flags: []) == nil)
        #expect(MediaKeyPress.decode(subtype: 7, data1: Self.data1(code: 0, state: 0x0A00), flags: []) == nil)
    }
}
