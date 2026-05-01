import AVFoundation
import SwiftUI
import UIKit

struct GameplayView: View {
    let level: LevelDefinition
    var onComplete: () -> Void
    var onLeave: () -> Void

    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var coordinator = VideoSyncCoordinator()
    @EnvironmentObject private var spatial: SpatialAmbientAudio

    @State private var pieces: [DraggablePiece]

    private var cols: Int { level.puzzleColumns }
    private var rows: Int { level.puzzleRows }

    init(level: LevelDefinition, onComplete: @escaping () -> Void, onLeave: @escaping () -> Void) {
        self.level = level
        self.onComplete = onComplete
        self.onLeave = onLeave
        let n = level.puzzleColumns * level.puzzleRows
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
    @State private var admireAutoCompleteTask: DispatchWorkItem?
    @State private var didFireLevelComplete = false
    /// Rung khi **vừa đi vào** vùng gần ô đúng (cạnh bắt CoreHaptics).
    @State private var hotSnapPieces: Set<Int> = []
    /// Long‑press đủ lâu → cho phép kéo (giữ rồi di chuyển).
    @State private var moveArmedByHold: Set<Int> = []
    /// Đã thực sự kéo dịch mảnh trong gesture hiện tại.
    @State private var dragDidMovePiece: Set<Int> = []
    /// Sau intro ném mảnh — mới cho kéo / xoay.
    @State private var pieceGestureReady = false
    @State private var introThrowTask: Task<Void, Never>?
    /// Intro: mảnh bắt đầu rất nhỏ rồi nở + bay vào ô (0.06…0.16 → 1).
    @State private var introPieceScale: [Int: CGFloat] = [:]
    /// Intro: nghiêng nhẹ rồi về 0 khi chạm ô.
    @State private var introTiltDegrees: [Int: Double] = [:]
    @State private var activelyDraggedPieceId: Int?

    var body: some View {
        ZStack {
            NatureBackground(variant: .gameplayDim)
                .ignoresSafeArea(edges: [.horizontal, .bottom])
            Color.black.opacity(0.45)
                .ignoresSafeArea(edges: [.horizontal, .bottom])

            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                GeometryReader { geo in
                    let layout = boardLayout(for: geo, cols: cols, rows: rows)
                    content(layout: layout, globalTime: t, geo: geo)
                        .onAppear {
                            HapticsService.prepare()
                            coordinator.load(level: level)
                            coordinator.play()
                            if coordinator.puzzleBoardMetricsReady {
                                bootstrapIfNeeded(layout: layout, playfieldWidth: layout.playfieldWidth)
                            }
                        }
                        .onChange(of: coordinator.puzzleBoardMetricsReady) { _, ready in
                            guard ready else { return }
                            bootstrapIfNeeded(layout: layout, playfieldWidth: layout.playfieldWidth)
                        }
                        .onDisappear {
                            admireAutoCompleteTask?.cancel()
                            admireAutoCompleteTask = nil
                            introThrowTask?.cancel()
                            introThrowTask = nil
                            coordinator.pause()
                        }
                }
            }
        }
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
                Text(String(localized: String.LocalizationValue(level.titleKey)))
                    .font(.footnote.weight(.semibold))
                    .tracking(0.35)
                    .foregroundStyle(NaturePalette.champagne.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: 320)
            }
            if admirePhaseActive {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "gameplay_next")) {
                        fireLevelCompleteOnce()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    @State private var lastLayoutSnapshot: BoardLayout?

    @ViewBuilder
    private func content(layout: BoardLayout, globalTime: TimeInterval, geo: GeometryProxy) -> some View {
        ZStack {
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
                        .zIndex(2 + Double(piece.correctIndex))
                }

                if hasBootstrapped {
                    Group {
                        ForEach(pieces.filter { !$0.isPlaced }) { piece in
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
            }

            if !admirePhaseActive {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    AccessibilityBannerSlot()
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                }
                .allowsHitTesting(false)
            }
        }
        .frame(width: geo.size.width, height: geo.size.height)
        .animation(.easeInOut(duration: 0.35), value: admirePhaseActive)
        .onAppear { lastLayoutSnapshot = layout }
        .onChange(of: geo.size) { _, _ in
            let next = boardLayout(for: geo, cols: cols, rows: rows)
            lastLayoutSnapshot = next
            reclampUnplacedCenters(layout: next)
        }
        .onChange(of: coordinator.videoDisplayAspectRatio) { _, _ in
            let next = boardLayout(for: geo, cols: cols, rows: rows)
            lastLayoutSnapshot = next
            reclampUnplacedCenters(layout: next)
        }
        .onChange(of: coordinator.isUsingSyntheticFallback) { _, _ in
            let next = boardLayout(for: geo, cols: cols, rows: rows)
            lastLayoutSnapshot = next
            reclampUnplacedCenters(layout: next)
        }
        .onChange(of: pieces) { _, new in
            guard new.allSatisfy(\.isPlaced), !admirePhaseActive else { return }
            admirePhaseActive = true
            let task = DispatchWorkItem { fireLevelCompleteOnce() }
            admireAutoCompleteTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: task)
        }
    }

    private func fireLevelCompleteOnce() {
        guard !didFireLevelComplete else { return }
        didFireLevelComplete = true
        admireAutoCompleteTask?.cancel()
        admireAutoCompleteTask = nil
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
                    VideoBoardUnderlayRepresentable(player: player)
                        .frame(width: layout.boardSize.width, height: layout.boardSize.height)
                        .clipped()
                        .position(layout.boardMidpoint)
                }
            } else {
                syntheticBoardUnderlayCells(layout: layout, globalTime: globalTime)
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
        let introS = introSpawnScale(for: piece.id)
        let base = pieceView(
            piece: piece,
            center: center,
            size: layout.cell,
            globalTime: globalTime,
            glow: glow,
            introExtraDegrees: introTiltValue(for: piece.id)
        )
            .position(center)
            .opacity(introOpacity(for: piece.id))
            .scaleEffect(introS * (dragging ? 1.06 : 1.0))
            .shadow(color: dragging ? Color.black.opacity(0.4) : .clear, radius: dragging ? 20 : 0, y: dragging ? 8 : 0)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: dragging)
            .zIndex(dragging ? 80 : 32 + Double(piece.id))
        if pieceGestureReady {
            base
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: level.gameplayLongPressArmSeconds, maximumDistance: 22)
                        .onEnded { _ in
                            moveArmedByHold.insert(piece.id)
                        }
                )
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

    private func pieceView(piece: DraggablePiece, center: CGPoint, size: CGSize, globalTime: TimeInterval, glow: Bool, introExtraDegrees: Double = 0) -> some View {
        let col = piece.correctIndex % cols
        let row = piece.correctIndex / cols
        let edges = PieceEdges.profile(col: col, row: row, cols: cols, rows: rows)
        return LivingPieceCell(
            palette: level.syntheticPalette,
            col: col,
            row: row,
            cols: cols,
            rows: rows,
            player: coordinator.player,
            useSynthetic: coordinator.isUsingSyntheticFallback,
            globalTime: globalTime,
            edges: edges,
            isPlaced: piece.isPlaced,
            bloomPulse: glow,
            hideOutlines: admirePhaseActive
        )
        .frame(width: size.width, height: size.height)
        .rotationEffect(piece.rotationAngle + .degrees(introExtraDegrees))
        .animation(.spring(response: 0.45, dampingFraction: 0.76), value: piece.rotationQuarterTurns)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityCombinedLabel(for: piece)))
        .accessibilityHint(Text(String(localized: piece.isPlaced ? "gameplay_audio_hint" : "gameplay_piece_gesture_hint")))
        .accessibilityAddTraits(.isButton)
    }

    private func pieceDragGesture(for piece: DraggablePiece, layout: BoardLayout, geoWidth: CGFloat) -> some Gesture {
        let slop: CGFloat = 14
        return DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStartCenters[piece.id] == nil {
                    dragStartCenters[piece.id] = centers[piece.id] ?? layout.boardMidpoint
                }
                let arm = moveArmedByHold.contains(piece.id)
                let beyondSlop = hypot(value.translation.width, value.translation.height) > slop
                guard arm || beyondSlop else { return }
                let start = dragStartCenters[piece.id] ?? layout.boardMidpoint
                let next = CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height)
                let clamped = layout.clampedUnplacedCenter(next)
                var tx = Transaction()
                tx.animation = .interactiveSpring(response: 0.11, dampingFraction: 0.92)
                withTransaction(tx) {
                    centers[piece.id] = clamped
                }
                activelyDraggedPieceId = piece.id
                dragDidMovePiece.insert(piece.id)
                proximityHaptics(for: piece, at: clamped, layout: layout)
                let nx = max(0, min(1, next.x / max(1, geoWidth)))
                spatial.playTactileAtPan(normalizedX: nx)
            }
            .onEnded { value in
                activelyDraggedPieceId = nil
                let wasArmed = moveArmedByHold.contains(piece.id)
                moveArmedByHold.remove(piece.id)
                let didDrag = dragDidMovePiece.contains(piece.id)
                dragDidMovePiece.remove(piece.id)
                let start = dragStartCenters[piece.id] ?? layout.boardMidpoint
                dragStartCenters[piece.id] = nil
                let tapLike = hypot(value.translation.width, value.translation.height) < slop
                if !didDrag, !wasArmed, tapLike {
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

    private func proximityHaptics(for piece: DraggablePiece, at point: CGPoint, layout: BoardLayout) {
        let target = layout.slotCenter(forIndex: piece.correctIndex)
        let d = hypot(point.x - target.x, point.y - target.y)
        let cellM = min(layout.cell.width, layout.cell.height)
        let hotR = min(100, max(36, cellM * 0.58))
        let enteringHot = d < hotR
        if enteringHot {
            if !hotSnapPieces.contains(piece.id) {
                hotSnapPieces.insert(piece.id)
                HapticsService.playProximitySoft()
            }
        } else {
            hotSnapPieces.remove(piece.id)
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
            p.isPlaced = true
            p.rotationQuarterTurns = 0
            var snapTxn = Transaction()
            snapTxn.disablesAnimations = true
            withTransaction(snapTxn) {
                pieces[index] = p
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                centers[p.id] = target
            }
            HapticsService.playSnapRigid()
            spatial.playSnapLayeredSuccess()
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
        hasBootstrapped = true
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
        let inset = layout.pieceExtentInset
        var spawns: [Int: CGPoint] = [:]
        for pieceId in 0..<slotForPiece.count {
            let minX = inset
            let maxX = w - inset
            let minY = inset
            let maxY = h - inset
            guard minX < maxX, minY < maxY else {
                spawns[pieceId] = layout.boardMidpoint
                continue
            }
            spawns[pieceId] = CGPoint(
                x: CGFloat.random(in: minX...maxX),
                y: CGFloat.random(in: minY...maxY)
            )
        }
        centers = spawns
        var seedScale: [Int: CGFloat] = [:]
        var seedTilt: [Int: Double] = [:]
        for p in pieces {
            seedScale[p.id] = CGFloat.random(in: 0.07...0.16)
            seedTilt[p.id] = Double.random(in: -34...34)
        }
        introPieceScale = seedScale
        introTiltDegrees = seedTilt

        introThrowTask?.cancel()
        introThrowTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)
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
        Self.makeBoardLayout(
            for: geo,
            cols: cols,
            rows: rows,
            contentAspectWidthOverHeight: coordinator.isUsingSyntheticFallback ? nil : coordinator.videoDisplayAspectRatio,
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

    func makeUIView(context: Context) -> VideoFullBoardUIView {
        VideoFullBoardUIView(player: player)
    }

    func updateUIView(_ uiView: VideoFullBoardUIView, context: Context) {
        uiView.replacePlayer(player)
    }
}
