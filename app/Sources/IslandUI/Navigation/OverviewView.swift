import IslandCore
import SwiftUI

struct OverviewView: View {
  let info: NowPlayingInfo?
  let agenda: DayAgenda
  let claude: ClaudePanel?
  var agents = ClaudeAgentsPanel()
  let soon: SoonPanel?
  let dismissedEvents: Set<String>
  let appearance: IslandAppearance
  let mediaEnabled: Bool
  let calendarEnabled: Bool
  let onAction: (PlayerAction) -> Void
  let onJoin: (URL) -> Void
  let onSoonAction: (SoonAction) -> Void
  let onSelectView: (ExpandedView) -> Void
  let onOpenSettings: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      if mediaEnabled {
        OverviewMusic(info: info, appearance: appearance, onAction: onAction, onOpen: { onSelectView(.player) })
          .frame(width: 184, height: 164)
      } else {
        unavailable("Музыка выключена", width: 184)
      }
      divider
      VStack(alignment: .leading, spacing: 6) {
        if calendarEnabled {
          CalendarDayView(
            agenda: agenda, dismissedEvents: dismissedEvents, style: appearance.calendar, compact: true,
            onOpen: { onSelectView(.calendar) }, onJoin: onJoin)
        } else {
          unavailable("Календарь выключен", width: 280, height: 126)
        }
        claudeSummary
      }
      .frame(width: 280, height: 164, alignment: .topLeading)
      divider
      if let soon {
        TimelineView(.periodic(from: .now, by: 1)) { context in
          SoonListView(
            panel: SoonPanel(reminders: soon.reminders, now: context.date),
            now: context.date, compact: true, onAction: onSoonAction)
        }
      } else {
        unavailable("Soon выключен", width: 204)
      }
    }
    .padding(.horizontal, 24)
    .padding(.top, 8)
    .frame(width: ExpandedLayout.dashboard.width, height: 184, alignment: .top)
  }

  private var divider: some View {
    Rectangle().fill(IslandPalette.divider)
      .frame(width: 1, height: 158)
      .padding(.horizontal, 12)
  }

  private var claudeSummary: some View {
    Button {
      onSelectView(.agents)
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
    .help("Агенты и ответы Claude Code")
  }

  private var claudeTitle: String {
    if agents.waitingCount > 0 { return "Claude · \(agents.waitingCount) ждут ответа" }
    guard let claude, let window = claude.limits.fiveHour ?? claude.limits.sevenDay else { return "Claude Code" }
    return "Claude · \(claude.remaining(window))% осталось"
  }

  private var claudeSubtitle: String {
    if !agents.agents.isEmpty { return "Сессий: \(agents.agents.count) · Агенты и ответы" }
    guard let claude else { return agents.connected ? "Подключено · Агенты и ответы" : "Подключить агентов" }
    if claude.isStale { return claude.freshness }
    if let window = claude.limits.fiveHour { return "5 часов · \(claude.resetText(window, weekday: false))" }
    return "7 дней · \(claude.freshness)"
  }

  private func unavailable(_ title: String, width: CGFloat, height: CGFloat = 164) -> some View {
    Button(action: onOpenSettings) {
      VStack(spacing: 6) {
        Text(title).font(.system(size: 12, weight: .medium))
        Text("Настроить").font(.system(size: 11)).foregroundStyle(Color(red: 45 / 255, green: 212 / 255, blue: 191 / 255))
      }
      .foregroundStyle(IslandPalette.secondary)
      .frame(width: width, height: height)
    }
    .buttonStyle(.plain)
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
