import SwiftUI

/// One quiet heading style for every pane: sentence case, system font, and a
/// single line of plain detail when it earns its place. Inside Vorssaint's
/// floating layer the launcher draws the title and ellipsis instead, so a
/// page keeps only its content.
struct PaneHeader<Trailing: View>: View {
    let title: String
    let detail: String?
    let trailing: Trailing
    @Environment(\.vorssaintEmbedded) private var vorssaintEmbedded

    init(_ title: String, detail: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.detail = detail
        self.trailing = trailing()
    }

    @ViewBuilder var body: some View {
        if vorssaintEmbedded {
            EmptyView()
        } else {
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
}

extension PaneHeader where Trailing == EmptyView {
    init(_ title: String, detail: String? = nil) {
        self.init(title, detail: detail) { EmptyView() }
    }
}
