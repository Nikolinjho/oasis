import AppKit
import IslandCore
import IslandUI
import SwiftUI

if CommandLine.arguments.contains("refresh") { setenv("OASIS_REVIEW_SKIN","refresh",1) }
let app = NSApplication.shared
let directory = CommandLine.arguments[1]
try! FileManager.default.createDirectory(atPath:directory,withIntermediateDirectories:true)
ReviewExporter.export(directory)
let defaults=UserDefaults(suiteName:"dev.nikoko.oasis.design-proof")!
let settings=AppSettings(defaults:defaults)
for page in SettingsPage.allCases {
 ReviewExporter.write(SettingsView(settings:settings,page:page),"settings-"+page.rawValue,"Настройки · "+page.title,CGSize(width:620,height:659),directory)
}
try! JSONSerialization.data(withJSONObject:ReviewExporter.records,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:directory).appendingPathComponent("index.json"))
print("Rendered \(ReviewExporter.records.count) native screens")
