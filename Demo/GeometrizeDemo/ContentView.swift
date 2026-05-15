import SwiftUI

/// Root router: onboarding until photo permission is granted, then the gallery.
struct ContentView: View {
    @EnvironmentObject var photos: PhotoLibraryService
    @EnvironmentObject var toasts: ToastCenter

    var body: some View {
        Group {
            if photos.status == .authorized || photos.status == .limited {
                NavigationStack {
                    PhotoGalleryView()
                }
                .tint(Theme.ink)
            } else {
                OnboardingView()
            }
        }
        .toasts(toasts)
    }
}
