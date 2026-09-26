import CoreGraphics
import Foundation
import ImageIO
import IslandCore
import Testing
import UniformTypeIdentifiers
@testable import IslandSources

struct ArtworkColorTests {
    static func solidPNG(red: CGFloat, green: CGFloat, blue: CGFloat) -> Data {
        let context = CGContext(
            data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(srgbRed: red, green: green, blue: blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    @Test("Яркая обложка отдаёт свой цвет")
    func brightStays() throws {
        let color = try #require(ArtworkColor.accent(of: Self.solidPNG(red: 1, green: 1, blue: 0)))
        #expect(abs(color.red - 1) < 0.03 && abs(color.green - 1) < 0.03 && color.blue < 0.03)
    }

    @Test("Тёмный цвет поднимается до яркости 0.45")
    func darkIsLifted() {
        let lifted = ArtworkColor.lifted(RGB(red: 0, green: 0, blue: 0))
        #expect(abs(lifted.red - 0.45) < 1e-9 && abs(lifted.green - 0.45) < 1e-9 && abs(lifted.blue - 0.45) < 1e-9)
    }

    @Test("Битые данные — nil")
    func garbage() {
        #expect(ArtworkColor.accent(of: Data("not an image".utf8)) == nil)
    }
}
