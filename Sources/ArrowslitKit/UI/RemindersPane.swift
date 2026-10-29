import SwiftUI

struct RemindersPane: View {
    @Bindable var state: AppState
    private var service: RemindersService { state.reminders }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("REMINDERS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(ArrowTheme.faint)
                Spacer()
                if service.access == .granted {
                    Button("Refresh") { service.refresh() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ArrowTheme.muted)
                }
            }

            switch service.access {
            case .notAsked:
                remindPrompt
            case .denied:
                deniedPrompt
            case .granted:
                if service.items.isEmpty {
                    Text("Nothing due today.")
                        .font(.system(size: 12))
                        .foregroundStyle(ArrowTheme.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 6) {
                            ForEach(service.items) { item in
                                ReminderRow(service: service, item: item)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { service.refresh() }
    }

    private var remindPrompt: some View {
        VStack(spacing: 10) {
            Text("See today's to-dos from Reminders here.")
                .font(.system(size: 12))
                .foregroundStyle(ArrowTheme.muted)
            Button("Connect Reminders") { service.requestAccess() }
                .buttonStyle(.plain)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Capsule().fill(Color(red: 0.04, green: 0.52, blue: 1)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deniedPrompt: some View {
        VStack(spacing: 10) {
            Text("Reminders access is off for Arrowslit.")
                .font(.system(size: 12))
                .foregroundStyle(ArrowTheme.muted)
            Button("Open Privacy Settings") { service.openPrivacySettings() }
                .buttonStyle(.plain)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(ArrowTheme.ink)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Capsule().fill(ArrowTheme.amber))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ReminderRow: View {
    let service: RemindersService
    let item: ReminderItem

    var body: some View {
        Button { service.complete(item) } label: {
            HStack(spacing: 9) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(item.completed ? ArrowTheme.green : Color(red: 0.30, green: 0.60, blue: 1))
                Text(item.title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(ArrowTheme.bone)
                    .lineLimit(1)
                Spacer()
                if let due = item.due {
                    Text(due.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(ArrowTheme.faint)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.045)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
