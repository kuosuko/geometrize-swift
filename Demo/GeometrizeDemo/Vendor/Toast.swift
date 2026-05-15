import SwiftUI

/// Small iOS-native toast — a capsule with optional SF Symbol and short title that drops in
/// from the top of the screen and auto-dismisses. Attach via `.toasts(center)` on a root view.
struct Toast: Identifiable, Equatable {
    let id = UUID()
    var symbol: String?
    var title: String
    var subtitle: String?
    var duration: TimeInterval = 2.0
}

@MainActor
final class ToastCenter: ObservableObject {
    @Published var current: Toast?

    func show(_ toast: Toast) {
        current = toast
        let id = toast.id
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(toast.duration * 1_000_000_000))
            await MainActor.run {
                if self?.current?.id == id { self?.current = nil }
            }
        }
    }
}

struct ToastOverlay: View {
    @ObservedObject var center: ToastCenter
    var body: some View {
        VStack {
            if let toast = center.current {
                HStack(spacing: 10) {
                    if let symbol = toast.symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(toast.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        if let subtitle = toast.subtitle {
                            Text(subtitle)
                                .font(.caption2)
                                .foregroundStyle(Theme.inkMuted)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.10), radius: 16, y: 6)
                )
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(toast.id)
            }
            Spacer()
        }
        .animation(.spring(duration: 0.35), value: center.current)
        .allowsHitTesting(false)
    }
}

extension View {
    func toasts(_ center: ToastCenter) -> some View {
        overlay(alignment: .top) { ToastOverlay(center: center) }
    }
}
