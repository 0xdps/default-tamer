//
//  ToastManager.swift
//  Default Tamer
//
//  Manages temporary notification toasts for user feedback
//

import Foundation
import SwiftUI

@MainActor
class ToastManager: ObservableObject {
    @Published var currentToast: Toast?
    
    static let shared = ToastManager()
    
    private init() {}
    
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let style: Style
        let duration: TimeInterval
        let icon: String
        
        enum Style {
            case info
            case success
            case warning
            case error
            
            var color: Color {
                switch self {
                case .info:
                    return .blue
                case .success:
                    return .green
                case .warning:
                    return .orange
                case .error:
                    return .red
                }
            }
            
            var backgroundColor: Color {
                switch self {
                case .info:
                    return Color.blue.opacity(0.1)
                case .success:
                    return Color.green.opacity(0.1)
                case .warning:
                    return Color.orange.opacity(0.1)
                case .error:
                    return Color.red.opacity(0.1)
                }
            }
            
            var defaultIcon: String {
                switch self {
                case .info:
                    return "info.circle.fill"
                case .success:
                    return "checkmark.circle.fill"
                case .warning:
                    return "exclamationmark.triangle.fill"
                case .error:
                    return "xmark.circle.fill"
                }
            }
        }
        
        static func == (lhs: Toast, rhs: Toast) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    /// Show a toast notification
    func show(
        _ message: String,
        style: Toast.Style = .info,
        duration: TimeInterval = 3.0,
        icon: String? = nil
    ) {
        let toast = Toast(
            message: message,
            style: style,
            duration: duration,
            icon: icon ?? style.defaultIcon
        )
        
        currentToast = toast
        debugLog("🔔 Toast: \(message)")
        
        // Auto-dismiss after duration
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if currentToast?.id == toast.id {
                withAnimation {
                    currentToast = nil
                }
            }
        }
    }
    
    /// Manually dismiss the current toast
    func dismiss() {
        withAnimation {
            currentToast = nil
        }
    }
    
    // Convenience methods for common toast types
    
    func info(_ message: String, duration: TimeInterval = 3.0) {
        show(message, style: .info, duration: duration)
    }
    
    func success(_ message: String, duration: TimeInterval = 2.5) {
        show(message, style: .success, duration: duration)
    }
    
    func warning(_ message: String, duration: TimeInterval = 3.5) {
        show(message, style: .warning, duration: duration)
    }
    
    func error(_ message: String, duration: TimeInterval = 4.0) {
        show(message, style: .error, duration: duration)
    }
}

// MARK: - Toast View

struct ToastView: View {
    let toast: ToastManager.Toast
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.icon)
                .font(.title3)
                .foregroundColor(toast.style.color)
            
            Text(toast.message)
                .font(.callout)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer(minLength: 0)
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(toast.style.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(toast.style.color.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .frame(minWidth: UIConstants.toastMinWidth, maxWidth: UIConstants.toastMaxWidth)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Toast Overlay Modifier

struct ToastOverlay: ViewModifier {
    @ObservedObject var toastManager: ToastManager
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            VStack {
                if let toast = toastManager.currentToast {
                    ToastView(toast: toast) {
                        toastManager.dismiss()
                    }
                    .padding(.top, 12)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: toastManager.currentToast)
                }
                
                Spacer()
            }
        }
    }
}

extension View {
    /// Apply toast overlay to any view
    func toastOverlay(manager: ToastManager = .shared) -> some View {
        modifier(ToastOverlay(toastManager: manager))
    }
}
