import Foundation

enum ShootWindowMode: String, CaseIterable, Identifiable {
    case now
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .now:
            return "Now"
        case .custom:
            return "Custom"
        }
    }
}

enum OutputIntent: String, CaseIterable, Identifiable {
    case instagramCarousel
    case reel
    case heroShot
    case travelBlogSet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .instagramCarousel:
            return "Instagram Carousel"
        case .reel:
            return "90s Reel"
        case .heroShot:
            return "Single Hero Shot"
        case .travelBlogSet:
            return "Travel Blog Set"
        }
    }

    var promptLabel: String {
        switch self {
        case .instagramCarousel:
            return "Instagram carousel"
        case .reel:
            return "90-second reel"
        case .heroShot:
            return "single hero shot"
        case .travelBlogSet:
            return "travel blog set"
        }
    }

    var defaultShotCount: Int {
        switch self {
        case .heroShot:
            return 6
        case .travelBlogSet:
            return 12
        case .instagramCarousel, .reel:
            return 8
        }
    }
}