import AppKit
import SwiftUI

/// Рендерит вью в app/build/snapshots/<name>.png для проверки глазами. Сравнения с эталоном нет
@MainActor
enum Snapshot {
  struct RenderError: Error {}

  @discardableResult
  static func write<V: View>(_ view: V, size: CGSize, name: String) throws -> CGSize {
    let content =
      view
      .frame(width: size.width, height: size.height)
      .background(Color(white: 0.85))
    let renderer = ImageRenderer(content: content)
    renderer.scale = 2
    guard let image = renderer.cgImage else { throw RenderError() }
    let app = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let directory = app.appendingPathComponent("build/snapshots")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
    try png.write(to: directory.appendingPathComponent("\(name).png"))
    return CGSize(width: image.width, height: image.height)
  }
}
