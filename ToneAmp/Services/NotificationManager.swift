import Foundation
import UserNotifications

/// Daily "Tone of the Day" reminder — local notifications, no server.
/// Schedules the next 7 days with the actual deterministic pick for each
/// date (same formula the Library banner uses), refreshed on every launch.
enum NotificationManager {
    static let enabledKey = "toneamp.dailyToneReminder"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// Deterministic song for an arbitrary date — mirror of the Library
    /// banner so the notification names the song the banner will show.
    static func songOfDay(_ date: Date, in songs: [Song]) -> Song? {
        guard !songs.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = Calendar.current.component(.year, from: date)
        return songs[(day * 31 + year) % songs.count]
    }

    static func setEnabled(_ enabled: Bool, songs: [Song]) async {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(
            withIdentifiers: (0..<8).map { "tone-of-day-\($0)" }
        )
        guard enabled else { return }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else {
            UserDefaults.standard.set(false, forKey: enabledKey)
            return
        }
        await schedule(songs: songs)
    }

    /// Called on launch to keep the 7-day window rolling.
    static func refresh(songs: [Song]) async {
        guard isEnabled else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }
        await schedule(songs: songs)
    }

    private static func schedule(songs: [Song]) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(
            withIdentifiers: (0..<8).map { "tone-of-day-\($0)" }
        )
        let calendar = Calendar.current
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: Date()),
                  let song = songOfDay(date, in: songs),
                  let tone = song.tones.first else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = 18
            components.minute = 0
            // Skip today's slot if 18:00 already passed.
            guard let fireDate = calendar.date(from: components), fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Tone of the Day 🎸"
            content.body = "\(song.title) — \(song.artist). \(tone.amp), gain at \(String(format: "%.1f", tone.settings.gain)). Dial it in."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "tone-of-day-\(offset)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}
