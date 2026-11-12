import Foundation
import UserNotifications

/// 今日の盤のお知らせ（オプトイン。毎日 20:00 に 1 回）
enum Reminder {
    static let id = "daily-board"

    /// 許可を聞いて、予約する。許可がなければ false
    static func enable(japanese: Bool) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        let content = UNMutableNotificationContent()
        content.title = japanese ? "今日の盤が届いています" : "Today's board is here"
        content.body = japanese ? "1 分だけ、耳を合わせてみませんか。" : "One minute of listening, whenever you like."
        var when = DateComponents()
        when.hour = 20
        let request = UNNotificationRequest(identifier: id, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true))
        try? await center.add(request)
        return true
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
