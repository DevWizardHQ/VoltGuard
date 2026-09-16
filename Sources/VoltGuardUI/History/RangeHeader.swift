import SwiftUI

/// The control strip every history tab shares: a natural-width range picker
/// pinned to the top, separated from the content by a divider.
struct RangeHeader<Trailing: View>: View {
    @Binding var range: HistoryRange
    var label: String
    @ViewBuilder var trailing: Trailing

    init(range: Binding<HistoryRange>, label: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() })
    {
        self._range = range
        self.label = label
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker(label, selection: $range) {
                    ForEach(HistoryRange.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel(label)

                Spacer(minLength: 0)
                trailing
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()
        }
    }
}

extension View {
    /// Tab content fills the window and starts at the top; without this a
    /// VStack centres itself and leaves a band of empty space above the
    /// controls.
    func historyTabLayout() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
