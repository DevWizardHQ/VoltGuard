import SwiftUI
import VoltGuardCore

struct ScheduleTab: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state

        Form {
            Section {
                Toggle("Limit monitoring to a schedule", isOn: $state.settings.schedule.isEnabled)
                Text(
                    "Outside every active window VoltGuard stops evaluating rules and the menu bar shows that it is outside schedule."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Active hours") {
                ForEach($state.settings.schedule.windows) { $window in
                    WindowEditor(window: $window)
                }
                Button("Add Window") {
                    state.settings.schedule.windows.append(
                        ScheduleWindow(name: "New Window", startMinuteOfDay: 9 * 60, endMinuteOfDay: 18 * 60)
                    )
                }
            }
            .disabled(!state.settings.schedule.isEnabled)
        }
        .formStyle(.grouped)
    }
}

private struct WindowEditor: View {
    @Binding var window: ScheduleWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("", isOn: $window.isEnabled)
                    .labelsHidden()
                    .accessibilityLabel("Enable \(window.name)")
                TextField("Name", text: $window.name)
            }

            HStack {
                DatePicker(
                    "From",
                    selection: Binding(
                        get: { Self.date(from: window.startMinuteOfDay) },
                        set: { window.startMinuteOfDay = Self.minutes(from: $0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                DatePicker(
                    "To",
                    selection: Binding(
                        get: { Self.date(from: window.endMinuteOfDay) },
                        set: { window.endMinuteOfDay = Self.minutes(from: $0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }

            HStack(spacing: 4) {
                ForEach(Weekday.allCases) { day in
                    Toggle(
                        day.shortName,
                        isOn: Binding(
                            get: { window.weekdays.contains(day) },
                            set: { isOn in
                                if isOn { window.weekdays.insert(day) } else { window.weekdays.remove(day) }
                            }
                        )
                    )
                    .toggleStyle(.button)
                    .accessibilityLabel(day.shortName)
                }
            }

            if window.crossesMidnight {
                Text("This window crosses midnight and belongs to the day it starts on.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private static func date(from minutes: Int) -> Date {
        Calendar.current.date(
            bySettingHour: minutes / 60,
            minute: minutes % 60,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private static func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
