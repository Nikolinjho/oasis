import IslandCore
import SwiftUI

struct OverviewView: View {
  let info: NowPlayingInfo?
  let agenda: DayAgenda
  let claude: ClaudePanel?
  let codex: CodexLimitsPanel?
  let soon: SoonPanel?
  let dismissedEvents: Set<String>
  let appearance: IslandAppearance
  let mediaEnabled: Bool
  let calendarEnabled: Bool
  let onAction: (PlayerAction) -> Void
  let onJoin: (URL) -> Void
  let onSoonAction: (SoonAction) -> Void
  let onSelectView: (ExpandedView) -> Void
  var notchWidth: CGFloat = 185

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      if mediaEnabled {
        OverviewMusic(info: info, appearance: appearance, onAction: onAction, onOpen: { onSelectView(.player) })
          .frame(width: 184, height: 164)
      }
      if mediaEnabled && (showsMiddleColumn || soon != nil) { divider }
      if showsMiddleColumn {
        VStack(alignment: .leading, spacing: 6) {
          if calendarEnabled {
            CalendarDayView(
              agenda: agenda, dismissedEvents: dismissedEvents, style: appearance.calendar, compact: true,
              onOpen: { onSelectView(.calendar) }, onJoin: onJoin)
          }
          HStack(spacing: 10) {
            if claude != nil { claudeSummary }
            if let codex {
              Button {
                onSelectView(.codex)
              } label: {
                HStack(spacing: 8) {
                  Image(systemName: "terminal").font(.system(size: 20))
                  VStack(alignment: .leading, spacing: 2) {
                    Text(codexTitle(codex)).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Text(codex.status == nil ? codex.freshness : "Лимиты недоступны")
                      .font(.system(size: 10)).foregroundStyle(IslandPalette.secondary).lineLimit(1)
                  }
                  Spacer(minLength: 0)
                  Image(systemName: "chevron.right").font(.system(size: 9))
                }
                .foregroundStyle(IslandPalette.foreground).frame(height: 30).contentShape(Rectangle())
              }
              .buttonStyle(.plain).help("Лимиты Codex")
            }
          }
        }
        .frame(width: 280, height: 164, alignment: .topLeading)
      }
      if showsMiddleColumn && soon != nil { divider }
      if let soon {
        TimelineView(.periodic(from: .now, by: 1)) { context in
          SoonListView(
            panel: SoonPanel(reminders: soon.reminders, now: context.date),
            now: context.date, compact: true, onAction: onSoonAction)
        }
      }
    }
    .padding(.horizontal, 24)
    .padding(.top, 8)
    .frame(width: layout.size(for: .overview).width, height: 184, alignment: .top)
  }

  private var divider: some View {
    Rectangle().fill(IslandPalette.divider)
      .frame(width: 1, height: 158)
      .padding(.horizontal, 12)
  }

  private var claudeSummary: some View {
    Button {
      onSelectView(.claude)
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "sparkle").font(.system(size: 20)).foregroundStyle(.orange)
        VStack(alignment: .leading, spacing: 2) {
          Text(claudeTitle).font(.system(size: 12, weight: .semibold)).foregroundStyle(IslandPalette.foreground).lineLimit(1)
          Text(claudeSubtitle).font(.system(size: 10)).foregroundStyle(IslandPalette.secondary).lineLimit(1)
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(IslandPalette.tertiary)
      }
      .frame(height: 30)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help("Лимиты Claude Code")
  }

  private var claudeTitle: String {
    guard let claude, let window = claude.limits.fiveHour ?? claude.limits.sevenDay else { return "Claude Code" }
    return "Claude · \(claude.remaining(window))% осталось"
  }

  private var claudeSubtitle: String {
    guard let claude else { return "Лимиты подписки" }
    if claude.isStale { return claude.freshness }
    if let window = claude.limits.fiveHour { return "5 часов · \(claude.resetText(window, weekday: false))" }
    return "7 дней · \(claude.freshness)"
  }

  private var layout: DashboardLayout {
    DashboardLayout(
      media: mediaEnabled, calendar: calendarEnabled, claude: claude != nil, codex: codex != nil,
      soon: soon != nil, notchWidth: notchWidth)
  }

  private var showsMiddleColumn: Bool {
    layout.showsMiddleColumn
  }

  private func codexTitle(_ panel: CodexLimitsPanel) -> String {
    guard let window = panel.limits?.buckets.first?.windows.first else { return "Codex" }
    return "Codex · \(window.remaining)% осталось"
  }

}

private struct OverviewMusic: View {
  let info: NowPlayingInfo?
  let appearance: IslandAppearance
  let onAction: (PlayerAction) -> Void
  let onOpen: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Button(action: onOpen) {
        HStack(spacing: 10) {
          ArtworkFlip(info: info, side: 52, radius: 9, flips: appearance.artworkFlip)
            .modifier(PausedArtwork(isPlaying: info?.isPlaying ?? false))
            .frame(width: 52, height: 52)
          VStack(alignment: .leading, spacing: 4) {
            Text(appearance.title(for: info) ?? "Не играет")
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(IslandPalette.foreground)
              .lineLimit(2)
            Text(info?.artist ?? "Музыка")
              .font(.system(size: 11))
              .foregroundStyle(IslandPalette.secondary)
              .lineLimit(1)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .help("Открыть плеер")
      HStack(spacing: 12) {
        Spacer(minLength: 0)
        ForEach(Array(PlayerControl.row(info).enumerated()), id: \.offset) { index, control in
          if (1...3).contains(index), let control {
            PlayerButton(control: control) { onAction(control.action) }
          }
        }
        Spacer(minLength: 0)
      }
      ProgressRow(
        info: info, fill: progressFill(info, appearance.waveform),
        showsRemaining: appearance.showsRemainingTime, onAction: onAction)
    }
    .padding(.top, 8)
    .frame(maxHeight: .infinity, alignment: .top)
  }
}
