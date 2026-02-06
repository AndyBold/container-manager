//
//  container_managerApp.swift
//  container-manager
//
//  Created by Andrew Bold on 30/12/2025.
//

import SwiftUI
import Combine

@main
struct container_managerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var containerMonitor = ContainerSystemMonitor()
    @StateObject private var windowManager = WindowManager()
    @AppStorage("showDesktopWindowOnLaunch") private var showDesktopWindowOnLaunch = false
    
    init() {
        // Set containerMonitor reference after initialization
        DispatchQueue.main.async {
            _ = container_managerApp.self
            // AppDelegate will access monitor through notification
        }
    }
    
    var body: some Scene {
        // Menu Bar Extra (always available)
        MenuBarExtra {
            ContentView()
                .environmentObject(containerMonitor)
                .environmentObject(windowManager)
                .onAppear {
                    // Pass containerMonitor to AppDelegate when view appears
                    appDelegate.containerMonitor = containerMonitor
                }
        } label: {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(containerMonitor.status.color)
        }
        .menuBarExtraStyle(.window)
        .commands {
            containerCommands
        }
        
        // Desktop Window (optional, can be opened from menu bar)
        Window("Container Manager", id: "desktop-window") {
            DesktopAppWindow()
                .environmentObject(containerMonitor)
                .environmentObject(windowManager)
        }
        .defaultSize(width: 1000, height: 700)
        .defaultPosition(.center)
        .commands {
            containerCommands
        }
        
        // Logs Windows (multiple, one per container)
        WindowGroup("Logs", id: "logs", for: String.self) { $containerName in
            if let containerName = containerName {
                ContainerLogsView(containerName: containerName)
                    .environmentObject(containerMonitor)
            }
        }
        .defaultSize(width: 900, height: 600)
        
        // Terminal Windows (multiple, one per container)
        WindowGroup("Terminal", id: "terminal", for: String.self) { $containerName in
            if let containerName = containerName {
                ContainerTerminalView(containerName: containerName)
                    .environmentObject(containerMonitor)
            }
        }
        .defaultSize(width: 800, height: 600)
        
        // Settings Window
        Settings {
            SettingsView()
        }
    }
    
    // MARK: - Commands
    
    @CommandsBuilder
    private var containerCommands: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Open Manager Window") {
                openDesktopWindow()
            }
            .keyboardShortcut("m", modifiers: [.command])
            
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
        
        CommandGroup(replacing: .newItem) {
            // Remove "New" menu items as they're not applicable
        }
    }
    
    // MARK: - Window Management
    
    private func openDesktopWindow() {
        if let url = URL(string: "container-manager://desktop-window") {
            NSWorkspace.shared.open(url)
        }
        
        // Alternative: Use NSWindow directly
        for window in NSApplication.shared.windows {
            if window.identifier?.rawValue == "desktop-window" {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }
        
        // If window doesn't exist, it will be created by SwiftUI
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    // Access to containerMonitor for auto-start
    weak var containerMonitor: ContainerSystemMonitor?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep app running in menu bar (accessory mode)
        // This allows the app to run without showing in the Dock
        NSApp.setActivationPolicy(.accessory)
        
        // Set up notification observers for opening windows
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenDesktopWindow),
            name: .openDesktopWindow,
            object: nil
        )
        
        // Auto-start service if enabled
        let autoStartService = UserDefaults.standard.bool(forKey: "autoStartService")
        if autoStartService {
            // Small delay to avoid blocking app startup
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.containerMonitor?.startContainerService()
            }
        }
    }
    
    @objc private func handleOpenDesktopWindow() {
        // Open or focus the desktop window
        openWindow(id: "desktop-window")
    }
    
    private func openWindow(id: String) {
        // Temporarily change to regular app to show window
        NSApp.setActivationPolicy(.regular)
        
        // Find and show the window
        for window in NSApplication.shared.windows {
            if window.identifier?.rawValue == id {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }
        
        // If no desktop windows are open, revert to accessory
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let hasVisibleWindows = NSApplication.shared.windows.contains { window in
                window.isVisible && window.identifier?.rawValue == "desktop-window"
            }
            
            if !hasVisibleWindows {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when windows close - stay in menu bar
        return false
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let openDesktopWindow = Notification.Name("openDesktopWindow")
}

// MARK: - Window Manager

@MainActor
class WindowManager: ObservableObject {
    @Published var openLogWindows: Set<String> = []
    
    func openLogsWindow(for containerName: String) {
        openLogWindows.insert(containerName)
        
        // Open the window using the environment
        if #available(macOS 14.0, *) {
            // Use the new WindowGroup API
            NSWorkspace.shared.open(URL(string: "container-manager://logs/\(containerName)")!)
        }
    }
    
    func closeLogsWindow(for containerName: String) {
        openLogWindows.remove(containerName)
    }
}

// Global function to open logs window
@MainActor
func openLogsWindow(for containerName: String) {
    // Use URL scheme to open logs window
    NSWorkspace.shared.open(URL(string: "container-manager://logs/\(containerName)")!)
}



