import MapKit
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct FieldView: View {
    let trip: Trip
    let aiService: any AIServicing
    let locationEnricher: any LocationEnriching
    let referenceImageCache: any ReferenceImageCaching
    let locationEditorServices: LocationEditorServiceFactory

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("Arc.FieldHighContrastMode") private var isHighContrastMode = false
    @State private var selectedStopID: UUID?
    @State private var cacheStatus = ReferenceImageCacheResult(totalImages: 0, cachedImages: 0)
    @State private var isPresentingInfo = false
    @State private var isPresentingPlanEditor = false
    @State private var isPresentingEditLocation = false
    @State private var isPresentingSafetyNet = false
    @State private var isConfirmingDelete = false
    @State private var isConfirmingFinish = false
    @State private var isConfirmingStageAdvance = false
    @State private var pendingStageOrderIndex: Int?
    @State private var hasDismissedCompletionPrompt = false
    @State private var photoAttachmentError: String?
    @State private var editingNoteItem: CaptureItem?

    private var orderedStops: [Stop] {
        trip.orderedStops
    }

    private var selectedStop: Stop? {
        if let selectedStopID,
           let stop = orderedStops.first(where: { $0.id == selectedStopID }) {
            return stop
        }

        return trip.activeStop
    }

    private var currentStage: Stage? {
        selectedStop?.currentStage
    }

    private var hasPlanItems: Bool {
        !trip.allItems.isEmpty
    }

    private var nextPendingItem: CaptureItem? {
        currentStage?.fieldDisplayItems.first { !$0.isResolved }
    }

    private var completionProgress: Double {
        guard !trip.allItems.isEmpty else {
            return 0
        }

        return Double(trip.resolvedCount) / Double(trip.allItems.count)
    }

    private var shouldShowCompletionPrompt: Bool {
        hasPlanItems && trip.missingCount == 0 && !hasDismissedCompletionPrompt
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                FieldExecutionHeader(
                    trip: trip,
                    stop: selectedStop,
                    stage: currentStage,
                    referenceStatus: referenceStatusText,
                    isHighContrast: isHighContrastMode
                )

                if hasPlanItems {
                    FieldProgressPanel(
                        completedCount: trip.capturedCount,
                        skippedCount: trip.skippedCount,
                        totalCount: trip.allItems.count,
                        remainingCount: trip.missingCount,
                        progress: completionProgress,
                        isHighContrast: isHighContrastMode
                    )
                }

                TripTimelinePanel(
                    stops: orderedStops,
                    selectedStopID: selectedStop?.id,
                    selectStop: selectStop
                )

                TripMapPanel(stops: orderedStops, selectedStopID: selectedStop?.id)

                if let photoAttachmentError {
                    ArcInlineError(message: photoAttachmentError)
                        .padding(.horizontal, 2)
                }

                if hasPlanItems, let stop = selectedStop, let stage = currentStage {
                    FieldStopControls(
                        stop: stop,
                        stage: stage,
                        currentPosition: currentStagePosition(in: stop),
                        totalStages: stop.orderedStages.count,
                        isHighContrast: isHighContrastMode,
                        arriveAction: { arrive(stop) },
                        previousAction: previousStage,
                        nextAction: attemptNextStage,
                        nextStopAction: advanceToNextStop
                    )

                    FieldStageCard(
                        stage: stage,
                        isHighContrast: isHighContrastMode,
                        toggleCaptured: toggleItemCompletion,
                        toggleSkipped: toggleItemSkipped,
                        attachPhoto: attachPhoto,
                        removePhoto: removePhoto,
                        editNote: { editingNoteItem = $0 }
                    )

                    FieldGuidanceCard(
                        trip: trip,
                        stop: stop,
                        stage: stage,
                        isHighContrast: isHighContrastMode
                    )
                } else {
                    FieldPlanRequiredCard()
                }
            }
            .padding(16)
            .padding(.bottom, hasPlanItems ? 112 : 0)
        }
        .background(fieldBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if hasPlanItems {
                fieldActionBar
            }
        }
        .navigationTitle("Field Guide")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isHighContrastMode.toggle()
                    }
                    playImpact(.light)
                } label: {
                    Image(systemName: isHighContrastMode ? "sun.max.fill" : "sun.max")
                }
                .accessibilityLabel(isHighContrastMode ? "Disable high contrast mode" : "Enable high contrast mode")

                if hasPlanItems {
                    Button {
                        isPresentingSafetyNet = true
                    } label: {
                        Image(systemName: "lifepreserver")
                    }
                    .accessibilityLabel("Open story safety net")
                }

                if selectedStop != nil {
                    Button {
                        isPresentingInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("Stop info")
                }

                Button {
                    isPresentingPlanEditor = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit plan")

                Menu {
                    if selectedStop != nil {
                        Button {
                            isPresentingEditLocation = true
                        } label: {
                            Label("Edit Stop Location", systemImage: "slider.horizontal.3")
                        }
                    }

                    Toggle(isOn: $isHighContrastMode) {
                        Label("High Contrast", systemImage: "sun.max")
                    }

                    Button {
                        isConfirmingFinish = true
                    } label: {
                        Label("Complete Trip", systemImage: "checkmark.seal")
                    }
                    .disabled(!hasPlanItems)

                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Delete Trip", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More actions")
            }
        }
        .sheet(isPresented: $isPresentingInfo) {
            if let selectedStop {
                ShootInfoSheet(
                    stop: selectedStop,
                    locationEnricher: locationEnricher,
                    referenceImageCache: referenceImageCache,
                    locationEditorServices: locationEditorServices
                )
            }
        }
        .sheet(isPresented: $isPresentingPlanEditor) {
            PlanEditorSheet(
                trip: trip,
                aiService: aiService,
                locationEnricher: locationEnricher,
                referenceImageCache: referenceImageCache
            )
        }
        .sheet(isPresented: $isPresentingEditLocation) {
            if let selectedStop {
                LocationEditorView(location: selectedStop, services: locationEditorServices) { draft in
                    selectedStop.name = draft.name
                    selectedStop.placeName = draft.name
                    selectedStop.latitude = draft.coordinate.latitude
                    selectedStop.longitude = draft.coordinate.longitude
                    try modelContext.save()
                }
            }
        }
        .sheet(isPresented: $isPresentingSafetyNet) {
            SafetyNetSheet(
                stop: selectedStop,
                addTemplate: addSafetyNetItem
            )
        }
        .sheet(item: $editingNoteItem) { item in
            FieldNoteEditorSheet(item: item) {
                try? modelContext.save()
            }
        }
        .confirmationDialog("Delete this trip?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Trip", role: .destructive) {
                deleteTrip()
            }
            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text("This removes the trip, stops, field guide, and export artifacts.")
        }
        .confirmationDialog("Complete this trip?", isPresented: $isConfirmingFinish, titleVisibility: .visible) {
            Button(trip.isStorySafe ? "Complete Trip" : "Complete Anyway") {
                completeTrip()
            }
            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text(finishDialogMessage)
        }
        .confirmationDialog("Move to the next stage?", isPresented: $isConfirmingStageAdvance, titleVisibility: .visible) {
            Button("Move Anyway") {
                if let pendingStageOrderIndex, let stop = selectedStop {
                    setStage(pendingStageOrderIndex, in: stop)
                }
                pendingStageOrderIndex = nil
            }
            Button("Stay Here", role: .cancel) {
                pendingStageOrderIndex = nil
            }
        } message: {
            Text(stageAdvanceDialogMessage)
        }
        .alert("Photo Could Not Be Attached", isPresented: Binding(
            get: { photoAttachmentError != nil },
            set: { if !$0 { photoAttachmentError = nil } }
        )) {
            Button("OK", role: .cancel) {
                photoAttachmentError = nil
            }
        } message: {
            Text(photoAttachmentError ?? "")
        }
        .alert("Trip coverage complete", isPresented: Binding(
            get: { shouldShowCompletionPrompt },
            set: { if !$0 { hasDismissedCompletionPrompt = true } }
        )) {
            Button("Complete Trip") {
                completeTrip()
            }
            Button("Keep Working", role: .cancel) {
                hasDismissedCompletionPrompt = true
            }
        } message: {
            Text("Every planned item has been captured or skipped. Complete the trip to generate the review script and export guide.")
        }
        .task {
            activateTripIfNeeded()
        }
        .task(id: selectedStop?.id) {
            if let selectedStop {
                cacheStatus = referenceImageCache.cacheStatus(for: selectedStop)
            }
        }
    }

    private var fieldActionBar: some View {
        FieldActionBar(
            primaryTitle: primaryFieldActionTitle,
            primarySubtitle: primaryFieldActionSubtitle,
            isHighContrast: isHighContrastMode,
            primaryAction: performPrimaryFieldAction,
            finishAction: { isConfirmingFinish = true }
        )
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private var fieldBackground: some View {
        Group {
            if isHighContrastMode {
                Color.black.ignoresSafeArea()
            } else {
                ArcSceneBackground()
            }
        }
    }

    private var referenceStatusText: String {
        guard cacheStatus.totalImages > 0 else {
            return "No offline refs"
        }

        return "\(cacheStatus.cachedImages)/\(cacheStatus.totalImages) refs"
    }

    private var finishDialogMessage: String {
        if trip.isStorySafe {
            return "Arc will generate an editing script and a shareable .arcguide export."
        }

        return "\(trip.resolvedMustCount)/\(trip.mustCount) must-get items are resolved. Completing now will still create the review and export artifacts."
    }

    private var stageAdvanceDialogMessage: String {
        guard let stage = currentStage else {
            return "This stage still has unresolved must-get items."
        }

        let titles = stage.unresolvedMustItems.prefix(3).map(\.title).joined(separator: ", ")
        return titles.isEmpty ? "This stage still has unresolved must-get items." : "Unresolved must-get items: \(titles)"
    }

    private var primaryFieldActionTitle: String {
        if trip.missingCount == 0 {
            return "All Items Resolved"
        }

        if nextPendingItem != nil {
            return "Capture Next"
        }

        guard let stop = selectedStop else {
            return "Find Remaining"
        }

        let currentPosition = currentStagePosition(in: stop)
        return currentPosition + 1 >= stop.orderedStages.count ? "Next Stop" : "Next Stage"
    }

    private var primaryFieldActionSubtitle: String {
        if let nextPendingItem {
            return nextPendingItem.title
        }

        if trip.missingCount == 0 {
            return "Ready to complete"
        }

        if let nextUnresolvedItem = trip.allItems.first(where: { !$0.isResolved }) {
            return nextUnresolvedItem.title
        }

        return "Keep the guide moving"
    }

    private func activateTripIfNeeded() {
        if trip.status == .planning {
            trip.status = .active
        }

        if selectedStopID == nil {
            selectedStopID = trip.activeStop?.id
        }

        if orderedStops.allSatisfy({ $0.status == .upcoming }), let first = orderedStops.first {
            first.status = .active
            first.arrivedAt = first.arrivedAt ?? Date()
            selectedStopID = first.id
        }

        try? modelContext.save()
    }

    private func selectStop(_ stop: Stop) {
        selectedStopID = stop.id
        if trip.status == .planning {
            trip.status = .active
        }

        if stop.status == .upcoming {
            stop.status = .active
            stop.arrivedAt = stop.arrivedAt ?? Date()
        }

        try? modelContext.save()
        playImpact(.light)
    }

    private func currentStagePosition(in stop: Stop) -> Int {
        guard let currentStage = stop.currentStage else {
            return 0
        }

        return stop.orderedStages.firstIndex { $0.id == currentStage.id } ?? 0
    }

    private func arrive(_ stop: Stop) {
        stop.status = .active
        stop.arrivedAt = stop.arrivedAt ?? Date()
        selectedStopID = stop.id
        try? modelContext.save()
        playImpact(.medium)
    }

    private func previousStage() {
        guard let stop = selectedStop else {
            return
        }

        let stages = stop.orderedStages
        let index = currentStagePosition(in: stop)
        guard index > 0 else {
            return
        }

        setStage(stages[index - 1].orderIndex, in: stop)
    }

    private func attemptNextStage() {
        guard let stop = selectedStop else {
            return
        }

        let stages = stop.orderedStages
        let index = currentStagePosition(in: stop)
        guard index + 1 < stages.count else {
            advanceToNextStop()
            return
        }

        let nextOrderIndex = stages[index + 1].orderIndex
        if let currentStage, !currentStage.unresolvedMustItems.isEmpty {
            pendingStageOrderIndex = nextOrderIndex
            isConfirmingStageAdvance = true
            return
        }

        setStage(nextOrderIndex, in: stop)
    }

    private func setStage(_ orderIndex: Int, in stop: Stop) {
        stop.currentStageOrderIndex = orderIndex
        try? modelContext.save()
        playImpact(.light)
    }

    private func advanceToNextStop() {
        guard let stop = selectedStop,
              let index = orderedStops.firstIndex(where: { $0.id == stop.id })
        else {
            return
        }

        stop.status = .done
        stop.departedAt = stop.departedAt ?? Date()

        if index + 1 < orderedStops.count {
            let nextStop = orderedStops[index + 1]
            nextStop.status = .active
            nextStop.arrivedAt = nextStop.arrivedAt ?? Date()
            selectedStopID = nextStop.id
        }

        try? modelContext.save()
        playImpact(.medium)
    }

    private func toggleItemCompletion(_ item: CaptureItem) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            item.isCaptured.toggle()
            item.capturedAt = item.isCaptured ? Date() : nil
            if item.isCaptured {
                item.isSkipped = false
                item.skippedAt = nil
            }
        }

        try? modelContext.save()
        playImpact(.light)
    }

    private func markItemCaptured(_ item: CaptureItem) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            item.isCaptured = true
            item.capturedAt = item.capturedAt ?? Date()
            item.isSkipped = false
            item.skippedAt = nil
        }

        try? modelContext.save()
        playImpact(.light)
    }

    private func toggleItemSkipped(_ item: CaptureItem) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            item.isSkipped.toggle()
            item.skippedAt = item.isSkipped ? Date() : nil
            if item.isSkipped {
                item.isCaptured = false
                item.capturedAt = nil
            }
        }

        try? modelContext.save()
        playImpact(.light)
    }

    private func performPrimaryFieldAction() {
        guard let nextPendingItem else {
            guard trip.missingCount > 0 else {
                isConfirmingFinish = true
                return
            }

            moveToNextUnresolvedScope()
            return
        }

        let capturedStage = nextPendingItem.stage
        markItemCaptured(nextPendingItem)

        if let capturedStage,
           capturedStage.missingItems.isEmpty,
           trip.missingCount > 0 {
            moveForwardAfterClearedStage(capturedStage)
        }
    }

    private func moveForwardAfterClearedStage(_ stage: Stage) {
        guard let stop = stage.stop,
              selectedStop?.id == stop.id
        else {
            moveToNextUnresolvedScope()
            return
        }

        let stages = stop.orderedStages
        guard let index = stages.firstIndex(where: { $0.id == stage.id }) else {
            moveToNextUnresolvedScope()
            return
        }

        if index + 1 < stages.count {
            setStage(stages[index + 1].orderIndex, in: stop)
            return
        }

        advanceToNextStop()
    }

    private func moveToNextUnresolvedScope() {
        guard let nextUnresolvedItem = trip.allItems.first(where: { !$0.isResolved }) else {
            isConfirmingFinish = true
            return
        }

        if let stop = nextUnresolvedItem.stage?.stop {
            selectStop(stop)
        }

        if let stage = nextUnresolvedItem.stage,
           let stop = stage.stop {
            setStage(stage.orderIndex, in: stop)
        }
    }

    private func attachPhoto(_ pickerItem: PhotosPickerItem?, to item: CaptureItem) {
        guard let pickerItem else {
            return
        }

        Task { @MainActor in
            do {
                guard let data = try await pickerItem.loadTransferable(type: Data.self) else {
                    return
                }

                item.capturedPhotoData = data
                item.capturedPhotoAttachedAt = Date()
                item.isCaptured = true
                item.capturedAt = item.capturedAt ?? Date()
                item.isSkipped = false
                item.skippedAt = nil
                try modelContext.save()
                playImpact(.medium)
            } catch {
                photoAttachmentError = error.localizedDescription
            }
        }
    }

    private func removePhoto(from item: CaptureItem) {
        item.capturedPhotoData = nil
        item.capturedPhotoAttachedAt = nil
        try? modelContext.save()
        playImpact(.light)
    }

    private func addSafetyNetItem(_ template: SafetyNetTemplate) {
        guard let stop = selectedStop else {
            return
        }

        let stage = safetyNetStage(for: stop)
        let normalizedTitle = template.title.lowercased()
        guard !stage.orderedItems.contains(where: { $0.title.lowercased() == normalizedTitle }) else {
            stop.currentStageOrderIndex = stage.orderIndex
            try? modelContext.save()
            return
        }

        let item = CaptureItem(
            orderIndex: stage.orderedItems.count,
            title: template.title,
            guidance: template.guidance,
            kind: template.kind,
            priority: .must,
            isBeforeLeaving: template.kind == .transition,
            origin: .safetyNet,
            stage: stage
        )
        stage.items.append(item)
        stop.currentStageOrderIndex = stage.orderIndex
        try? modelContext.save()
        playImpact(.medium)
    }

    private func safetyNetStage(for stop: Stop) -> Stage {
        if let existing = stop.orderedStages.first(where: { $0.kind == .safetyNet }) {
            return existing
        }

        let stage = Stage(
            orderIndex: stop.orderedStages.count,
            title: "Safety Net",
            goal: "Patch story gaps before leaving the stop.",
            kind: .safetyNet,
            stop: stop
        )
        stop.stages.append(stage)
        return stage
    }

    private func completeTrip() {
        trip.status = .completed
        trip.completedAt = Date()

        if let selectedStop {
            selectedStop.status = .done
            selectedStop.departedAt = selectedStop.departedAt ?? Date()
        }

        _ = TripDocumentMapper.generateScriptArtifact(for: trip)
        try? modelContext.save()
        dismiss()
    }

    private func deleteTrip() {
        modelContext.delete(trip)
        try? modelContext.save()
        dismiss()
    }

    private func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

private struct FieldExecutionHeader: View {
    let trip: Trip
    let stop: Stop?
    let stage: Stage?
    let referenceStatus: String
    let isHighContrast: Bool

    var body: some View {
        ArcHeroHeader(
            systemImage: "camera.viewfinder",
            title: trip.title,
            subtitle: summary,
            badges: badges
        )
        .accessibilityElement(children: .combine)
    }

    private var summary: String {
        if let stop, let stage {
            return "\(stop.name) - \(stage.mantra)"
        }

        return trip.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Work each stop, stage, and must-get item." : trip.summary
    }

    private var badges: [ArcHeroBadge] {
        [
            ArcHeroBadge(label: "\(trip.resolvedCount)/\(trip.allItems.count)", systemImage: "checkmark.circle"),
            ArcHeroBadge(label: "\(trip.orderedStops.count) stops", systemImage: "map"),
            ArcHeroBadge(label: referenceStatus, systemImage: "arrow.down.circle")
        ]
    }
}

private struct FieldProgressPanel: View {
    let completedCount: Int
    let skippedCount: Int
    let totalCount: Int
    let remainingCount: Int
    let progress: Double
    let isHighContrast: Bool

    var body: some View {
        ArcDenseCard(accent: isHighContrast ? .white : ArcPalette.tint) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Field Progress")
                        .font(.headline)
                    Text("\(remainingCount) remaining")
                        .font(.subheadline)
                        .foregroundStyle(isHighContrast ? .white.opacity(0.82) : .secondary)
                }

                Spacer()

                Text("\(completedCount + skippedCount)/\(totalCount)")
                    .font(.title3.monospacedDigit().weight(.semibold))
            }

            FieldProgressBar(progress: progress)
                .frame(height: 8)

            HStack(spacing: 8) {
                ArcStatusPill("\(completedCount) captured", systemImage: "checkmark.circle", tint: isHighContrast ? .white : ArcPalette.tint)
                ArcStatusPill("\(skippedCount) skipped", systemImage: "forward.circle", tint: isHighContrast ? .white.opacity(0.8) : ArcPalette.glowSecondary)
            }
        }
    }
}

private struct TripTimelinePanel: View {
    let stops: [Stop]
    let selectedStopID: UUID?
    let selectStop: (Stop) -> Void

    var body: some View {
        ArcDenseCard(accent: ArcPalette.glowSecondary) {
            ArcFeatureTitle(
                systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                title: "Trip Timeline",
                subtitle: stops.isEmpty ? "No stops yet." : "\(stops.count) stops",
                accent: ArcPalette.glowSecondary
            )

            if stops.isEmpty {
                Text("Import or add a plan to create stops.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(stops) { stop in
                            Button {
                                selectStop(stop)
                            } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    Label(stop.status.title, systemImage: systemImage(for: stop.status))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(stop.id == selectedStopID ? ArcPalette.tint : .secondary)

                                    Text(stop.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)

                                    Text("\(stop.allItems.filter(\.isResolved).count)/\(stop.allItems.count) resolved")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 168, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(stop.id == selectedStopID ? ArcPalette.tint.opacity(0.14) : ArcPalette.elevatedSurface)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(stop.id == selectedStopID ? ArcPalette.tint.opacity(0.45) : ArcPalette.surfaceStroke, lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func systemImage(for status: StopStatus) -> String {
        switch status {
        case .upcoming:
            return "circle"
        case .active:
            return "record.circle"
        case .done:
            return "checkmark.circle"
        case .skipped:
            return "forward.circle"
        }
    }
}

private struct TripMapPanel: View {
    let stops: [Stop]
    let selectedStopID: UUID?

    private var points: [StopMapPoint] {
        stops.compactMap { stop in
            guard let latitude = stop.latitude, let longitude = stop.longitude else {
                return nil
            }

            return StopMapPoint(
                id: stop.id,
                title: stop.name,
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            )
        }
    }

    var body: some View {
        ArcDenseCard(accent: ArcPalette.glowPrimary) {
            ArcFeatureTitle(
                systemImage: "map",
                title: "Map",
                subtitle: points.isEmpty ? "Set coordinates for stops to show them here." : "\(points.count) mapped stops",
                accent: ArcPalette.glowPrimary
            )

            if !points.isEmpty {
                Map(initialPosition: .region(region(for: points))) {
                    ForEach(points) { point in
                        Marker(point.title, systemImage: point.id == selectedStopID ? "record.circle" : "mappin", coordinate: point.coordinate)
                    }
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .allowsHitTesting(false)
            }
        }
    }

    private func region(for points: [StopMapPoint]) -> MKCoordinateRegion {
        guard let first = points.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
            )
        }

        let latitudes = points.map { $0.coordinate.latitude }
        let longitudes = points.map { $0.coordinate.longitude }
        let minLatitude = latitudes.min() ?? first.coordinate.latitude
        let maxLatitude = latitudes.max() ?? first.coordinate.latitude
        let minLongitude = longitudes.min() ?? first.coordinate.longitude
        let maxLongitude = longitudes.max() ?? first.coordinate.longitude
        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
        let latitudeDelta = max(0.01, (maxLatitude - minLatitude) * 1.8)
        let longitudeDelta = max(0.01, (maxLongitude - minLongitude) * 1.8)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
}

private struct StopMapPoint: Identifiable {
    let id: UUID
    let title: String
    let coordinate: CLLocationCoordinate2D
}

private struct FieldStopControls: View {
    let stop: Stop
    let stage: Stage
    let currentPosition: Int
    let totalStages: Int
    let isHighContrast: Bool
    let arriveAction: () -> Void
    let previousAction: () -> Void
    let nextAction: () -> Void
    let nextStopAction: () -> Void

    var body: some View {
        ArcDenseCard(accent: isHighContrast ? .white : ArcPalette.glowPrimary) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(stop.name)
                        .font(.headline)
                    Text("Stage \(currentPosition + 1) of \(max(totalStages, 1)) - \(stage.title)")
                        .font(.subheadline)
                        .foregroundStyle(isHighContrast ? .white.opacity(0.82) : .secondary)
                }

                Spacer()

                ArcStatusPill(stop.status.title, systemImage: stop.status == .active ? "record.circle" : "circle", tint: isHighContrast ? .white : ArcPalette.glowPrimary)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    controls
                }

                VStack(spacing: 10) {
                    controls
                }
            }
        }
    }

    private var controls: some View {
        Group {
            Button {
                arriveAction()
            } label: {
                Label("Arrive", systemImage: "location.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)

            Button {
                previousAction()
            } label: {
                Label("Previous", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .disabled(currentPosition == 0)

            Button {
                nextAction()
            } label: {
                Label(currentPosition + 1 >= totalStages ? "Next Stop" : "Next", systemImage: "chevron.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
        }
    }
}

private struct FieldStageCard: View {
    let stage: Stage
    let isHighContrast: Bool
    let toggleCaptured: (CaptureItem) -> Void
    let toggleSkipped: (CaptureItem) -> Void
    let attachPhoto: (PhotosPickerItem?, CaptureItem) -> Void
    let removePhoto: (CaptureItem) -> Void
    let editNote: (CaptureItem) -> Void

    private var mustCaptureItems: [CaptureItem] {
        stage.fieldMustItems
    }

    private var optionalItems: [CaptureItem] {
        stage.fieldOptionalItems
    }

    private var beforeLeavingItems: [CaptureItem] {
        stage.fieldBeforeLeavingItems
    }

    var body: some View {
        ArcDenseCard(accent: isHighContrast ? .white : ArcPalette.tint) {
            ArcFeatureTitle(
                systemImage: stage.kind == .safetyNet ? "lifepreserver" : "rectangle.stack",
                title: stage.title,
                subtitle: stage.mantra,
                accent: isHighContrast ? .white : ArcPalette.tint
            )

            FieldProgressBar(progress: stage.progress)
                .frame(height: 8)

            FieldItemSection(
                title: "Must capture",
                emptyMessage: "No must-get items in this stage.",
                items: mustCaptureItems,
                tint: isHighContrast ? .white : ArcPalette.tint,
                toggleCaptured: toggleCaptured,
                toggleSkipped: toggleSkipped,
                attachPhoto: attachPhoto,
                removePhoto: removePhoto,
                editNote: editNote
            )

            if !optionalItems.isEmpty {
                FieldItemSection(
                    title: "Optional coverage",
                    emptyMessage: "",
                    items: optionalItems,
                    tint: isHighContrast ? .white : ArcPalette.glowPrimary,
                    toggleCaptured: toggleCaptured,
                    toggleSkipped: toggleSkipped,
                    attachPhoto: attachPhoto,
                    removePhoto: removePhoto,
                    editNote: editNote
                )
            }

            if !beforeLeavingItems.isEmpty {
                FieldItemSection(
                    title: "Before leaving",
                    emptyMessage: "",
                    items: beforeLeavingItems,
                    tint: isHighContrast ? .white : ArcPalette.glowSecondary,
                    toggleCaptured: toggleCaptured,
                    toggleSkipped: toggleSkipped,
                    attachPhoto: attachPhoto,
                    removePhoto: removePhoto,
                    editNote: editNote
                )
            }
        }
    }
}

private struct FieldItemSection: View {
    let title: String
    let emptyMessage: String
    let items: [CaptureItem]
    let tint: Color
    let toggleCaptured: (CaptureItem) -> Void
    let toggleSkipped: (CaptureItem) -> Void
    let attachPhoto: (PhotosPickerItem?, CaptureItem) -> Void
    let removePhoto: (CaptureItem) -> Void
    let editNote: (CaptureItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if items.isEmpty {
                if !emptyMessage.isEmpty {
                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(items) { item in
                    FieldChecklistRow(
                        item: item,
                        tint: tint,
                        toggleCaptured: { toggleCaptured(item) },
                        toggleSkipped: { toggleSkipped(item) },
                        attachPhoto: { attachPhoto($0, item) },
                        removePhoto: { removePhoto(item) },
                        editNote: { editNote(item) }
                    )
                }
            }
        }
    }
}

private struct FieldChecklistRow: View {
    let item: CaptureItem
    let tint: Color
    let toggleCaptured: () -> Void
    let toggleSkipped: () -> Void
    let attachPhoto: (PhotosPickerItem?) -> Void
    let removePhoto: () -> Void
    let editNote: () -> Void

    @State private var selectedPhotoItem: PhotosPickerItem?

    private var thumbnailImage: UIImage? {
        guard let data = item.capturedPhotoData else {
            return nil
        }

        return UIImage(data: data)
    }

    var body: some View {
        let photoButtonTitle = item.capturedPhotoData == nil ? "Photo" : "Replace"

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: toggleCaptured) {
                    Image(systemName: item.isCaptured ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(item.isCaptured ? tint : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.isCaptured ? "Mark not captured" : "Mark captured")

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .strikethrough(item.isSkipped)
                        .foregroundStyle(item.isSkipped ? .secondary : .primary)

                    Text("\(item.displayRoleTitle) - \(item.priority.title). \(item.guidance)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !item.fieldNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Label(item.fieldNote, systemImage: "note.text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let thumbnailImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Button(action: removePhoto) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.55))
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove attached photo")
                }
            }

            HStack(spacing: 8) {
                Button(action: toggleSkipped) {
                    Label(item.isSkipped ? "Unskip" : "Skip", systemImage: item.isSkipped ? "arrow.uturn.backward" : "forward.end")
                }
                .buttonStyle(.glass)

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(photoButtonTitle, systemImage: "photo")
                }
                .buttonStyle(.glass)
                .onChange(of: selectedPhotoItem) { _, newValue in
                    attachPhoto(newValue)
                    selectedPhotoItem = nil
                }

                Button(action: editNote) {
                    Label("Note", systemImage: "note.text")
                }
                .buttonStyle(.glass)
            }
            .font(.caption.weight(.semibold))
        }
        .padding(12)
        .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(item.isResolved ? tint.opacity(0.38) : ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private struct FieldGuidanceCard: View {
    let trip: Trip
    let stop: Stop
    let stage: Stage
    let isHighContrast: Bool

    var body: some View {
        ArcFeatureCard(accent: isHighContrast ? .white : ArcPalette.glowSecondary) {
            ArcFeatureTitle(
                systemImage: "quote.bubble",
                title: "Field Guidance",
                subtitle: stage.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? trip.targetPlatform.title : stage.goal,
                accent: isHighContrast ? .white : ArcPalette.glowSecondary
            )

            VStack(alignment: .leading, spacing: 8) {
                guidanceLine("Stop", stop.coordinateSummary)
                guidanceLine("Output", "\(trip.outputIntent.title) for \(trip.targetPlatform.title)")
                guidanceLine("Before moving on", stage.unresolvedMustItems.isEmpty ? "Must-get coverage is clear." : "\(stage.unresolvedMustItems.count) must-get items remain.")
            }
        }
    }

    private func guidanceLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct FieldPlanRequiredCard: View {
    var body: some View {
        ArcFeatureCard(accent: ArcPalette.glowPrimary) {
            ArcFeatureTitle(
                systemImage: "exclamationmark.triangle",
                title: "Plan needed",
                subtitle: "Import a trip plan or add field items before starting execution.",
                accent: ArcPalette.glowPrimary
            )
        }
    }
}

private struct SafetyNetSheet: View {
    let stop: Stop?
    let addTemplate: (SafetyNetTemplate) -> Void

    @Environment(\.dismiss) private var dismiss

    private let templates = SafetyNetTemplate.defaults

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ArcCompactHeroHeader(
                        systemImage: "lifepreserver.fill",
                        title: "Safety Net",
                        summary: stop == nil ? "Choose a stop first." : "Patch common story gaps before leaving."
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    ForEach(templates) { template in
                        Button {
                            addTemplate(template)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Label(template.title, systemImage: template.kind.systemImage)
                                    .font(.headline)
                                Text(template.guidance)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .disabled(stop == nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(ArcSceneBackground())
            .navigationTitle("Safety Net")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct SafetyNetTemplate: Identifiable {
    let id = UUID()
    let title: String
    let guidance: String
    let kind: FieldGuideItemKind

    static let defaults: [SafetyNetTemplate] = [
        SafetyNetTemplate(title: "Wide establishing frame", guidance: "Capture a clean wide view that proves where this stop is.", kind: .shot),
        SafetyNetTemplate(title: "Human-scale detail", guidance: "Capture a close detail with texture, hands, signage, food, or movement.", kind: .shot),
        SafetyNetTemplate(title: "Natural sound bed", guidance: "Record 10-20 seconds of clean ambient sound.", kind: .sound),
        SafetyNetTemplate(title: "Voice note reaction", guidance: "Record the plain-language reason this stop matters in the story.", kind: .voice),
        SafetyNetTemplate(title: "Exit transition", guidance: "Capture a leaving shot that can bridge to the next stop.", kind: .transition)
    ]
}

private struct FieldActionBar: View {
    let primaryTitle: String
    let primarySubtitle: String
    let isHighContrast: Bool
    let primaryAction: () -> Void
    let finishAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: primaryAction) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(primarySubtitle)
                        .font(.caption)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.glassProminent)

            Button(action: finishAction) {
                Image(systemName: "checkmark.seal")
                    .font(.headline)
                    .frame(width: 48, height: 44)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Complete trip")
        }
        .tint(isHighContrast ? .white : ArcPalette.tint)
    }
}

private extension Stage {
    var fieldMustItems: [CaptureItem] {
        orderedItems.filter { $0.priority == .must && !$0.isBeforeLeaving }
    }

    var fieldOptionalItems: [CaptureItem] {
        orderedItems.filter { $0.priority == .optional && !$0.isBeforeLeaving }
    }

    var fieldBeforeLeavingItems: [CaptureItem] {
        orderedItems.filter(\.isBeforeLeaving)
    }

    var fieldDisplayItems: [CaptureItem] {
        fieldMustItems + fieldOptionalItems + fieldBeforeLeavingItems
    }
}

private struct FieldNoteEditorSheet: View {
    let item: CaptureItem
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var note: String

    init(item: CaptureItem, onSave: @escaping () -> Void) {
        self.item = item
        self.onSave = onSave
        _note = State(initialValue: item.fieldNote)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(item.title) {
                    TextField("Field note", text: $note, axis: .vertical)
                        .lineLimit(5...10)
                }
            }
            .navigationTitle("Field Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        item.fieldNote = note
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FieldProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)

                Capsule()
                    .fill(ArcPalette.tint)
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue(progress.formatted(.percent.precision(.fractionLength(0))))
    }
}
