import IslandCore
import SwiftUI

/// Компакт и peek календаря: секунды до начала и время до конца обновляются раз в секунду (ui-inspection 3.5)
struct CalendarLiveView: View {
    let event: CalendarEvent?
    let showsLine: Bool
    let notchWidth: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let event {
                ActivityCompactView(
                    layout: ActivityLayouts.calendar(event: event, now: context.date, showsLine: showsLine),
                    notchWidth: notchWidth)
            }
        }
    }
}
