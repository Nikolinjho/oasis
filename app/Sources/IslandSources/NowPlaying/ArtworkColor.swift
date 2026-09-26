import CoreImage
import Foundation
import IslandCore

/// Цвет волны из обложки: средний цвет, поднятый до читаемой на тёмном острове яркости
public enum ArtworkColor {
    public static func accent(of data: Data) -> RGB? {
        guard let image = CIImage(data: data), !image.extent.isEmpty,
              let filter = CIFilter(name: "CIAreaAverage", parameters: [
                  kCIInputImageKey: image,
                  kCIInputExtentKey: CIVector(cgRect: image.extent),
              ]),
              let output = filter.outputImage else { return nil }
        // без рабочего цветового пространства: значения sRGB проходят как есть
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        return lifted(RGB(red: Double(pixel[0]) / 255, green: Double(pixel[1]) / 255, blue: Double(pixel[2]) / 255))
    }

    /// Тёмный средний цвет на острове #0C0A09 не виден: тянем к белому до яркости 0.45
    static func lifted(_ color: RGB) -> RGB {
        let luma = 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue
        guard luma < 0.45 else { return color }
        let t = (0.45 - luma) / (1 - luma)
        return RGB(
            red: color.red + (1 - color.red) * t,
            green: color.green + (1 - color.green) * t,
            blue: color.blue + (1 - color.blue) * t)
    }
}
