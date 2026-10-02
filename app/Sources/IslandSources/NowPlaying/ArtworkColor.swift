import CoreImage
import Foundation
import IslandCore

/// Цвет волны из обложки: средний цвет, поднятый до читаемой на тёмном острове яркости
public enum ArtworkColor {
  // CIContext по документации Apple потокобезопасен для конкурентного render и сам Sendable в этом SDK:
  // один на процесс, а не по одному на каждый трек и каждый вызов average()
  private static let context = CIContext(options: [.workingColorSpace: NSNull()])

  public static func accent(of data: Data) -> RGB? {
    guard let image = CIImage(data: data), !image.extent.isEmpty else { return nil }
    return average(image, in: image.extent).map(lifted)
  }

  /// Gradient: средние цвета верхней и нижней половины обложки, поднятые до читаемой яркости
  public static func gradient(of data: Data) -> (top: RGB, bottom: RGB)? {
    guard let image = CIImage(data: data), !image.extent.isEmpty else { return nil }
    guard let halves = halves(of: image) else { return nil }
    return (lifted(halves.top), lifted(halves.bottom))
  }

  /// Один decode обложки на трек: сразу accent (среднее по всей обложке) и bottom (низ, для Gradient) —
  /// то, что нужно AdapterNowPlayingSource.fillAccent на каждый трек (вместо отдельных accent(of:) + gradient(of:))
  static func accentAndBottom(of data: Data) -> (accent: RGB, bottom: RGB)? {
    guard let image = CIImage(data: data), !image.extent.isEmpty,
      let accentColor = average(image, in: image.extent),
      let halves = halves(of: image)
    else { return nil }
    return (lifted(accentColor), lifted(halves.bottom))
  }

  private static func halves(of image: CIImage) -> (top: RGB, bottom: RGB)? {
    let extent = image.extent
    // у CIImage начало снизу: верх обложки — верхняя половина extent
    let top = CGRect(x: extent.minX, y: extent.midY, width: extent.width, height: extent.height / 2)
    let bottom = CGRect(x: extent.minX, y: extent.minY, width: extent.width, height: extent.height / 2)
    guard let topColor = average(image, in: top), let bottomColor = average(image, in: bottom) else { return nil }
    return (topColor, bottomColor)
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

  private static func average(_ image: CIImage, in rect: CGRect) -> RGB? {
    guard
      let filter = CIFilter(
        name: "CIAreaAverage",
        parameters: [
          kCIInputImageKey: image, kCIInputExtentKey: CIVector(cgRect: rect),
        ]), let output = filter.outputImage
    else { return nil }
    var pixel = [UInt8](repeating: 0, count: 4)
    context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
    return RGB(red: Double(pixel[0]) / 255, green: Double(pixel[1]) / 255, blue: Double(pixel[2]) / 255)
  }
}
