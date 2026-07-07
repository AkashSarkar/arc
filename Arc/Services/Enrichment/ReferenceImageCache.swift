import Foundation

protocol ReferenceImageCaching {
    func cacheReferenceImages(for location: Stop) async -> ReferenceImageCacheResult
    func cacheStatus(for location: Stop) -> ReferenceImageCacheResult
}

struct ReferenceImageCacheResult {
    let totalImages: Int
    let cachedImages: Int
}

struct DiskReferenceImageCache: ReferenceImageCaching {
    private let fileManager: FileManager
    private let urlSession: URLSession

    init(
        fileManager: FileManager = .default,
        urlSession: URLSession = .shared
    ) {
        self.fileManager = fileManager
        self.urlSession = urlSession
    }

    func cacheReferenceImages(for location: Stop) async -> ReferenceImageCacheResult {
        guard let imageTargets = imageTargets(for: location) else {
            return ReferenceImageCacheResult(totalImages: 0, cachedImages: 0)
        }

        guard !imageTargets.isEmpty else {
            return ReferenceImageCacheResult(totalImages: 0, cachedImages: 0)
        }

        let cacheDirectory = referenceImageDirectory(for: location.id)
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            return ReferenceImageCacheResult(totalImages: imageTargets.count, cachedImages: 0)
        }

        var cachedImages = 0

        for target in imageTargets {
            let fileURL = cacheDirectory.appending(path: fileName(for: target.id, sourceURL: target.url))

            if fileManager.fileExists(atPath: fileURL.path()) {
                cachedImages += 1
                continue
            }

            do {
                let (data, response) = try await urlSession.data(from: target.url)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode),
                      !data.isEmpty
                else {
                    continue
                }

                try data.write(to: fileURL, options: .atomic)
                cachedImages += 1
            } catch {
                continue
            }
        }

        return ReferenceImageCacheResult(totalImages: imageTargets.count, cachedImages: cachedImages)
    }

    func cacheStatus(for location: Stop) -> ReferenceImageCacheResult {
        guard let imageTargets = imageTargets(for: location) else {
            return ReferenceImageCacheResult(totalImages: 0, cachedImages: 0)
        }

        guard !imageTargets.isEmpty else {
            return ReferenceImageCacheResult(totalImages: 0, cachedImages: 0)
        }

        let cacheDirectory = referenceImageDirectory(for: location.id)
        var cachedImages = 0

        for target in imageTargets {
            let fileURL = cacheDirectory.appending(path: fileName(for: target.id, sourceURL: target.url))
            if fileManager.fileExists(atPath: fileURL.path()) {
                cachedImages += 1
            }
        }

        return ReferenceImageCacheResult(totalImages: imageTargets.count, cachedImages: cachedImages)
    }

    private func imageTargets(for location: Stop) -> [(id: String, url: URL)]? {
        guard let contextBundle = LocationContextBundle.decode(from: location.enrichmentJSON) else {
            return nil
        }

        return contextBundle.referenceImages.compactMap { referenceImage -> (id: String, url: URL)? in
            guard let imageURLString = referenceImage.imageURLString,
                  let url = URL(string: imageURLString)
            else {
                return nil
            }

            return (id: referenceImage.id, url: url)
        }
    }

    private func referenceImageDirectory(for locationID: UUID) -> URL {
        let baseDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        return baseDirectory
            .appending(path: "Arc")
            .appending(path: "ReferenceImages")
            .appending(path: locationID.uuidString.lowercased())
    }

    private func fileName(for imageID: String, sourceURL: URL) -> String {
        let extensionCandidate = sourceURL.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileExtension = extensionCandidate.isEmpty ? "jpg" : extensionCandidate
        return "\(imageID).\(fileExtension)"
    }
}
