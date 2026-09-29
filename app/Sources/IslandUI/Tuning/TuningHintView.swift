import IslandCore
import SwiftUI

/// Подложка подгонки выреза (Task 17t): пока пользователь держит ползунок Notch width/height в Tuning.
/// Заливка формы (красная) задаёт IslandView, здесь только содержимое — оно чёрное на красном фоне
/// (Alcove 1.7.9, 29.09, MBP 16", API-вырез 185, Notch width −1, height 0)
struct TuningHintView: View {
    let hint: TuningHint
    let notchWidth: CGFloat

    var body: some View {
        switch hint {
        case .width:
            VStack {
                Spacer(minLength: 0)
                widthRow
                    // точный отступ снизу не снимали: оценка по силуэту подложки (высота 69, строка внизу)
                    .padding(.bottom, 10)
            }
        case .height:
            heightRow
                .frame(height: IslandGeometry.tuningHeightBase)
        }
    }

    /// «← −1 →»: стрелки по краям, значение по центру (Alcove 1.7.9, 29.09). Строка внизу подложки
    /// (высота 69), ниже физического выреза (высотой notch.height): гасить его гэпом здесь не нужно —
    /// в отличие от heightRow, чья высота (32) как раз совпадает с вырезом
    private var widthRow: some View {
        HStack {
            Image(systemName: "arrow.left")
            Spacer()
            Text(hint.signedLabel)
                .monospacedDigit()
            Spacer()
            Image(systemName: "arrow.right")
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.black)
        .padding(.horizontal, 14)
    }

    /// Глиф ↕ слева, значение со знаком справа (Alcove 1.7.9, 29.09)
    private var heightRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.and.down")
            Spacer(minLength: notchWidth)
            Text(hint.signedLabel)
                .monospacedDigit()
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.black)
        .padding(.horizontal, 14)
    }
}
