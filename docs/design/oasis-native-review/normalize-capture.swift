import AppKit
import Foundation
// Захват macOS иногда добавляет к рамке окна 1 pt с каждой стороны.
// Убираем только этот внешний край, без масштабирования снимка.
let root=URL(fileURLWithPath:CommandLine.arguments[1])
let rows=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("index.json"))) as! [[String:String]]
var count=0
for row in rows {
 let url=root.appendingPathComponent(row["id"]!+".png")
 let bitmap=NSBitmapImageRep(data:try Data(contentsOf:url))!
 let expectedWidth=Int(row["width"]!)!*2, expectedHeight=Int(row["height"]!)!*2
 let dw=bitmap.pixelsWide-expectedWidth,dh=bitmap.pixelsHigh-expectedHeight
 precondition([0,4].contains(dw) && [0,4].contains(dh),"Unexpected capture size: \(row["id"]!)")
 if dw==0 && dh==0 { continue }
 let crop=bitmap.cgImage!.cropping(to:CGRect(x:dw/2,y:dh/2,width:expectedWidth,height:expectedHeight))!
 try NSBitmapImageRep(cgImage:crop).representation(using:.png,properties:[:])!.write(to:url)
 count += 1
}
print("Normalized outer window capture border without resizing: \(count) images")
