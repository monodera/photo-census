import SwiftUI

/// ハイライトがスライドするカプセル型セグメントコントロール。
/// 標準の .segmented ピッカーは macOS で切り替えアニメーションがないため自作する
struct SlidingSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String

    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                Text(label(option))
                    .font(.callout)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background {
                        if selection == option {
                            Capsule()
                                .fill(Color.accentColor)
                                .matchedGeometryEffect(id: "highlight", in: highlight)
                        }
                    }
                    .foregroundStyle(selection == option ? Color.white : Color.primary)
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selection = option
                        }
                    }
            }
        }
        .padding(3)
        .background(Capsule().fill(.quaternary))
    }
}
