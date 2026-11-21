import AppKit
import IslandCore
import SwiftUI

@MainActor public enum ReviewExporter {
 public static var records: [[String: String]] = []
 public static func write<V: View>(_ view: V, _ id: String, _ title: String, _ size: CGSize, _ directory: String) {
  let spec = IslandShapeSpec(size:size,bottomRadius:size.height > 80 ? 35:14)
  let content: AnyView = id.hasPrefix("settings-")
    ? AnyView(view.environment(\.colorScheme,.dark))
    : AnyView(view.frame(width:size.width,height:size.height).background(IslandPalette.background).clipShape(IslandShape(spec:spec,shoulder:0)).environment(\.colorScheme,.dark))
  let host=NSHostingView(rootView:content)
  host.sizingOptions=[]
  let window=NSWindow(contentRect:NSRect(origin:NSPoint(x:100,y:100),size:size),styleMask:[.borderless],backing:.buffered,defer:false)
  window.isReleasedWhenClosed=false;window.appearance=NSAppearance(named:.darkAqua)
  window.isOpaque=false;window.backgroundColor=id.hasPrefix("settings-") ? .windowBackgroundColor : .clear
  window.hasShadow=false;window.contentView=host;host.frame=NSRect(origin:.zero,size:size)
  window.setContentSize(size);host.layoutSubtreeIfNeeded();window.orderFrontRegardless();window.display()
  RunLoop.main.run(until:Date().addingTimeInterval(0.15))
  let capture=Process();capture.executableURL=URL(fileURLWithPath:"/usr/sbin/screencapture")
  capture.arguments=["-x","-o","-l",String(window.windowNumber),URL(fileURLWithPath:directory).appendingPathComponent(id+".png").path]
  try! capture.run();capture.waitUntilExit();precondition(capture.terminationStatus == 0)
  records.append(["id":id,"title":title,"width":String(Int(size.width)),"height":String(Int(size.height))])
  window.close()
 }
 public static func export(_ directory: String) {
  let now = Date(timeIntervalSince1970: 1794085405.737012)
  let info = NowPlayingInfo(bundleID: NowPlayingInfo.musicBundleID, title:"Midnight City",artist:"M83",isPlaying:true,duration:244,elapsed:82)
  let event = CalendarEvent(id:"sync",title:"Дизайн Oasis",start:now.addingTimeInterval(600),end:now.addingTimeInterval(2400),isAllDay:false,color:RGB(red:0.5,green:0.8,blue:0.5),url:URL(string:"https://meet.google.com/abc-defg-hij"),location:"Студия")
  let agenda = DayAgenda(today:[event],tomorrow:[])
  let reminder = try! SoonReminder(title:"Сделать перерыв",durationSeconds:900,now:now)
  let soon = SoonPanel(reminders:[reminder],now:now)
  let limits = ClaudeLimits(fiveHour:ClaudeWindow(usedPercent:38,resetsAt:now.addingTimeInterval(7200)),sevenDay:ClaudeWindow(usedPercent:24,resetsAt:now.addingTimeInterval(400000)),capturedAt:now)
  let claude = ClaudePanel(limits:limits,day:nil,now:now,horizon:.midnight,calendar:.current)
  var agents = ClaudeAgentsPanel(); agents.connected=true
  agents.agents=[ClaudeAgentSnapshot(id:ClaudeAgentID(sessionID:"oasis"),project:"Oasis",directory:"~/oasis",branch:"main",title:"Освежить оформление",state:.working,detail:"Проверяет макеты")]
  var codex = agents; codex.provider = .codex
  for view in ExpandedView.allCases {
   let size = ExpandedLayout.size(for:view,navigation:true)
   write(ExpandedContent(view:view,agents:agents,codex:codex,info:info,agenda:agenda,claude:claude,soon:soon,onAction:{_ in},onJoin:{_ in},navigation:true),view.rawValue,view.rawValue,size,directory)
   if [.duo,.player,.calendar,.soon,.overview,.inbox,.agents,.codexAgents].contains(view) {
    write(ExpandedContent(view:view,info:nil,agenda:.empty,soon:SoonPanel(reminders:[],now:now),onAction:{_ in},onJoin:{_ in},navigation:true),view.rawValue+"-empty",view.rawValue+" · пусто",size,directory)
   }
  }
  var paused=info;paused.isPlaying=false
  write(ExpandedContent(view:.player,info:paused,agenda:agenda,volume:0.6,showsVolumeRow:true,onAction:{_ in},onJoin:{_ in},navigation:true),"player-volume","Плеер · громкость",ExpandedLayout.size(for:.player,navigation:true,volumeRow:true),directory)
  write(SoonDetailView(reminder:reminder,now:now,onAction:{_ in}),"soon-detail","Soon · детали",CGSize(width:345,height:175),directory)
  write(SoonComposerView(title:.constant("Сделать перерыв"),duration:.constant("15m"),onSubmit:{},onClose:{}),"soon-compose","Soon · создание",CGSize(width:345,height:207),directory)
  for playing in [true,false] {
   var track=info;track.isPlaying=playing
   for peek in [false,true] {
    write(MusicLiveView(info:track,notchWidth:185,showsTitle:peek),"music-\(playing ? "playing":"paused")-\(peek ? "peek":"compact")","Музыка · \(playing ? "играет":"пауза") · \(peek ? "peek":"компакт")",CGSize(width:peek ? 276:257,height:peek ? 51:32),directory)
   }
  }
  for kind:HUDKind in [.volume,.brightness] {
   for level in [0.0,0.6,1.0] {
    write(HUDView(kind:kind,level:level,notchWidth:185),"hud-\(kind)-\(Int(level*100))","HUD · \(kind) · \(Int(level*100))%",CGSize(width:367,height:32),directory)
   }
  }
  for (id,alert,width) in [("charging",IslandAlert.charging(level:0.8),350.0),("low-battery",.lowBattery(level:0.1),373.0),("low-power",.lowPower(level:0.5),435.0)] {
   write(AlertView(alert:alert,notchWidth:185),id,id,CGSize(width:width,height:32),directory)
  }

  write(Color.clear,"hover","Пустой остров · hover",CGSize(width:203,height:90),directory)
  for model:AirPodsInfo.Model in [.airpods,.pro,.max] {
   write(AlertView(alert:.airpods(AirPodsInfo(name:"AirPods",battery:0.75,model:model)),notchWidth:185),"airpods-\(model)","Наушники · \(model)",CGSize(width:280,height:32),directory)
  }
  write(AlertView(alert:.calendarReminder(CalendarReminder(eventID:"sync",title:"Дизайн Oasis",minutes:5,color:event.color)),notchWidth:185),"event-reminder","Напоминание о событии",CGSize(width:300,height:32),directory)
  write(SoonPeekView(notice:SoonNotice(reminder:reminder),notchWidth:185),"soon-peek","Soon · уведомление",CGSize(width:300,height:73),directory)
  let agentID=agents.agents[0].id
  for provider:AgentProvider in [.claude,.codex] {
   for kind:ClaudeRequest.Kind in [.permission,.questions] {
    let request=ClaudeRequest(id:ClaudeRequestID(agent:agentID),kind:kind,toolName:"Edit",originalInput:Data("{\"file_path\":\"docs/design/oasis.html\"}".utf8),questions:[ClaudeQuestion(text:"Какой вариант оформления оставить?",header:"Оформление",options:[.init(label:"Тропический",description:"Мягкий зелёный акцент"),.init(label:"Текущий",description:"Сохранить существующие цвета")],multiSelect:false)])
    var panel=agents;panel.provider=provider;panel.requests=[request];panel.selectedAgentID=agentID;panel.selectedRequestID=request.id
    for compact in [false,true] {
     panel.compact=compact
     let view:ExpandedView=provider == .codex ? .codexAgents:.agents
     write(ExpandedContent(view:view,agents:panel,codex:panel,info:info,agenda:agenda,soon:soon,onAction:{_ in},onJoin:{_ in},navigation:true),"\(provider)-\(kind)-\(compact)","\(provider.title) · \(kind) · \(compact ? "компакт":"обычный")",CGSize(width:panel.width,height:panel.height),directory)
    }
   }
  }
  try! JSONSerialization.data(withJSONObject:records,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:directory).appendingPathComponent("index.json"))
 }
}
