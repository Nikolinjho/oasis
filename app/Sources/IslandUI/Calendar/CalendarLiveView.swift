import IslandCore
import SwiftUI

/// Компакт и peek календаря: секунды до начала и время до конца обновляются раз в секунду (ui-inspection 3.5)
struct CalendarLiveView: View {
  let event: CalendarEvent?
  var music: NowPlayingInfo?
  let showsLine: Bool
  let notchWidth: CGFloat
  var appearance = IslandAppearance.default

  var body: some View {
    // тики от начала события: смена «12s» → «11s» и шаг кольца совпадают с секундами события
    TimelineView(.periodic(from: event?.start ?? .now, by: 1)) { context in
      if let event {
        ActivityCompactView(
          layout: ActivityLayouts.calendar(
            event: event, now: context.date, showsLine: showsLine, withMusic: music != nil, style: appearance.calendar),
          notchWidth: notchWidth, artwork: music, artworkFlip: appearance.artworkFlip)
      }
    }
  }
}
