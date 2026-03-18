import Foundation
import UserNotifications

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            print("Notification permission: \(granted)")
        }
    }
    
    func scheduleConcertNotification(concert: Concert) {
        let content = UNMutableNotificationContent()
        content.title = "🎵 \(concert.artistName) is coming!"
        content.body = "\(concert.artistName) is playing at \(concert.venueName) in \(concert.city) on \(concert.date)"
        content.sound = .default
        content.badge = 1
        
        // Schedule 1 week before if possible; otherwise immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "concert_\(concert.id)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendConcertsFoundNotification(count: Int) {
        guard count > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🎤 BeatHopper found \(count) show\(count == 1 ? "" : "s")!"
        content.body = count == 1 ? "One of your artists is coming to your city soon." : "\(count) of your favorite artists are coming to your cities soon."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "concerts_found_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}
