import SwiftUI

/// Welcome screen. One hero image, one serif headline, one short paragraph, one CTA.
/// That's the whole screen — disciplined, no decorative noise.
struct OnboardingView: View {
    @EnvironmentObject var photos: PhotoLibraryService

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                hero
                Spacer(minLength: 28)
                copy
                Spacer()
                cta
                Spacer(minLength: 36)
            }
            .padding(.horizontal, 28)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        // Bundled AI-generated illustration: a person reconstructed from geometric primitives.
        // Lives in Assets.xcassets/OnboardingHero. Square, rendered as a soft-cornered card.
        Image("OnboardingHero")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 320)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.black.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 28, x: 0, y: 14)
    }

    // MARK: - Copy

    private var copy: some View {
        VStack(spacing: 10) {
            Text("Turn photos\ninto shapes.")
                .font(Theme.title(34))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Text("Geometrize redraws any image as a stack of colored primitives — the same algorithm Sam Twidale's library uses, now native on iOS.")
                .font(Theme.body(15))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - CTA

    private var cta: some View {
        VStack(spacing: 12) {
            Button {
                Task { await photos.requestAccess() }
            } label: {
                Text(buttonTitle)
                    .font(.headline)
                    .foregroundStyle(Theme.canvas)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        Capsule().fill(Theme.ink)
                    )
            }
            .buttonStyle(.plain)

            if photos.status == .denied || photos.status == .restricted {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.inkMuted)
                }
            } else {
                Text("Photos stay on your device.")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSubtle)
            }
        }
    }

    private var buttonTitle: String {
        switch photos.status {
        case .notDetermined: return "Connect Photos"
        case .denied, .restricted: return "Photos Access Needed"
        default: return "Continue"
        }
    }
}

#Preview("Onboarding") {
    OnboardingView()
        .environmentObject(PhotoLibraryService())
}
