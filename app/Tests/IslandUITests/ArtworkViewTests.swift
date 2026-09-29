import AppKit
import Testing
import UniformTypeIdentifiers
@testable import IslandUI

@MainActor
struct ArtworkViewTests {
    static func png(width: Int, height: Int) -> Data {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    @Test("Превью видео 16:9, квадратная обложка и плейсхолдер — квадрат (Alcove 1.7.9: 54×30 у YouTube)")
    func frame() {
        #expect(ArtworkView.frame(for: Self.png(width: 32, height: 18), side: 54) == CGSize(width: 54, height: 30))
        #expect(ArtworkView.frame(for: Self.png(width: 20, height: 20), side: 55) == CGSize(width: 55, height: 55))
        #expect(ArtworkView.frame(for: nil, side: 16) == CGSize(width: 16, height: 16))
    }
}
