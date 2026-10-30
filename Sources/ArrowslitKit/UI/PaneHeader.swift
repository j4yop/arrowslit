import SwiftUI

/// One quiet heading style for every pane: sentence case, system font, and a
/// single line of plain detail when it earns its place.
struct PaneHeader<Trailing: View>: View {
    let title: String
    let detail: String?
    let trailing: Trailing

    init(_ title: String, detail: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.detail = detail
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ArrowTheme.title)
                    .foregroundStyle(ArrowTheme.bone)
                if let detail {
                    Text(detail)
                        .font(ArrowTheme.detail)
                        .foregroundStyle(ArrowTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
    }
}

extension PaneHeader where Trailing == EmptyView {
    init(_ title: String, detail: String? = nil) {
        self.init(title, detail: detail) { EmptyView() }
    }
}
