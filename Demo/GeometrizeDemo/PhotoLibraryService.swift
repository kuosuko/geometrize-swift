import Foundation
import Photos
import SwiftUI

/// Thin wrapper over `PHPhotoLibrary` and `PHCachingImageManager` for the gallery & detail screens.
@MainActor
final class PhotoLibraryService: ObservableObject {
    @Published var status: PHAuthorizationStatus = .notDetermined
    @Published var assets: [PHAsset] = []

    private let imageManager = PHCachingImageManager()
    private let thumbnailOptions: PHImageRequestOptions = {
        let o = PHImageRequestOptions()
        o.deliveryMode = .opportunistic
        o.isSynchronous = false
        o.resizeMode = .fast
        o.isNetworkAccessAllowed = true
        return o
    }()
    private let fullOptions: PHImageRequestOptions = {
        let o = PHImageRequestOptions()
        o.deliveryMode = .highQualityFormat
        o.isSynchronous = false
        o.resizeMode = .exact
        o.isNetworkAccessAllowed = true
        return o
    }()

    init() {
        self.status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            Task { await refresh() }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshStatus() }
        }
    }

    /// Re-read the authorization status (called when the app becomes active so changes made in
    /// Settings, or via `simctl privacy`, propagate without a full app restart).
    func refreshStatus() {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current != status {
            status = current
            if current == .authorized || current == .limited {
                Task { await refresh() }
            }
        }
    }

    func requestAccess() async {
        let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        self.status = newStatus
        if newStatus == .authorized || newStatus == .limited {
            await refresh()
        }
    }

    func refresh() async {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 300
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var collected: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in collected.append(asset) }
        self.assets = collected
    }

    func thumbnail(for asset: PHAsset, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: thumbnailOptions
        ) { image, _ in completion(image) }
    }

    func fullImage(for asset: PHAsset, maxDimension: CGFloat, completion: @escaping (UIImage?) -> Void) {
        let scale = UIScreen.main.scale
        let size = CGSize(width: maxDimension * scale, height: maxDimension * scale)
        imageManager.requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFit,
            options: fullOptions
        ) { image, _ in completion(image) }
    }
}

extension PHAsset: @retroactive Identifiable {
    public var id: String { localIdentifier }
}
