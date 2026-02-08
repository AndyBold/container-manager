//
//  LoadingIndicator.swift
//  container-manager
//
//  Loading indicator component with animation preferences support
//

import SwiftUI
import AppKit

/// A reusable loading indicator that respects user preferences
struct LoadingIndicator: View {
    let message: String?
    let size: Size
    
    @AppStorage("enableAnimations") private var enableAnimations = true
    @AppStorage("showLoadingIndicators") private var showLoadingIndicators = true
    @AppStorage("reduceMotion") private var reduceMotion = false
    @AppStorage("compactMode") private var compactMode = false
    
    enum Size {
        case small
        case medium
        case large
        
        var dimension: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 24
            case .large: return 32
            }
        }
        
        var fontSize: Font {
            switch self {
            case .small: return .caption
            case .medium: return .body
            case .large: return .title3
            }
        }
    }
    
    init(message: String? = nil, size: Size = .medium) {
        self.message = message
        self.size = size
    }
    
    // Effective reduce motion (app OR system)
    private var effectiveReduceMotion: Bool {
        reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    
    var body: some View {
        if showLoadingIndicators {
            HStack(spacing: compactMode ? 6 : 8) {
                ProgressView()
                    .scaleEffect(effectiveReduceMotion ? 0.8 : 1.0)
                    .controlSize(size == .small ? .small : (size == .large ? .large : .regular))
                
                if let message = message {
                    Text(message)
                        .font(size.fontSize)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// A loading overlay that can be placed over content
struct LoadingOverlay: View {
    let isLoading: Bool
    let message: String?
    
    @AppStorage("enableAnimations") private var enableAnimations = true
    @AppStorage("reduceMotion") private var reduceMotion = false
    @AppStorage("compactMode") private var compactMode = false
    
    init(isLoading: Bool, message: String? = "Loading...") {
        self.isLoading = isLoading
        self.message = message
    }
    
    // Effective reduce motion (app OR system)
    private var effectiveReduceMotion: Bool {
        reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    
    // Animation based on preferences
    private var defaultAnimation: Animation? {
        guard enableAnimations else { return nil }
        return effectiveReduceMotion ? .linear(duration: 0.2) : .smooth
    }
    
    var body: some View {
        if isLoading {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: compactMode ? 12 : 16) {
                    ProgressView()
                        .scaleEffect(effectiveReduceMotion ? 1.2 : 1.5)
                        .controlSize(.large)
                    
                    if let message = message {
                        Text(message)
                            .font(compactMode ? .body : .title3)
                            .foregroundStyle(.white)
                    }
                }
                .padding(compactMode ? 24 : 32)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .transition(.opacity)
            .animation(defaultAnimation, value: isLoading)
        }
    }
}

/// View modifier to show loading state
struct LoadingModifier: ViewModifier {
    let isLoading: Bool
    let message: String?
    
    func body(content: Content) -> some View {
        content
            .overlay {
                LoadingOverlay(isLoading: isLoading, message: message)
            }
    }
}

extension View {
    /// Adds a loading overlay to the view
    func loading(_ isLoading: Bool, message: String? = "Loading...") -> some View {
        self.modifier(LoadingModifier(isLoading: isLoading, message: message))
    }
}

// MARK: - Inline Loading State

/// Shows loading state inline with content (useful for buttons, menus, etc.)
struct InlineLoadingView: View {
    let isLoading: Bool
    let text: String
    let loadingText: String?
    
    @AppStorage("showLoadingIndicators") private var showLoadingIndicators = true
    @AppStorage("compactMode") private var compactMode = false
    
    init(isLoading: Bool, text: String, loadingText: String? = nil) {
        self.isLoading = isLoading
        self.text = text
        self.loadingText = loadingText
    }
    
    var body: some View {
        if isLoading && showLoadingIndicators {
            HStack(spacing: compactMode ? 6 : 8) {
                ProgressView()
                    .scaleEffect(0.8)
                    .controlSize(.small)
                Text(loadingText ?? text)
            }
        } else {
            Text(text)
        }
    }
}

// MARK: - Preview

#Preview("Loading Indicator Sizes") {
    VStack(spacing: 24) {
        LoadingIndicator(message: "Small", size: .small)
        LoadingIndicator(message: "Medium", size: .medium)
        LoadingIndicator(message: "Large", size: .large)
        LoadingIndicator(size: .medium)
    }
    .padding()
}

#Preview("Loading Overlay") {
    VStack {
        Text("Content behind overlay")
            .font(.title)
    }
    .frame(width: 400, height: 300)
    .loading(true, message: "Processing...")
}

#Preview("Inline Loading") {
    VStack(spacing: 16) {
        Button {
        } label: {
            InlineLoadingView(isLoading: false, text: "Not Loading")
        }
        
        Button {
        } label: {
            InlineLoadingView(isLoading: true, text: "Start", loadingText: "Starting...")
        }
        .disabled(true)
    }
    .padding()
}
