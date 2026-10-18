import Foundation
import IslandCore
import SwiftUI

/// Независимые цели календаря, музыки и ожидающих запросов вокруг физического выреза.
struct SharedActivityCompactView: View {
  let agents: ClaudeAgentsPanel
  let music: NowPlayingInfo?
  let event: CalendarEvent?
  let notchWidth: CGFloat
  let height: CGFloat
  var appearance = IslandAppearance.default
  let onSelect: (ExpandedView) -> Void

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        Button {
          onSelect(event == nil ? .agents : .calendar)
        } label: {
          HStack(spacing: 6) {
            Group {
              if event == nil {
                ActivityIcon(layout: ActivityLayouts.claudeIcon).frame(width: 18, height: 15)
              } else {
                Image(systemName: "calendar").foregroundStyle(IslandPalette.dateAccent)
              }
            }
            if let event {
              TimelineView(.periodic(from: .now, by: 1)) { context in
                if event.start <= context.date {
                  ActivityRing(
                    progress: max(
                      0, min(1, context.date.timeIntervalSince(event.start) / max(1, event.end.timeIntervalSince(event.start)))),
                    color: Color(event.color), track: IslandPalette.divider
                  ).frame(width: 14, height: 14)
                } else {
                  Text(countdown(event, now: context.date)).monospacedDigit()
                }
              }
            } else {
              Text("Claude")
            }
          }.font(.system(size: 11, weight: .medium)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(event == nil ? "Агенты Claude" : "Календарь")
        Color.clear.frame(width: notchWidth)
        HStack(spacing: 10) {
          if let music {
            Button {
              onSelect(.player)
            } label: {
              ArtworkFlip(info: music, side: 16, radius: 4, flips: appearance.artworkFlip)
                .scaleEffect(PausedArtwork.look(isPlaying: music.isPlaying).scale)
                .frame(width: 20, height: 24)
            }.accessibilityLabel("Музыка")
          }
          Button {
            onSelect(.agents)
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "sparkle").font(.system(size: 12))
              Text("\(agents.waitingCount)").font(.system(size: 12, weight: .semibold)).monospacedDigit()
            }.foregroundStyle(ClaudeAgentsStyle.accent).frame(height: 24)
          }.accessibilityLabel("\(agents.waitingCount) запросов Claude ждут ответа")
        }.frame(maxWidth: .infinity, alignment: .trailing)
      }
      .padding(.horizontal, 18).frame(height: 32)
      if height > 32 {
        Text(event?.title ?? music?.title ?? "Claude ждёт ответа")
          .font(.system(size: 12, weight: .medium)).lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 18).frame(height: height - 32)
      }
    }
    .buttonStyle(.plain).foregroundStyle(IslandPalette.foreground)
  }

  private func countdown(_ event: CalendarEvent, now: Date) -> String {
    if event.start <= now { return "Сейчас" }
    let seconds = event.start.timeIntervalSince(now)
    if seconds < 60 { return "\(max(1, Int(ceil(seconds))))s" }
    let minutes = Int(ceil(seconds / 60))
    return "\(max(1, minutes))m"
  }
}
