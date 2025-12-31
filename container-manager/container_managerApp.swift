//
//  container_managerApp.swift
//  container-manager
//
//  Created by Andrew Bold on 30/12/2025.
//

import SwiftUI

@main
struct container_managerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var containerMonitor = ContainerSystemMonitor()
    
    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(containerMonitor)
        } label: {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(containerMonitor.status.color)
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(after: .appInfo) {
                Divider()
                
                Button(containerMonitor.status == .running ? "Stop Service" : "Start Service") {
                    if containerMonitor.status == .running {
                        containerMonitor.stopContainerService()
                    } else {
                        containerMonitor.startContainerService()
                    }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(containerMonitor.isOperating || containerMonitor.status == .error)
                
                Button("Refresh Status") {
                    containerMonitor.checkContainerStatus()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(containerMonitor.isOperating)
            }
        }
    }
}
// AppDelegate to hide from Dock and App Switcher
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock and Cmd+Tab switcher
        NSApp.setActivationPolicy(.accessory)
    }
}

