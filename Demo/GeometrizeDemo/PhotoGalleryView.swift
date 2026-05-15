import SwiftUI
import Photos

/// Photos.app-style picker: 3-column square grid, tight 1.5pt gaps, no per-tile chrome,
/// system large title, pull-to-refresh, dark-mode safe.
///
/// The cells defer to content — that's the iOS pattern. No card borders, no shadows,
/// no per-tile labels. The image IS the affordance.
struct PhotoGalleryView: View {
    @EnvironmentObject var photos: PhotoLibraryService
    @EnvironmentObject var toasts: ToastCenter
    @State private var selected: PHAsset?

    // 3 columns, 1.5pt gaps — matches Photos.app rhythm.
    private let columns = [
        GridItem(.flexible(), spacing: 1.5),
        GridItem(.flexible(), spacing: 1.5),
        GridItem(.flexible(), spacing: 1.5)
    ]

    var body: some View {
        ScrollView {
            if photos.assets.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 1.5) {
                    ForEach(photos.assets) { asset in
                        Button { selected = asset } label: {
                            ThumbnailTile(asset: asset)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1.5)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemBackground))
        .scrollIndicators(.hidden)
        .navigationTitle("Photos")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $selected) { asset in
            EditView(asset: asset)
                .environmentObject(photos)
                .environmentObject(toasts)
        }
        .refreshable { await photos.refresh() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No photos")
                .font(.title3.weight(.semibold))
            Text("Add a photo to your library to start.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }
}

/// A single square thumbnail. Aspect-ratio'd to 1:1, system fill while loading, no border.
private struct ThumbnailTile: View {
    let asset: PHAsset
    @EnvironmentObject var photos: PhotoLibraryService
    @State private var image: UIImage?
    @State private var didRequest = false

    var body: some View {
        Color(.tertiarySystemFill)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .contentShape(Rectangle())
            .onAppear { request() }
    }

    private func request() {
        guard !didRequest else { return }
        didRequest = true
        let scale = UIScreen.main.scale
        photos.thumbnail(for: asset, targetSize: CGSize(width: 180 * scale, height: 180 * scale)) { img in
            Task { @MainActor in self.image = img }
        }
    }
}
