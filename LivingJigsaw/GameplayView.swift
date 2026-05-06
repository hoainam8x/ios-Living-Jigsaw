import AVFoundation
import QuartzCore
import SwiftUI
import UIKit

struct GameplayView: View {
    let level: LevelDefinition
    /// Video/ảnh đã xuất ra file temp từ thư viện — `nil` = dùng video bundle theo level.
    var userPickedLibraryVideoURL: URL?
    /// Độ khó người dùng chọn cho media thư viện (2...4), `nil` = theo level.
    var userPickedGridSize: Int?
    /// `true` khi chơi video bundle level — ghi hoàn thành khi bấm Tiếp tục trên overlay bloom.
    var advanceProgressWhenCompleted: Bool = true
    var onComplete: () -> Void
    var onLeave: () -> Void

    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var coordinator = VideoSyncCoordinator()
    @EnvironmentObject private var spatial: SpatialAmbientAudio

    @State private var pieces: [DraggablePiece]

    private let puzzleCols: Int
    private let puzzleRows: Int
    private var cols: Int { puzzleCols }
    private var rows: Int { puzzleRows }

    init(
        level: LevelDefinition,
        userPickedLibraryVideoURL: URL? = nil,
        userPickedGridSize: Int? = nil,
        advanceProgressWhenCompleted: Bool = true,
        onComplete: @escaping () -> Void,
        onLeave: @escaping () -> Void
    ) {
        self.level = level
        self.userPickedLibraryVideoURL = userPickedLibraryVideoURL
        self.userPickedGridSize = userPickedGridSize
        self.advanceProgressWhenCompleted = advanceProgressWhenCompleted
        self.onComplete = onComplete
        self.onLeave = onLeave
        if userPickedLibraryVideoURL != nil {
            let grid = max(2, min(4, userPickedGridSize ?? 2))
            self.puzzleCols = grid
            self.puzzleRows = grid
        } else {
            self.puzzleCols = level.puzzleColumns
            self.puzzleRows = level.puzzleRows
        }
        let n = self.puzzleCols * self.puzzleRows
        _pieces = State(initialValue: (0..<n).map { i in
            DraggablePiece(id: i, correctIndex: i, rotationQuarterTurns: 0, isPlaced: false, dragOffset: .zero)
        })
    }

    @State private var centers: [Int: CGPoint] = [:]
    @State private var dragStartCenters: [Int: CGPoint] = [:]
    @State private var hasBootstrapped = false
    @State private var glowUntil: [Int: Date] = [:]
    /// Đã ghép đủ mảnh — ẩn viền, chờ chiêm ngưỡng rồi `onComplete`.
    @State private var admirePhaseActive = false
    /// Fade viền jigsaw ~0.5s khi vào admire.
    @State private var admireOutlineFade: CGFloat = 1
    /// Ẩn lớp mảnh đã ghép để lộ video full bàn + bloom scale.
    @State private var admirePlacedPieceOpacity: CGFloat = 1
    @State private var admireBoardScale: CGFloat = 1
    @State private var admireVideoBrightness: Double = 0
    @State private var didFireLevelComplete = false
    /// Rung khi **vừa đi vào** vùng gần ô đúng (cạnh bắt CoreHaptics).
    @State private var hotSnapPieces: Set<Int> = []
    /// Đã thực sự kéo dịch mảnh trong gesture hiện tại.
    @State private var dragDidMovePiece: Set<Int> = []
    /// Tránh `playTactileAtPan` mỗi frame (stop/schedule buffer) — gây giật chính luồng + audio.
    @State private var dragTactileBucket: Int = -1
    /// Giới hạn tần suất nhịp nam châm (UIImpactFeedbackGenerator).
    @State private var lastMagneticPulseTime: CFTimeInterval = 0
    /// Sau intro ném mảnh — mới cho kéo / xoay.
    @State private var pieceGestureReady = false
    @State private var introThrowTask: Task<Void, Never>?
    /// Intro: mảnh bắt đầu rất nhỏ rồi nở + bay vào ô (0.06…0.16 → 1).
    @State private var introPieceScale: [Int: CGFloat] = [:]
    /// Intro: nghiêng nhẹ rồi về 0 khi chạm ô.
    @State private var introTiltDegrees: [Int: Double] = [:]
    @State private var activelyDraggedPieceId: Int?
    /// Mảnh đang “chọn” (ưu tiên z-order + viền) — giữ sau tap/xoay cho đến khi chọn mảnh khác hoặc ghép xong.
    @State private var selectedUnplacedPieceId: Int?
    @State private var gameplayAdBannerSuppressed = false
    @State private var bloomCelebrationPresented = false
    @State private var bloomPresentationDelayTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            NatureBackground(variant: .gameplayDim)
                .ignoresSafeArea()
            Color.black.opacity(admirePhaseActive || bloomCelebrationPresented ? 0.1 : 0.45)
                .ignoresSafeArea()

            gameplayGeometry()

            if bloomCelebrationPresented {
                BloomCelebrationOverlayPanel(level: level, immersiveBackground: false, onContinue: finishAfterCelebration)
                    .environmentObject(spatial)
                    .transition(.opacity.combined(with: .scale(1.02)))
                    .zIndex(600)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: [.top, .bottom])
        .background(NaturePalette.deepForest.opacity(0.92).ignoresSafeArea(edges: .top))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(NaturePalette.deepForest.opacity(0.92), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(NaturePalette.sunlight)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "home_back")) {
                    HapticsService.playMenuTap()
                    onLeave()
                }
            }
            ToolbarItem(placement: .principal) {
                Text(
                    userPickedLibraryVideoURL != nil
                        ? "Độ khó \(cols)x\(rows)"
                        : String(localized: String.LocalizationValue(level.titleKey))
                )
                    .font(.footnote.weight(.semibold))
                    .tracking(0.35)
                    .foregroundStyle(NaturePalette.champagne.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: 320)
            }
        }
    }

    @State private var lastLayoutSnapshot: BoardLayout?

    @ViewBuilder
    private func gameplayGeometry() -> some View {
        GeometryReader { geo in
            let layout = boardLayout(for: geo, cols: cols, rows: rows)
            Group {
                if coordinator.isUsingSyntheticFallback {
                    TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        content(layout: layout, globalTime: t, geo: geo)
                    }
                } else {
                    content(layout: layout, globalTime: 0, geo: geo)
                }
            }
            .onAppear {
                HapticsService.prepare()
                coordinator.load(level: level, userPickedLibraryVideoURL: userPickedLibraryVideoURL)
                coordinator.play()
                let placed = pieces.filter(\.isPlaced).count
                spatial.beginGameplaySession(level: level, placedCount: placed)
                if coordinator.puzzleBoardMetricsReady {
                    bootstrapIfNeeded(layout: layout, playfieldWidth: layout.playfieldWidth)
                }
            }
            .onChange(of: coordinator.puzzleBoardMetricsReady) { _, ready in
                guard ready else { return }
                bootstrapIfNeeded(layout: layout, playfieldWidth: layout.playfieldWidth)
            }
            .onDisappear {
                bloomPresentationDelayTask?.cancel()
                bloomPresentationDelayTask = nil
                introThrowTask?.cancel()
                introThrowTask = nil
                spatial.endGameplaySession()
                spatial.setDragShimmerActive(false, reduceMotion: reduceMotion)
                spatial.updateDragProximityFocus(focus01: 0, stereoPan: 0, reduceMotion: reduceMotion)
                coordinator.setVideoPlaybackMuted(true)
                coordinator.pause()
                selectedUnplacedPieceId = nil
            }
        }
        // Mở rộng chiều cao đo được (tránh GeometryReader trong Navigation chỉ = vùng dưới nav → spawn bị “thấp”).
        .ignoresSafeArea(edges: [.top, .bottom])
    }

    @ViewBuilder
    private func content(layout: BoardLayout, globalTime: TimeInterval, geo: GeometryProxy) -> some View {
        ZStack {
            // Hint vẽ trước → mảnh intro bay **lên trên** chữ (giống màn mẫu văng tung toé).
            if !admirePhaseActive {
                VStack(spacing: 0) {
                    Text(String(localized: "gameplay_calm"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(NaturePalette.cream.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHint(Text(String(localized: "gameplay_audio_hint")))
                        .background(
                            ZStack {
                                Capsule().fill(Color.black.opacity(0.22))
                                LuxuryGlassPanel(shape: Capsule(), lineWidth: 0.85)
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    Spacer(minLength: 0)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
                .zIndex(2)
            }

            ZStack {
                boardMediaUnderlay(
                    layout: layout,
                    globalTime: globalTime,
                    playfieldH: layout.playfieldHeight,
                    boardW: layout.playfieldWidth
                )
                .zIndex(0)

                if !admirePhaseActive {
                    slotGhostStrokes(layout: layout)
                        .opacity(pieceGestureReady ? 1.0 : 0.42)
                        .animation(.easeInOut(duration: 0.45), value: pieceGestureReady)
                        .zIndex(1)
                }

                ForEach(pieces.filter(\.isPlaced)) { piece in
                    let c = layout.slotCenter(forIndex: piece.correctIndex)
                    let g = admirePhaseActive ? false : glowActive(for: piece.id)
                    pieceView(piece: piece, center: c, size: layout.cell, globalTime: globalTime, glow: g, introExtraDegrees: 0)
                        .position(c)
                        .opacity(admirePhaseActive ? admirePlacedPieceOpacity : 1)
                        .brightness(admirePhaseActive ? admireVideoBrightness * 0.35 : 0)
                        .zIndex(2 + Double(piece.correctIndex))
                }

                if hasBootstrapped {
                    Group {
                        ForEach(pieces.filter { !$0.isPlaced }.sorted(by: { $0.id < $1.id })) { piece in
                            let c = centers[piece.id] ?? layout.boardMidpoint
                            let g = admirePhaseActive ? false : glowActive(for: piece.id)
                            unplacedPieceNode(
                                piece: piece,
                                center: c,
                                layout: layout,
                                geoWidth: layout.playfieldWidth,
                                globalTime: globalTime,
                                glow: g
                            )
                        }
                    }
                }
            }
            .frame(width: layout.playfieldWidth, height: layout.playfieldHeight)
            .ignoresSafeArea(edges: [.horizontal, .bottom])
            .zIndex(8)

            if !admirePhaseActive {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                        .allowsHitTesting(false)
                    HStack(spacing: 0) {
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: 50)
                            .allowsHitTesting(false)
                        GameplayAdBannerSlot(isSuppressed: $gameplayAdBannerSuppressed)
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: 50)
                            .allowsHitTesting(false)
                    }
                    .frame(height: 50)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .zIndex(40)
            }
        }
        .frame(width: geo.size.width, height: geo.size.height)
        .animation(.easeInOut(duration: 0.35), value: admirePhaseActive)
        .onAppear { lastLayoutSnapshot = layout }
        .onChange(of: geo.size) { _, _ in
            let next = boardLayout(for: geo, cols: cols, rows: rows)
            lastLayoutSnapshot = next
            if !hasBootstrapped, coordinator.puzzleBoardMetricsReady {
                bootstrapIfNeeded(layout: next, playfieldWidth: next.playfieldWidth)
            } else {
                reclampUnplacedCenters(layout: next)
            }
        }
        .onChange(of: coordinator.videoDisplayAspectRatio) { _, _ in
            let next = boardLayout(for: geo, cols: cols, rows: rows)
            lastLayoutSnapshot = next
            if !hasBootstrapped, coordinator.puzzleBoardMetricsReady {
                bootstrapIfNeeded(layout: next, playfieldWidth: next.playfieldWidth)
            } else {
                reclampUnplacedCenters(layout: next)
            }
        }
        .onChange(of: coordinator.isUsingSyntheticFallback) { _, _ in
            let next = boardLayout(for: geo, cols: cols, rows: rows)
            lastLayoutSnapshot = next
            if !hasBootstrapped, coordinator.puzzleBoardMetricsReady {
                bootstrapIfNeeded(layout: next, playfieldWidth: next.playfieldWidth)
            } else {
                reclampUnplacedCenters(layout: next)
            }
        }
        .onChange(of: pieces) { _, new in
            guard new.allSatisfy(\.isPlaced), !admirePhaseActive else { return }
            spatial.celebrateSymphonyFull()
            admirePhaseActive = true
            admireOutlineFade = 1
            admirePlacedPieceOpacity = 1
            admireBoardScale = 1
            admireVideoBrightness = 0
            withAnimation(.easeOut(duration: 0.5)) {
                admireOutlineFade = 0
            }
            if reduceMotion {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        admireBoardScale = 1.012
                        admireVideoBrightness = 0.08
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.72, dampingFraction: 0.68)) {
                        admireBoardScale = 1.048
                        admireVideoBrightness = 0.14
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    guard admirePhaseActive else { return }
                    withAnimation(.easeOut(duration: 0.65)) {
                        admireBoardScale = 1.018
                        admireVideoBrightness = 0.1
                    }
                }
            }
            withAnimation(.easeOut(duration: 0.52).delay(0.28)) {
                admirePlacedPieceOpacity = 0
            }
            if !coordinator.isUsingSyntheticFallback {
                coordinator.setVideoPlaybackMuted(false)
            }
            bloomPresentationDelayTask?.cancel()
            bloomPresentationDelayTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                bloomCelebrationPresented = true
            }
        }
    }

    private func finishAfterCelebration() {
        guard !didFireLevelComplete else { return }
        didFireLevelComplete = true
        bloomPresentationDelayTask?.cancel()
        bloomPresentationDelayTask = nil
        if advanceProgressWhenCompleted {
            GameProgress.markCompleted(levelId: level.id)
        }
        coordinator.setVideoPlaybackMuted(true)
        bloomCelebrationPresented = false
        onComplete()
    }

    private func glowActive(for id: Int) -> Bool {
        guard let until = glowUntil[id] else { return false }
        return Date() < until
    }

    /// Chỉ viền ô — không nền synthetic (tránh vùng lõm / xếp chồng thấy đen).
    private func slotGhostStrokes(layout: BoardLayout) -> some View {
        ForEach(0..<(cols * rows), id: \.self) { idx in
            let col = idx % cols
            let row = idx / cols
            let edges = PieceEdges.profile(col: col, row: row, cols: cols, rows: rows)
            JigsawPieceShape(edges: edges)
                .stroke(NaturePalette.champagne.opacity(0.16), lineWidth: 1)
                .frame(width: layout.cell.width, height: layout.cell.height)
                .position(layout.slotCenter(forIndex: idx))
        }
    }

    /// Nền bàn: synthetic = lấp lõm khi cần; video **không** full-board lúc chơi (tránh lộ ảnh), chỉ khi chiêm ngưỡng.
    @ViewBuilder
    private func boardMediaUnderlay(layout: BoardLayout, globalTime: TimeInterval, playfieldH: CGFloat, boardW: CGFloat) -> some View {
        Group {
            if let player = coordinator.player, !coordinator.isUsingSyntheticFallback {
                if admirePhaseActive {
                    VideoBoardUnderlayRepresentable(player: player, itemVideoOutput: coordinator.itemVideoOutput)
                        .frame(width: layout.boardSize.width, height: layout.boardSize.height)
                        .clipped()
                        .scaleEffect(admireBoardScale, anchor: .center)
                        .brightness(admireVideoBrightness)
                        .position(layout.boardMidpoint)
                }
            } else {
                let anchor = UnitPoint(
                    x: layout.boardMidpoint.x / max(1, boardW),
                    y: layout.boardMidpoint.y / max(1, playfieldH)
                )
                syntheticBoardUnderlayCells(layout: layout, globalTime: globalTime)
                    .scaleEffect(admirePhaseActive ? admireBoardScale : 1, anchor: anchor)
                    .brightness(admirePhaseActive ? admireVideoBrightness : 0)
            }
        }
        .frame(width: boardW, height: playfieldH)
        .allowsHitTesting(false)
    }

    private func syntheticBoardUnderlayCells(layout: BoardLayout, globalTime: TimeInterval) -> some View {
        ZStack {
            ForEach(0..<(cols * rows), id: \.self) { idx in
                let col = idx % cols
                let row = idx / cols
                SyntheticLoopView(
                    palette: level.syntheticPalette,
                    globalTime: globalTime,
                    col: col,
                    row: row
                )
                .frame(width: layout.cell.width, height: layout.cell.height)
                .position(layout.slotCenter(forIndex: idx))
            }
        }
    }

    @ViewBuilder
    private func unplacedPieceNode(
        piece: DraggablePiece,
        center: CGPoint,
        layout: BoardLayout,
        geoWidth: CGFloat,
        globalTime: TimeInterval,
        glow: Bool
    ) -> some View {
        let dragging = activelyDraggedPieceId == piece.id
        let lifted = selectedUnplacedPieceId == piece.id || dragging
        let introS = introSpawnScale(for: piece.id)
        let ph = max(1, layout.playfieldHeight)
        let pw = max(1, layout.playfieldWidth)
        let stackLayer = Double(center.y / ph) * 8 + Double(center.x / pw) * 0.08 + Double(piece.id) * 1e-4
        let liftScale: CGFloat = {
            if dragging { return reduceMotion ? 1.05 : 1.09 }
            if lifted { return reduceMotion ? 1.025 : 1.05 }
            return 1
        }()
        let base = pieceView(
            piece: piece,
            center: center,
            size: layout.cell,
            globalTime: globalTime,
            glow: glow,
            introExtraDegrees: introTiltValue(for: piece.id),
            selectionEmphasized: lifted && !admirePhaseActive
        )
            .position(center)
            .opacity(introOpacity(for: piece.id))
            .scaleEffect(introS * liftScale)
            .shadow(
                color: lifted ? Color.black.opacity(dragging ? 0.48 : 0.32) : .clear,
                radius: dragging ? 24 : (lifted ? 16 : 0),
                y: dragging ? 10 : (lifted ? 6 : 0)
            )
            .zIndex(dragging ? 340 : (lifted ? 240 : 40 + stackLayer))
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: selectedUnplacedPieceId)
            .animation(.spring(response: 0.36, dampingFraction: 0.78), value: activelyDraggedPieceId)
        if pieceGestureReady {
            base
                .gesture(pieceDragGesture(for: piece, layout: layout, geoWidth: geoWidth))
        } else {
            base
        }
    }

    private func introSpawnScale(for id: Int) -> CGFloat {
        if reduceMotion || pieceGestureReady { return 1 }
        return introPieceScale[id] ?? 0.1
    }

    private func introTiltValue(for id: Int) -> Double {
        if reduceMotion || pieceGestureReady { return 0 }
        return introTiltDegrees[id] ?? 0
    }

    private func introOpacity(for id: Int) -> Double {
        if reduceMotion || pieceGestureReady { return 1 }
        let s = Double(introPieceScale[id] ?? 0.1)
        return min(1, 0.52 + 0.48 * ((s - 0.06) / max(0.001, 1 - 0.06)))
    }

    private func pieceView(
        piece: DraggablePiece,
        center: CGPoint,
        size: CGSize,
        globalTime: TimeInterval,
        glow: Bool,
        introExtraDegrees: Double = 0,
        selectionEmphasized: Bool = false
    ) -> some View {
        let col = piece.correctIndex % cols
        let row = piece.correctIndex / cols
        let edges = PieceEdges.profile(col: col, row: row, cols: cols, rows: rows)
        let core = LivingPieceCell(
            palette: level.syntheticPalette,
            col: col,
            row: row,
            cols: cols,
            rows: rows,
            player: coordinator.player,
            itemVideoOutput: coordinator.itemVideoOutput,
            useSynthetic: coordinator.isUsingSyntheticFallback,
            globalTime: globalTime,
            edges: edges,
            isPlaced: piece.isPlaced,
            bloomPulse: glow,
            jigsawStrokeOpacity: admirePhaseActive ? admireOutlineFade : 1,
            selectionEmphasized: selectionEmphasized
        )
        .frame(width: size.width, height: size.height)
        return Group {
            if selectionEmphasized {
                ZStack {
                    JigsawPieceShape(edges: edges)
                        .stroke(NaturePalette.goldRing.opacity(0.5), lineWidth: 11)
                        .blur(radius: 5)
                    core
                    JigsawPieceShape(edges: edges)
                        .stroke(NaturePalette.luxuryStrokeGradient, lineWidth: 3.2)
                        .shadow(color: NaturePalette.champagne.opacity(0.95), radius: 12, y: 2)
                }
                .frame(width: size.width, height: size.height)
            } else {
                core
            }
        }
        .frame(width: size.width, height: size.height)
        .rotationEffect(piece.rotationAngle + .degrees(introExtraDegrees))
        .contentShape(JigsawPieceShape(edges: edges))
        .animation(.spring(response: 0.45, dampingFraction: 0.76), value: piece.rotationQuarterTurns)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityCombinedLabel(for: piece)))
        .accessibilityHint(Text(String(localized: piece.isPlaced ? "gameplay_audio_hint" : "gameplay_piece_gesture_hint")))
        .accessibilityAddTraits(.isButton)
    }

    private func pieceDragGesture(for piece: DraggablePiece, layout: BoardLayout, geoWidth: CGFloat) -> some Gesture {
        let slop: CGFloat = 6
        return DragGesture(minimumDistance: 0)
            .onChanged { value in
                selectedUnplacedPieceId = piece.id
                if dragStartCenters[piece.id] == nil {
                    dragStartCenters[piece.id] = centers[piece.id] ?? layout.boardMidpoint
                }
                let beyondSlop = hypot(value.translation.width, value.translation.height) > slop
                guard beyondSlop else { return }
                let start = dragStartCenters[piece.id] ?? layout.boardMidpoint
                let next = CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height)
                let clamped = layout.clampedUnplacedCenter(next)
                var tx = Transaction()
                tx.animation = nil
                withTransaction(tx) {
                    centers[piece.id] = clamped
                }
                activelyDraggedPieceId = piece.id
                dragDidMovePiece.insert(piece.id)
                processDragSensoryFeedback(
                    piece: piece,
                    at: clamped,
                    layout: layout,
                    geoWidth: geoWidth
                )
            }
            .onEnded { value in
                activelyDraggedPieceId = nil
                dragTactileBucket = -1
                spatial.setDragShimmerActive(false, reduceMotion: reduceMotion)
                spatial.updateDragProximityFocus(focus01: 0, stereoPan: 0, reduceMotion: reduceMotion)
                let didDrag = dragDidMovePiece.contains(piece.id)
                dragDidMovePiece.remove(piece.id)
                let start = dragStartCenters[piece.id] ?? layout.boardMidpoint
                dragStartCenters[piece.id] = nil
                let tapLike = hypot(value.translation.width, value.translation.height) < slop
                if !didDrag, tapLike {
                    rotatePiece(id: piece.id)
                    return
                }
                let rawEnd = CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height)
                let end = layout.clampedUnplacedCenter(rawEnd)
                if let idx = pieces.firstIndex(where: { $0.id == piece.id }) {
                    hotSnapPieces.remove(piece.id)
                    trySnap(index: idx, currentCenter: end, layout: layout, forced: false)
                }
            }
    }

    private func rotatePiece(id: Int) {
        guard let idx = pieces.firstIndex(where: { $0.id == id }) else { return }
        guard !pieces[idx].isPlaced else { return }
        selectedUnplacedPieceId = id
        let next = pieces[idx].rotationQuarterTurns + 1
        withAnimation(.spring(response: 0.46, dampingFraction: 0.74)) {
            pieces[idx].rotationQuarterTurns = next
        }
        HapticsService.playPieceRotate()
        spatial.playRotateClick()
        UIAccessibility.post(notification: .announcement, argument: String(localized: "piece_rotated_a11y"))
    }

    private func accessibilityCombinedLabel(for piece: DraggablePiece) -> String {
        let base = String(localized: String.LocalizationValue(level.pieceAccessibilityKey(index: piece.correctIndex)))
        guard !coordinator.isUsingSyntheticFallback else { return base }
        let motion = String(localized: "a11y_piece_live_motion")
        return "\(motion). \(base)"
    }

    private func processDragSensoryFeedback(
        piece: DraggablePiece,
        at point: CGPoint,
        layout: BoardLayout,
        geoWidth: CGFloat
    ) {
        let target = layout.slotCenter(forIndex: piece.correctIndex)
        let d = hypot(point.x - target.x, point.y - target.y)
        let cellM = min(layout.cell.width, layout.cell.height)
        let hotR = min(100, max(36, cellM * 0.58))
        let farR = hotR * 2.75
        let focus01 = Float(max(0, min(1, 1 - d / max(farR, 1))))
        let nx = max(0, min(1, point.x / max(1, geoWidth)))
        let stereo = Float(nx * 2 - 1)
        spatial.updateDragProximityFocus(focus01: focus01, stereoPan: stereo, reduceMotion: reduceMotion)
        spatial.setDragShimmerActive(true, reduceMotion: reduceMotion)

        let inHot = d < hotR
        if inHot {
            if !hotSnapPieces.contains(piece.id) {
                hotSnapPieces.insert(piece.id)
                if !reduceMotion {
                    HapticsService.playProximitySoft()
                }
            }
            if !reduceMotion {
                let now = CACurrentMediaTime()
                if now - lastMagneticPulseTime >= 0.052 {
                    lastMagneticPulseTime = now
                    let near01 = CGFloat(max(0, min(1, 1 - d / max(hotR, 1))))
                    HapticsService.playMagneticMicroPulse(intensity: 0.12 + near01 * 0.28)
                }
            }
        } else {
            hotSnapPieces.remove(piece.id)
        }

        if d > farR * 1.02 {
            let bucket = Int(nx * 10)
            if bucket != dragTactileBucket {
                dragTactileBucket = bucket
                spatial.playTactileAtPan(normalizedX: nx)
            }
        } else {
            dragTactileBucket = -1
        }
    }

    private func trySnap(index: Int, currentCenter: CGPoint, layout: BoardLayout, forced: Bool) {
        var p = pieces[index]
        guard !p.isPlaced else { return }
        let target = layout.slotCenter(forIndex: p.correctIndex)
        let d = hypot(currentCenter.x - target.x, currentCenter.y - target.y)
        let snapR: CGFloat = forced ? 220 : level.gameplaySnapRadius
        let orientationOK = p.normalizedQuarterTurns == 0
        if d <= snapR, orientationOK {
            activelyDraggedPieceId = nil
            if selectedUnplacedPieceId == p.id {
                selectedUnplacedPieceId = nil
            }
            p.isPlaced = true
            p.rotationQuarterTurns = 0
            let placedAfterSnap = pieces.filter(\.isPlaced).count + 1
            var snapTxn = Transaction()
            snapTxn.disablesAnimations = true
            withTransaction(snapTxn) {
                pieces[index] = p
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                centers[p.id] = target
            }
            HapticsService.playSnapMatchHeavy()
            spatial.playSnapLayeredSuccess()
            spatial.syncSymphonyLayers(placedCount: placedAfterSnap, total: cols * rows)
            glowUntil[p.id] = Date().addingTimeInterval(1.0)
            UIAccessibility.post(notification: .announcement, argument: String(localized: "piece_connected"))
        } else if d <= snapR, !orientationOK, !forced {
            HapticsService.playSnapReject()
            spatial.playRotateClick()
            centers[p.id] = layout.clampedUnplacedCenter(currentCenter)
        } else if !forced {
            centers[p.id] = layout.clampedUnplacedCenter(currentCenter)
        }
    }

    private func reclampUnplacedCenters(layout: BoardLayout) {
        guard hasBootstrapped, pieceGestureReady else { return }
        for piece in pieces where !piece.isPlaced {
            let c = centers[piece.id] ?? layout.boardMidpoint
            centers[piece.id] = layout.clampedUnplacedCenter(c)
        }
    }

    private func bootstrapIfNeeded(layout: BoardLayout, playfieldWidth: CGFloat) {
        guard !hasBootstrapped else { return }
        // Tránh frame SwiftUI lần đầu = 0 / quá thấp → spawn rơi vào `boardMidpoint` (cụm giữa màn).
        guard layout.playfieldHeight >= 160, layout.playfieldWidth >= 160 else { return }
        hasBootstrapped = true
        selectedUnplacedPieceId = nil
        pieceGestureReady = false
        lastLayoutSnapshot = layout
        let fieldW = max(1, playfieldWidth)

        var slotForPiece = Array(0..<(cols * rows))
        var guardDerangement = 0
        repeat {
            slotForPiece.shuffle()
            guardDerangement += 1
        } while (0..<slotForPiece.count).contains(where: { slotForPiece[$0] == $0 }) && guardDerangement < 120

        var targets: [Int: CGPoint] = [:]
        for pieceId in 0..<slotForPiece.count {
            let c = layout.slotCenter(forIndex: slotForPiece[pieceId])
            targets[pieceId] = c
        }
        for i in pieces.indices {
            pieces[i].rotationQuarterTurns = Int.random(in: 0..<4)
        }

        if reduceMotion {
            centers = targets
            pieceGestureReady = true
            return
        }

        let w = fieldW
        let h = layout.playfieldHeight
        /// Intro mảnh thu nhỏ — inset ngang giữ mép; inset dọc nhỏ hơn để tận dụng gần full chiều cao màn.
        let spawnInsetX = max(5, layout.pieceExtentInset * 0.09)
        let spawnInsetY = max(2, layout.pieceExtentInset * 0.03)
        let minX = spawnInsetX
        let maxX = w - spawnInsetX
        let minY = spawnInsetY
        let maxY = h - spawnInsetY
        let n = slotForPiece.count
        var spawns: [Int: CGPoint] = [:]
        /// Video rộng → bàn là dải ngang mỏng; random đều toàn màn vẫn hay rơi **trên** bàn. Ưu tiên dải trên/dưới `boardRect` để mảnh nằm nền đen rồi mới bay vào ô.
        func introScatterPoint() -> CGPoint {
            let x = CGFloat.random(in: minX...maxX)
            let boardTop = layout.boardOrigin.y
            let boardBot = layout.boardOrigin.y + layout.boardSize.height
            let margin = max(6, layout.pieceExtentInset * 0.1)
            let topBandMax = min(maxY, boardTop - margin)
            let botBandMin = max(minY, boardBot + margin)
            let topBandHi = max(0, topBandMax - minY)
            let botBandHi = max(0, maxY - botBandMin)
            if topBandHi + botBandHi > 44, Double.random(in: 0...1) < 0.9 {
                if topBandHi > 22, botBandHi > 22 {
                    let y = Bool.random()
                        ? CGFloat.random(in: minY...topBandMax)
                        : CGFloat.random(in: botBandMin...maxY)
                    return CGPoint(x: x, y: y)
                }
                if topBandHi > 22 {
                    return CGPoint(x: x, y: CGFloat.random(in: minY...topBandMax))
                }
                if botBandHi > 22 {
                    return CGPoint(x: x, y: CGFloat.random(in: botBandMin...maxY))
                }
            }
            return CGPoint(x: x, y: CGFloat.random(in: minY...maxY))
        }
        if minX < maxX, minY < maxY, n > 0 {
            for pid in 0..<n {
                spawns[pid] = introScatterPoint()
            }
        } else {
            for pid in 0..<max(n, 0) {
                spawns[pid] = layout.boardMidpoint
            }
        }
        centers = spawns
        var seedScale: [Int: CGFloat] = [:]
        var seedTilt: [Int: Double] = [:]
        for p in pieces {
            seedScale[p.id] = CGFloat.random(in: 0.05...0.24)
            seedTilt[p.id] = Double.random(in: 0.0...360.0)
        }
        introPieceScale = seedScale
        introTiltDegrees = seedTilt

        introThrowTask?.cancel()
        introThrowTask = Task { @MainActor in
            // Giữ scatter đủ lâu — trước đây ~280ms rồi bay vào dải ô nên màn nhìn như “chỉ cụm theo bàn”.
            try? await Task.sleep(nanoseconds: 1_050_000_000)
            guard !Task.isCancelled else { return }
            let ordered = pieces.map(\.id).shuffled()
            for (i, pid) in ordered.enumerated() {
                if i > 0 {
                    let gap = UInt64.random(in: 52_000_000...118_000_000)
                    try? await Task.sleep(nanoseconds: gap)
                }
                guard !Task.isCancelled else { return }
                if let t = targets[pid] {
                    withAnimation(.interpolatingSpring(stiffness: 82, damping: 14.5)) {
                        centers[pid] = t
                        introPieceScale[pid] = 1.0
                        introTiltDegrees[pid] = 0
                    }
                    let nx = max(0, min(1, t.x / fieldW))
                    spatial.playPieceSettleAtPan(normalizedX: nx)
                    HapticsService.playPieceSettle()
                }
            }
            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: 520_000_000)
            pieceGestureReady = true
            if let snap = lastLayoutSnapshot {
                withAnimation(.easeOut(duration: 0.28)) {
                    reclampUnplacedCenters(layout: snap)
                }
            }
        }
    }

    private struct BoardLayout {
        let cols: Int
        let rows: Int
        let cell: CGSize
        let boardOrigin: CGPoint
        let boardSize: CGSize
        /// Bề ngang vùng ZStack chơi (= chiều rộng geometry).
        let playfieldWidth: CGFloat
        /// Chiều cao vùng bàn (ô + chỗ kéo tràn nhẹ).
        let playfieldHeight: CGFloat
        /// Nửa “bán kính” mảnh + tai — giữ tâm mảnh trong playfield khi kéo.
        var pieceExtentInset: CGFloat {
            max(cell.width, cell.height) * 0.5 * 1.24
        }
        /// Tâm khung 2×2 — fallback khi chưa có `centers`.
        var boardMidpoint: CGPoint {
            CGPoint(
                x: boardOrigin.x + boardSize.width * 0.5,
                y: boardOrigin.y + boardSize.height * 0.5
            )
        }

        func slotCenter(forIndex index: Int) -> CGPoint {
            let col = index % cols
            let row = index / cols
            let x = boardOrigin.x + CGFloat(col) * cell.width + cell.width * 0.5
            let y = boardOrigin.y + CGFloat(row) * cell.height + cell.height * 0.5
            return CGPoint(x: x, y: y)
        }

        /// Giữ tâm mảnh trong **toàn** vùng chơi (kéo thoải mái khắp màn hình layout).
        func clampedUnplacedCenter(_ proposed: CGPoint) -> CGPoint {
            let inset = pieceExtentInset
            let minX = inset
            let maxX = playfieldWidth - inset
            let minY = inset
            let maxY = playfieldHeight - inset
            guard minX <= maxX, minY <= maxY else { return proposed }
            return CGPoint(
                x: min(maxX, max(minX, proposed.x)),
                y: min(maxY, max(minY, proposed.y))
            )
        }
    }

    private func boardLayout(for geo: GeometryProxy, cols: Int, rows: Int) -> BoardLayout {
        let contentAR: CGFloat? = {
            guard !coordinator.isUsingSyntheticFallback else { return nil }
            guard let ar = coordinator.videoDisplayAspectRatio else { return nil }
            // Màn chọn media từ thư viện: ưu tiên bố cục dọc theo điện thoại.
            if userPickedLibraryVideoURL != nil, ar > 1.0 {
                return 1.0 / ar
            }
            return ar
        }()
        return Self.makeBoardLayout(
            for: geo,
            cols: cols,
            rows: rows,
            contentAspectWidthOverHeight: contentAR,
            displayScale: displayScale
        )
    }

    /// `contentAspectWidthOverHeight`: tỷ lệ **cả khung** video (bàn ghép = `cols×rows` ô cùng tỷ lệ). `nil` → ô vuông (synthetic).
    private static func makeBoardLayout(
        for geo: GeometryProxy,
        cols: Int,
        rows: Int,
        contentAspectWidthOverHeight: CGFloat?,
        displayScale: CGFloat
    ) -> BoardLayout {
        let s = max(displayScale, 1)
        func floorPx(_ v: CGFloat) -> CGFloat { floor(v * s) / s }

        let playfieldWidth = geo.size.width
        let playfieldHeight = geo.size.height

        /// Khung ghép rộng tối đa 98% bề ngang; chiều cao bàn tối đa ~88% vùng chơi full màn hình.
        let capW = max(floorPx(playfieldWidth * 0.98), 120)
        let verticalBudget = max(140, playfieldHeight * 0.88)

        let boardAR: CGFloat = {
            if let ar = contentAspectWidthOverHeight, ar.isFinite, ar > 0.05, ar < 20 {
                return ar
            }
            return 1
        }()

        var boardW = capW
        var boardH = boardW / boardAR
        if boardH > verticalBudget {
            boardH = verticalBudget
            boardW = boardH * boardAR
        }

        // Video: khung bàn = tỷ lệ video; làm tròn theo pixel để các ô `cols×rows` khớp ghép thành một lưới decode thống nhất.
        if contentAspectWidthOverHeight != nil {
            boardH = max(floorPx(boardH), 1 / s)
            boardW = boardH * boardAR
            if boardW > capW {
                boardW = max(floorPx(capW), 1 / s)
                boardH = max(floorPx(boardW / boardAR), 1 / s)
                boardW = boardH * boardAR
                if boardW > capW + 0.5 / s {
                    boardW = max(floorPx(capW), 1 / s)
                    boardH = max(floorPx(boardW / boardAR), 1 / s)
                    boardW = boardH * boardAR
                }
            }
        }

        let cw = boardW / CGFloat(cols)
        let ch = boardH / CGFloat(rows)
        let boardSize = CGSize(width: boardW, height: boardH)
        let originX = (playfieldWidth - boardW) * 0.5
        let originY = max(10, (playfieldHeight - boardH) * 0.5)
        return BoardLayout(
            cols: cols,
            rows: rows,
            cell: CGSize(width: cw, height: ch),
            boardOrigin: CGPoint(x: originX, y: originY),
            boardSize: boardSize,
            playfieldWidth: playfieldWidth,
            playfieldHeight: playfieldHeight
        )
    }

}

private struct VideoBoardUnderlayRepresentable: UIViewRepresentable {
    let player: AVPlayer
    let itemVideoOutput: AVPlayerItemVideoOutput?

    func makeUIView(context: Context) -> VideoFullBoardUIView {
        VideoFullBoardUIView(player: player, itemVideoOutput: itemVideoOutput)
    }

    func updateUIView(_ uiView: VideoFullBoardUIView, context: Context) {
        uiView.replacePlayer(player, itemVideoOutput: itemVideoOutput)
    }
}
