import SwiftUI

@main
struct GeometrizeDemoApp: App {
    @StateObject private var photos = PhotoLibraryService()
    @StateObject private var toasts = ToastCenter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(photos)
                .environmentObject(toasts)
        }
    }
}
