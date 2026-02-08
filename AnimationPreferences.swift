//
//  AnimationPreferences.swift
//  container-manager
//
//  Animation and visual effect preferences helper
//

import SwiftUI
import AppKit

/// Helper extension to access animation preferences throughout the app
extension View {
    /// Returns the appropriate animation based on user preferences
    /// - Parameters:
    ///   - animation: The animation to use if animations are enabled
    ///   - value: The value to observe for animation triggers
    /// - Returns: The animation or nil based on preferences
    func animatedIf<V: Equatable>(
        _ animation: Animation = .smooth,
        value: V,
        enableAnimations: Bool = true,
        reduceMotion: Bool = false
    ) -> some View {
        self.animation(
            enableAnimations ? (reduceMotion ? .linear(duration: 0.2) : animation) : nil,
            value: value
        )
    }
    
    /// Applies a smooth transition based on user preferences
    func transitionIf(
        _ transition: AnyTransition,
        enableAnimations: Bool = true
    ) -> some View {
        self.transition(enableAnimations ? transition : .identity)
    }
}

/// Animation preferences accessible throughout the app
struct AnimationPreferences {
    var enableAnimations: Bool
    var reduceMotion: Bool
    var showLoadingIndicators: Bool
    var compactMode: Bool
    var showEmptyStateIllustrations: Bool
    
    /// Check if the system has reduce motion enabled
    private static var systemReduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    
    /// Check if the system has reduce transparency enabled
    private static var systemReduceTransparency: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    }
    
    /// Check if the system has increase contrast enabled
    private static var systemIncreaseContrast: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    }
    
    /// Effective reduce motion setting (app setting OR system setting)
    var effectiveReduceMotion: Bool {
        reduceMotion || Self.systemReduceMotion
    }
    
    /// Default animation to use based on preferences
    var defaultAnimation: Animation? {
        guard enableAnimations else { return nil }
        return effectiveReduceMotion ? .linear(duration: 0.2) : .smooth
    }
    
    /// Spring animation to use based on preferences
    var springAnimation: Animation? {
        guard enableAnimations else { return nil }
        return effectiveReduceMotion ? .linear(duration: 0.2) : .spring(response: 0.3, dampingFraction: 0.7)
    }
    
    /// Quick animation for small changes
    var quickAnimation: Animation? {
        guard enableAnimations else { return nil }
        return effectiveReduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.15)
    }
    
    /// Slow animation for emphasis
    var slowAnimation: Animation? {
        guard enableAnimations else { return nil }
        return effectiveReduceMotion ? .linear(duration: 0.3) : .easeInOut(duration: 0.5)
    }
    
    /// Opacity for overlays (respects reduce transparency)
    var overlayOpacity: Double {
        Self.systemReduceTransparency ? 0.95 : 0.8
    }
    
    /// Background opacity for cards and panels
    var backgroundOpacity: Double {
        Self.systemReduceTransparency ? 1.0 : 0.95
    }
    
    /// Whether to use increased contrast colors
    var shouldIncreaseContrast: Bool {
        Self.systemIncreaseContrast
    }
    
    /// Spacing for layouts based on compact mode
    var spacing: CGFloat {
        compactMode ? 8 : 16
    }
    
    /// Padding for layouts based on compact mode
    var padding: CGFloat {
        compactMode ? 8 : 12
    }
    
    /// Card padding based on compact mode
    var cardPadding: CGFloat {
        compactMode ? 12 : 16
    }
    
    /// Initialize from UserDefaults
    init() {
        self.enableAnimations = UserDefaults.standard.bool(forKey: "enableAnimations")
        self.reduceMotion = UserDefaults.standard.bool(forKey: "reduceMotion")
        self.showLoadingIndicators = UserDefaults.standard.bool(forKey: "showLoadingIndicators")
        self.compactMode = UserDefaults.standard.bool(forKey: "compactMode")
        self.showEmptyStateIllustrations = UserDefaults.standard.bool(forKey: "showEmptyStateIllustrations")
        
        // Set defaults if not yet configured
        if !UserDefaults.standard.bool(forKey: "hasConfiguredAnimationPreferences") {
            UserDefaults.standard.set(true, forKey: "enableAnimations")
            UserDefaults.standard.set(false, forKey: "reduceMotion")
            UserDefaults.standard.set(true, forKey: "showLoadingIndicators")
            UserDefaults.standard.set(false, forKey: "compactMode")
            UserDefaults.standard.set(true, forKey: "showEmptyStateIllustrations")
            UserDefaults.standard.set(true, forKey: "hasConfiguredAnimationPreferences")
            
            self.enableAnimations = true
            self.reduceMotion = false
            self.showLoadingIndicators = true
            self.compactMode = false
            self.showEmptyStateIllustrations = true
        }
    }
}

/// Environment key for animation preferences
struct AnimationPreferencesKey: EnvironmentKey {
    static let defaultValue = AnimationPreferences()
}

extension EnvironmentValues {
    var animationPreferences: AnimationPreferences {
        get { self[AnimationPreferencesKey.self] }
        set { self[AnimationPreferencesKey.self] = newValue }
    }
}

// MARK: - View Modifiers

/// View modifier that applies animation preferences
struct AnimatedModifier<V: Equatable>: ViewModifier {
    @AppStorage("enableAnimations") private var enableAnimations = true
    @AppStorage("reduceMotion") private var reduceMotion = false
    
    let value: V
    let animation: Animation
    
    /// Check if reduce motion is enabled (app OR system)
    private var effectiveReduceMotion: Bool {
        reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    
    func body(content: Content) -> some View {
        content.animation(
            enableAnimations ? (effectiveReduceMotion ? .linear(duration: 0.2) : animation) : nil,
            value: value
        )
    }
}

extension View {
    /// Apply animation based on user preferences
    func animated<V: Equatable>(_ animation: Animation = .smooth, value: V) -> some View {
        self.modifier(AnimatedModifier(value: value, animation: animation))
    }
}
