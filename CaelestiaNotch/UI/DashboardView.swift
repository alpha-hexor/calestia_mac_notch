import SwiftUI

struct DashboardView: View {
    @ObservedObject var spotify: SpotifyService
    @ObservedObject var system: SystemMonitor
    let bongo: BongoCatController

    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: 10) {
                Card {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(context.date.formatted(.dateTime.weekday(.wide))).textCase(.uppercase)
                                .font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(Palette.muted)
                            Text(context.date, format: .dateTime.hour().minute())
                                .font(.system(size: 32, weight: .light, design: .rounded)).monospacedDigit()
                                .foregroundStyle(Palette.accent)
                            Text(context.date.formatted(.dateTime.month(.wide).day())).foregroundStyle(Palette.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(system.hardwareModel, systemImage: "laptopcomputer").lineLimit(1)
                        Label("up \(system.uptimeLabel)", systemImage: "clock")
                        Label(system.battery.map { "\($0)%\(system.isCharging ? " · charging" : " battery")" } ?? "AC power",
                              systemImage: system.isCharging ? "battery.100percent.bolt" : "battery.75percent")
                    }.font(.system(size: 10)).foregroundStyle(Palette.muted).frame(maxWidth: .infinity, alignment: .leading)
                }
            }.frame(width: 195)

            Card { CalendarCard() }

            Card {
                VStack(spacing: 8) {
                    AlbumArt(image: spotify.artwork).frame(width: 79, height: 79).clipShape(Circle())
                    Text(spotify.track?.title ?? "Nothing playing").font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.accent).lineLimit(1)
                    Text(spotify.track?.artist ?? "A soundtrack for your day")
                        .font(.system(size: 9)).foregroundStyle(Palette.muted).lineLimit(1)
                    PlaybackControls(spotify: spotify, compact: true)
                    BongoCatView(motion: bongo).frame(height: 44)
                }
            }.frame(width: 180)
        }
    }
}

private struct CalendarCard: View {
    private let calendar = Calendar.current

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let date = context.date
            VStack(spacing: 10) {
                HStack {
                    Text(date.formatted(.dateTime.month(.wide).year()))
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.accent)
                    Spacer()
                    Image(systemName: "calendar").foregroundStyle(Palette.muted)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 3) {
                    ForEach(0..<7, id: \.self) { index in
                        Text(weekday(index)).font(.system(size: 9, weight: .semibold)).foregroundStyle(Palette.ink)
                            .frame(height: 18)
                    }
                    ForEach(Array(days(for: date).enumerated()), id: \.offset) { _, day in
                        let today = day.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                        Text(day.map { String(calendar.component(.day, from: $0)) } ?? "")
                            .font(.system(size: 10, weight: today ? .semibold : .regular))
                            .frame(width: 22, height: 22)
                            .foregroundStyle(today ? Palette.cream : Palette.muted)
                            .background(today ? Palette.accent : .clear, in: Circle())
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func weekday(_ index: Int) -> String {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return symbols[(index + calendar.firstWeekday - 1) % 7]
    }

    private func days(for date: Date) -> [Date?] {
        guard let start = calendar.dateInterval(of: .month, for: date)?.start,
              let range = calendar.range(of: .day, in: .month, for: date) else { return [] }
        let offset = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        var dates = [Date?](repeating: nil, count: offset)
        dates += range.map { calendar.date(byAdding: .day, value: $0 - 1, to: start) }
        while dates.count % 7 != 0 { dates.append(nil) }
        return dates
    }
}
