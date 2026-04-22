import Foundation

enum ShootWindowMode: String, CaseIterable, Identifiable {
    case now
    case custom

    nonisolated var id: String { rawValue }

    nonisolated var title: String {
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
    case fullTravelVlog
    case bRollPackage
    case portraitSession
    case productEditorial
    case documentarySequence

    nonisolated var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .instagramCarousel:
            return "Photo Carousel"
        case .reel:
            return "Short Video"
        case .heroShot:
            return "Single Hero Shot"
        case .travelBlogSet:
            return "Travel Story Set"
        case .fullTravelVlog:
            return "Full Travel Vlog"
        case .bRollPackage:
            return "B-Roll Package"
        case .portraitSession:
            return "Portrait Session"
        case .productEditorial:
            return "Product Editorial"
        case .documentarySequence:
            return "Documentary Sequence"
        }
    }

    nonisolated var promptLabel: String {
        switch self {
        case .instagramCarousel:
            return "social photo carousel"
        case .reel:
            return "short-form vertical video"
        case .heroShot:
            return "single hero shot"
        case .travelBlogSet:
            return "travel photo story"
        case .fullTravelVlog:
            return "full travel vlog"
        case .bRollPackage:
            return "B-roll package"
        case .portraitSession:
            return "portrait session"
        case .productEditorial:
            return "product or object editorial set"
        case .documentarySequence:
            return "documentary sequence"
        }
    }

    nonisolated var defaultShotCount: Int {
        switch self {
        case .heroShot:
            return 6
        case .fullTravelVlog:
            return 16
        case .bRollPackage:
            return 14
        case .travelBlogSet, .documentarySequence:
            return 12
        case .portraitSession, .productEditorial:
            return 10
        case .instagramCarousel, .reel:
            return 8
        }
    }

    nonisolated var defaultCaptureMedium: CaptureMedium {
        switch self {
        case .instagramCarousel, .heroShot, .travelBlogSet, .portraitSession, .productEditorial:
            return .photo
        case .reel, .fullTravelVlog, .bRollPackage, .documentarySequence:
            return .video
        }
    }

    nonisolated var defaultTargetPlatform: TargetPlatform {
        switch self {
        case .instagramCarousel, .reel:
            return .instagram
        case .fullTravelVlog:
            return .youtube
        case .travelBlogSet:
            return .websiteBlog
        case .heroShot, .portraitSession, .productEditorial:
            return .portfolio
        case .bRollPackage, .documentarySequence:
            return .clientDelivery
        }
    }
}

enum CaptureMedium: String, CaseIterable, Identifiable {
    case photo
    case video
    case hybrid

    nonisolated var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .photo:
            return "Photo"
        case .video:
            return "Video"
        case .hybrid:
            return "Photo + Video"
        }
    }

    nonisolated var promptDirective: String {
        switch self {
        case .photo:
            return "Plan still-image coverage. Emphasize composition, lens choice, timing, and sequence variety."
        case .video:
            return "Plan video coverage. Emphasize motion, camera movement, transition shots, audio or ambient moments, and edit rhythm."
        case .hybrid:
            return "Plan combined photo and video coverage. Balance still hero frames with motion clips and reusable transitions."
        }
    }
}

enum TargetPlatform: String, CaseIterable, Identifiable {
    case instagram
    case tiktok
    case youtube
    case websiteBlog
    case portfolio
    case clientDelivery
    case personalArchive

    nonisolated var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .instagram:
            return "Instagram"
        case .tiktok:
            return "TikTok"
        case .youtube:
            return "YouTube"
        case .websiteBlog:
            return "Website / Blog"
        case .portfolio:
            return "Portfolio"
        case .clientDelivery:
            return "Client Delivery"
        case .personalArchive:
            return "Personal Archive"
        }
    }

    nonisolated var promptDirective: String {
        switch self {
        case .instagram:
            return "Optimize for visual hooks, clean crops, vertical-friendly alternates, and fast scanning."
        case .tiktok:
            return "Optimize for vertical video, immediate hooks, movement, and short attention spans."
        case .youtube:
            return "Optimize for narrative continuity, establishing context, B-roll coverage, and longer edit structure."
        case .websiteBlog:
            return "Optimize for story coverage, environmental context, detail images, and readable sequencing."
        case .portfolio:
            return "Optimize for polished hero frames, variety, and technical quality over volume."
        case .clientDelivery:
            return "Optimize for completeness, coverage variety, and clear practical deliverables."
        case .personalArchive:
            return "Optimize for memory, place, detail, and a coherent record of the experience."
        }
    }
}

extension OutputIntent {
    nonisolated init(storedValue: String) {
        self = OutputIntent(rawValue: storedValue) ?? .instagramCarousel
    }
}

enum CaptureStylePreset: String, CaseIterable, Identifiable {
    case natural
    case cinematic
    case minimal
    case editorial
    case socialReel
    case moodyTravel

    nonisolated var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .natural:
            return "Natural"
        case .cinematic:
            return "Cinematic"
        case .minimal:
            return "Minimal"
        case .editorial:
            return "Editorial"
        case .socialReel:
            return "Social Reel"
        case .moodyTravel:
            return "Moody Travel"
        }
    }

    nonisolated var promptDirective: String {
        switch self {
        case .natural:
            return "Natural and grounded. Prioritize truthful location coverage, usable light, and practical shot sequencing."
        case .cinematic:
            return "Cinematic. Prioritize depth, motion, foreground layers, atmosphere, and wide-to-tight visual rhythm."
        case .minimal:
            return "Minimal. Prioritize clean geometry, negative space, restrained detail, and simple compositions."
        case .editorial:
            return "Editorial. Prioritize a polished magazine-style set with variety, visual contrast, and intentional details."
        case .socialReel:
            return "Social reel. Prioritize hooks, movement, transitions, close details, and shots that cut together quickly."
        case .moodyTravel:
            return "Moody travel. Prioritize atmosphere, weather, texture, solitude, silhouettes, and quiet narrative progression."
        }
    }
}
