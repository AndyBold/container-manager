//
//  NotificationManager.swift
//  container-manager
//
//  Manages macOS notifications for container events
//

import UserNotifications
import Foundation
import SwiftUI

class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    
    // Read directly from UserDefaults instead of using @AppStorage
    private var showNotifications: Bool {
        UserDefaults.standard.bool(forKey: "showNotifications")
    }

    override init() {
        super.init()
        
        // Set default value for showNotifications if not set
        if UserDefaults.standard.object(forKey: "showNotifications") == nil {
            UserDefaults.standard.set(true, forKey: "showNotifications")
        }
        
        center.delegate = self
        requestAuthorization()
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    func sendNotification(title: String, body: String, identifier: String = UUID().uuidString) {
        guard showNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        center.add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }

    // MARK: - Convenience Methods

    func containerStarted(_ name: String) {
        sendNotification(title: "Container Started", body: name, identifier: "container-started-\(name)")
    }

    func containerStopped(_ name: String) {
        sendNotification(title: "Container Stopped", body: name, identifier: "container-stopped-\(name)")
    }

    func containerError(_ name: String, error: String) {
        sendNotification(title: "Container Error", body: "\(name): \(error)", identifier: "container-error-\(name)")
    }

    func serviceStarted() {
        sendNotification(title: "Container Service", body: "Service started successfully", identifier: "service-started")
    }

    func serviceStopped() {
        sendNotification(title: "Container Service", body: "Service stopped", identifier: "service-stopped")
    }

    func serviceError(_ error: String) {
        sendNotification(title: "Container Service Error", body: error, identifier: "service-error")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification) async
                               -> UNNotificationPresentationOptions {
        // Show notifications even when app is in foreground
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse) async {
        // Handle notification interactions (taps, actions)
        // Could open the desktop window or specific container view
        print("User interacted with notification: \(response.notification.request.identifier)")
    }
}
