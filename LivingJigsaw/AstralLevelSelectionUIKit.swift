import AVFoundation
import UIKit

// MARK: - interpolateColor (The Astral Path — nền chuyển màu theo cuộn)

func interpolateColor(from a: UIColor, to b: UIColor, t: CGFloat) -> UIColor {
    let u = max(0, min(1, t))
    func rgba(_ c: UIColor) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        if let comps = c.cgColor.components, comps.count >= 3 {
            let alpha = comps.count > 3 ? comps[3] : 1
            return (comps[0], comps[1], comps[2], alpha)
        }
        var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, al: CGFloat = 0
        if c.getRed(&r, green: &g, blue: &bl, alpha: &al) { return (r, g, bl, al) }
        return (0, 0, 0, 1)
    }
    let A = rgba(a), B = rgba(b)
    return UIColor(
        red: A.0 + (B.0 - A.0) * u,
        green: A.1 + (B.1 - A.1) * u,
        blue: A.2 + (B.2 - A.2) * u,
        alpha: A.3 + (B.3 - A.3) * u
    )
}

// MARK: - Bundle video URL → `LevelVideoCatalog`

enum LevelBundleVideoURL {
    static func url(forLevelId levelId: Int) -> URL? {
        LevelVideoCatalog.bundleVideoURL(forLevelId: levelId)
    }
}

// MARK: - Màu nền / aura theo từng level (khớp SyntheticPalette trong LevelDefinition)

enum AstralLevelPaletteUIColor {
    static func deep(for levelId: Int) -> UIColor {
        switch levelId {
        case 1: return UIColor(red: 0.04, green: 0.12, blue: 0.10, alpha: 1)
        case 2: return UIColor(red: 0.06, green: 0.08, blue: 0.14, alpha: 1)
        case 3: return UIColor(red: 0.12, green: 0.05, blue: 0.05, alpha: 1)
        case 4: return UIColor(red: 0.02, green: 0.06, blue: 0.14, alpha: 1)
        case 5: return UIColor(red: 0.04, green: 0.05, blue: 0.12, alpha: 1)
        case 6: return UIColor(red: 0.10, green: 0.05, blue: 0.02, alpha: 1)
        case 7: return UIColor(red: 0.06, green: 0.04, blue: 0.08, alpha: 1)
        case 8: return UIColor(red: 0.02, green: 0.08, blue: 0.10, alpha: 1)
        case 9: return UIColor(red: 0.06, green: 0.02, blue: 0.12, alpha: 1)
        case 10: return UIColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 1)
        case 11: return UIColor(red: 0.04, green: 0.04, blue: 0.12, alpha: 1)
        case 12: return UIColor(red: 0.03, green: 0.08, blue: 0.06, alpha: 1)
        default: return UIColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1)
        }
    }

    static func aura(for levelId: Int) -> UIColor {
        switch levelId {
        case 1: return UIColor(red: 0.25, green: 0.72, blue: 0.55, alpha: 1)
        case 2: return UIColor(red: 0.45, green: 0.75, blue: 0.95, alpha: 1)
        case 3: return UIColor(red: 0.98, green: 0.82, blue: 0.35, alpha: 1)
        case 4: return UIColor(red: 0.75, green: 0.88, blue: 1.0, alpha: 1)
        case 5: return UIColor(red: 0.25, green: 0.85, blue: 0.92, alpha: 1)
        case 6: return UIColor(red: 1.0, green: 0.78, blue: 0.35, alpha: 1)
        case 7: return UIColor(red: 0.55, green: 0.35, blue: 0.98, alpha: 1)
        case 8: return UIColor(red: 0.72, green: 0.35, blue: 0.98, alpha: 1)
        case 9: return UIColor(red: 0.45, green: 0.25, blue: 0.98, alpha: 1)
        case 10: return UIColor(red: 0.55, green: 0.92, blue: 0.95, alpha: 1)
        case 11: return UIColor(red: 0.35, green: 0.92, blue: 0.72, alpha: 1)
        case 12: return UIColor(red: 0.85, green: 0.95, blue: 0.35, alpha: 1)
        default: return UIColor(red: 0.55, green: 0.85, blue: 1.0, alpha: 1)
        }
    }
}

// MARK: - Cell

final class AstralLevelCell: UICollectionViewCell {
    static let reuseId = "AstralLevelCell"

    private let parallaxHost = UIView()
    private let diskContainer = UIView()
    private let thumbView = UIImageView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let auraLayer = CAShapeLayer()
    private let lockView = UIImageView(image: UIImage(systemName: "lock.fill"))
    private let checkView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
    private let titleLabel = UILabel()
    private let idLabel = UILabel()

    var levelId: Int = 0
    var videoHost: UIView { diskContainer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear
        
        // Start với alpha = 0 và scale nhỏ cho fade in animation
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.85, y: 0.85)

        parallaxHost.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(parallaxHost)

        diskContainer.translatesAutoresizingMaskIntoConstraints = false
        diskContainer.clipsToBounds = true
        diskContainer.layer.cornerCurve = .continuous
        parallaxHost.addSubview(diskContainer)

        thumbView.translatesAutoresizingMaskIntoConstraints = false
        thumbView.contentMode = .scaleAspectFit
        thumbView.clipsToBounds = true
        diskContainer.addSubview(thumbView)

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.alpha = 0.92
        diskContainer.addSubview(blurView)

        auraLayer.fillColor = UIColor.clear.cgColor
        auraLayer.strokeColor = UIColor.white.cgColor
        auraLayer.lineWidth = 4
        diskContainer.layer.addSublayer(auraLayer)

        lockView.translatesAutoresizingMaskIntoConstraints = false
        lockView.tintColor = UIColor.white.withAlphaComponent(0.45)
        lockView.isHidden = true
        diskContainer.addSubview(lockView)

        checkView.translatesAutoresizingMaskIntoConstraints = false
        checkView.tintColor = UIColor(red: 0.95, green: 0.82, blue: 0.45, alpha: 1)
        checkView.isHidden = true
        diskContainer.addSubview(checkView)

        idLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        idLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        idLabel.translatesAutoresizingMaskIntoConstraints = false
        parallaxHost.addSubview(idLabel)

        titleLabel.font = .preferredFont(forTextStyle: .caption1)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        titleLabel.numberOfLines = 2
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        parallaxHost.addSubview(titleLabel)

        let diskSize: CGFloat = 132
        NSLayoutConstraint.activate([
            parallaxHost.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            parallaxHost.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            parallaxHost.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.92),
            parallaxHost.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            diskContainer.widthAnchor.constraint(equalToConstant: diskSize),
            diskContainer.heightAnchor.constraint(equalToConstant: diskSize),
            diskContainer.topAnchor.constraint(equalTo: parallaxHost.topAnchor, constant: 8),
            diskContainer.centerXAnchor.constraint(equalTo: parallaxHost.centerXAnchor),

            thumbView.topAnchor.constraint(equalTo: diskContainer.topAnchor),
            thumbView.leadingAnchor.constraint(equalTo: diskContainer.leadingAnchor),
            thumbView.trailingAnchor.constraint(equalTo: diskContainer.trailingAnchor),
            thumbView.bottomAnchor.constraint(equalTo: diskContainer.bottomAnchor),

            blurView.topAnchor.constraint(equalTo: diskContainer.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: diskContainer.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: diskContainer.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: diskContainer.bottomAnchor),

            lockView.centerXAnchor.constraint(equalTo: diskContainer.centerXAnchor),
            lockView.centerYAnchor.constraint(equalTo: diskContainer.centerYAnchor),

            checkView.centerXAnchor.constraint(equalTo: diskContainer.centerXAnchor),
            checkView.centerYAnchor.constraint(equalTo: diskContainer.centerYAnchor),

            idLabel.topAnchor.constraint(equalTo: diskContainer.bottomAnchor, constant: 8),
            idLabel.centerXAnchor.constraint(equalTo: parallaxHost.centerXAnchor),

            titleLabel.topAnchor.constraint(equalTo: idLabel.bottomAnchor, constant: 2),
            titleLabel.leadingAnchor.constraint(equalTo: parallaxHost.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: parallaxHost.trailingAnchor, constant: -4)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        diskContainer.layer.cornerRadius = diskContainer.bounds.width * 0.5
        let r = diskContainer.bounds.insetBy(dx: 2, dy: 2)
        auraLayer.path = UIBezierPath(ovalIn: r).cgPath
        auraLayer.frame = diskContainer.bounds
    }

    func configure(
        level: LevelDefinition,
        unlocked: Bool,
        cleared: Bool,
        zigOffset: CGFloat,
        thumbnail: UIImage?
    ) {
        levelId = level.id
        titleLabel.text = String(localized: String.LocalizationValue(level.titleKey))
        idLabel.text = "#\(level.id)"
        lockView.isHidden = unlocked
        checkView.isHidden = !cleared
        thumbView.image = thumbnail
        thumbView.backgroundColor = AstralLevelPaletteUIColor.deep(for: level.id)
        parallaxHost.transform = CGAffineTransform(translationX: zigOffset, y: 0)
        
        // Fade in animation khi cell được configure lần đầu
        if alpha < 0.1 {
            UIView.animate(
                withDuration: 0.6,
                delay: 0,
                usingSpringWithDamping: 0.75,
                initialSpringVelocity: 0.3,
                options: [.curveEaseOut]
            ) {
                self.alpha = 0.75  // Default alpha khi không focus
                self.transform = .identity
            }
        }
    }

    func applyFocusState(focused: Bool, auraColor: UIColor, showVideo: Bool) {
        let scale: CGFloat = focused ? 1.25 : 1.0
        let alpha: CGFloat = focused ? 1.0 : 0.75
        
        // Smooth spring animation cho scale và fade
        UIView.animate(
            withDuration: 0.65,
            delay: 0,
            usingSpringWithDamping: 0.72,
            initialSpringVelocity: 0.4,
            options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]
        ) {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
            self.alpha = alpha
        }
        
        // Smooth fade cho aura glow
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.55)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        
        auraLayer.strokeColor = auraColor.cgColor
        auraLayer.opacity = focused ? 1 : 0
        auraLayer.shadowColor = auraColor.cgColor
        auraLayer.shadowRadius = focused ? 14 : 0
        auraLayer.shadowOpacity = focused ? 0.9 : 0
        auraLayer.shadowOffset = .zero
        
        CATransaction.commit()

        // Smooth fade cho blur và thumb
        UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseInOut]) {
            self.blurView.alpha = (showVideo && focused) ? 0 : 0.92
            self.thumbView.alpha = (showVideo && focused) ? 0 : 1.0
        } completion: { _ in
            self.blurView.isHidden = showVideo && focused
            self.thumbView.isHidden = showVideo && focused
        }
    }

    func setParallax(zigOffset: CGFloat, extraY: CGFloat) {
        parallaxHost.transform = CGAffineTransform(translationX: zigOffset, y: extraY)
    }
}

// MARK: - ViewController

final class AstralLevelSelectionViewController: UIViewController, UICollectionViewDelegate {
    var onPickLevel: ((LevelDefinition) -> Void)?

    private var levels: [LevelDefinition] = LevelDefinition.all.sorted { $0.id < $1.id }
    private let rowHeight: CGFloat = 268
    private let zig: CGFloat = 76

    private let bgGradient = CAGradientLayer()
    private let glowHost = UIView()
    private let glowShape = CAShapeLayer()
    private let glowGradientLayer = CAGradientLayer()
    private var collectionView: UICollectionView!

    private var thumbnailCache: [Int: UIImage] = [:]
    private var focusedIndex: Int = 0
    private var previewPlayer: AVPlayer?
    private var previewLayer: AVPlayerLayer?
    private weak var hostingCell: AstralLevelCell?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        bgGradient.type = .radial
        bgGradient.colors = [
            AstralLevelPaletteUIColor.deep(for: 1).cgColor,
            UIColor.black.cgColor
        ]
        bgGradient.locations = [0, 1]
        bgGradient.startPoint = CGPoint(x: 0.5, y: 0.35)
        bgGradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        view.layer.insertSublayer(bgGradient, at: 0)

        glowHost.isUserInteractionEnabled = false
        glowHost.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(glowHost)

        glowGradientLayer.type = .axial
        glowGradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.55).cgColor,
            UIColor(red: 0.45, green: 0.85, blue: 1.0, alpha: 0.65).cgColor,
            UIColor(red: 0.65, green: 0.35, blue: 0.98, alpha: 0.5).cgColor,
            UIColor.clear.cgColor
        ]
        glowGradientLayer.locations = [0, 0.25, 0.5, 0.72, 1]
        glowGradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        glowGradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        glowHost.layer.addSublayer(glowGradientLayer)

        glowShape.fillColor = UIColor.clear.cgColor
        glowShape.strokeColor = UIColor.white.cgColor
        glowShape.lineWidth = 5
        glowShape.lineCap = .round
        glowShape.lineJoin = .round
        glowShape.lineDashPattern = [10, 8]
        glowGradientLayer.mask = glowShape

        let glowFlow = CABasicAnimation(keyPath: "locations")
        glowFlow.fromValue = [0, 0.18, 0.42, 0.65, 0.88]
        glowFlow.toValue = [0.12, 0.35, 0.58, 0.82, 1.0]
        glowFlow.duration = 3.2
        glowFlow.repeatCount = .infinity
        glowFlow.autoreverses = true
        glowGradientLayer.add(glowFlow, forKey: "glowDrift")

        let flow = makeLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: flow)
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.decelerationRate = .normal  // Smooth deceleration cho cảm giác cuộn tự nhiên hơn
        collectionView.register(AstralLevelCell.self, forCellWithReuseIdentifier: AstralLevelCell.reuseId)
        collectionView.dataSource = self
        view.addSubview(collectionView)

        let hint = UILabel()
        hint.translatesAutoresizingMaskIntoConstraints = false
        hint.text = String(localized: String.LocalizationValue("level_map_hint"))
        hint.font = .preferredFont(forTextStyle: .caption1)
        hint.textColor = UIColor.white.withAlphaComponent(0.68)
        hint.textAlignment = .center
        hint.numberOfLines = 0
        view.addSubview(hint)

        NSLayoutConstraint.activate([
            glowHost.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            glowHost.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            glowHost.topAnchor.constraint(equalTo: view.topAnchor),
            glowHost.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            hint.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            hint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            hint.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),

            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 8),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let dashAnim = CABasicAnimation(keyPath: "lineDashPhase")
        dashAnim.fromValue = 0
        dashAnim.toValue = 48
        dashAnim.duration = 2.2
        dashAnim.repeatCount = .infinity
        glowShape.add(dashAnim, forKey: "flow")

        preloadThumbnails()
    }

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [weak self] _, environment in
            guard let self else {
                return Self.fallbackSection()
            }
            let h = environment.container.effectiveContentSize.height
            let inset = max(72, (h - self.rowHeight) * 0.48)
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(self.rowHeight)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(self.rowHeight)),
                subitems: [item]
            )
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 0
            section.contentInsets = NSDirectionalEdgeInsets(top: inset, leading: 16, bottom: inset, trailing: 16)
            return section
        }
    }

    private static func fallbackSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(268))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(268)),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 120, leading: 16, bottom: 120, trailing: 16)
        return section
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bgGradient.frame = view.bounds
        glowShape.frame = glowHost.bounds
        updateGlowPath()
        updateBackgroundForScrollPosition()
        if let cell = hostingCell {
            previewLayer?.frame = cell.videoHost.bounds
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateFocusAndParallax()
        attachPreviewIfNeeded()
    }

    private func preloadThumbnails() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            for level in self.levels {
                guard let url = LevelBundleVideoURL.url(forLevelId: level.id) else { continue }
                let asset = AVURLAsset(url: url)
                let gen = AVAssetImageGenerator(asset: asset)
                gen.appliesPreferredTrackTransform = true
                gen.maximumSize = CGSize(width: 360, height: 360)
                let t = CMTime(seconds: 0.35, preferredTimescale: 600)
                do {
                    let cg = try gen.copyCGImage(at: t, actualTime: nil)
                    let img = UIImage(cgImage: cg)
                    DispatchQueue.main.async {
                        self.thumbnailCache[level.id] = img
                        if let idx = self.levels.firstIndex(where: { $0.id == level.id }) {
                            self.collectionView.reloadItems(at: [IndexPath(item: idx, section: 0)])
                        }
                    }
                } catch {
                    continue
                }
            }
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateFocusAndParallax()
        updateGlowPath()
        updateBackgroundForScrollPosition()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        attachPreviewIfNeeded()
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        guard let cv = scrollView as? UICollectionView else { return }
        let proposedY = targetContentOffset.pointee.y
        let centerY = proposedY + cv.bounds.height * 0.5
        var best = 0
        var bestDist = CGFloat.greatestFiniteMagnitude
        for i in 0..<levels.count {
            guard let attr = cv.layoutAttributesForItem(at: IndexPath(item: i, section: 0)) else { continue }
            let d = abs(attr.center.y - centerY)
            if d < bestDist {
                bestDist = d
                best = i
            }
        }
        if let attr = cv.layoutAttributesForItem(at: IndexPath(item: best, section: 0)) {
            let targetY = attr.center.y - cv.bounds.height * 0.5
            
            // Sử dụng spring animation cho snap mượt mà với gia tốc tự nhiên
            targetContentOffset.pointee = cv.contentOffset  // Cancel default deceleration
            
            UIView.animate(
                withDuration: 0.75,
                delay: 0,
                usingSpringWithDamping: 0.82,
                initialSpringVelocity: abs(velocity.y * 0.15),  // Kế thừa velocity từ gesture
                options: [.curveEaseOut, .allowUserInteraction]
            ) {
                cv.setContentOffset(CGPoint(x: cv.contentOffset.x, y: targetY), animated: false)
            }
        }
    }

    private func updateFocusAndParallax() {
        let cv = collectionView!
        let centerY = cv.contentOffset.y + cv.bounds.height * 0.5

        var newFocus = 0
        var best = CGFloat.greatestFiniteMagnitude
        for i in 0..<levels.count {
            guard let attr = cv.layoutAttributesForItem(at: IndexPath(item: i, section: 0)) else { continue }
            let d = abs(attr.center.y - centerY)
            if d < best {
                best = d
                newFocus = i
            }
        }

        let focusChanged = newFocus != focusedIndex
        focusedIndex = newFocus

        for i in 0..<levels.count {
            guard let cell = cv.cellForItem(at: IndexPath(item: i, section: 0)) as? AstralLevelCell else { continue }
            let level = levels[i]
            let zigOffset = (i % 2 == 0) ? -zig : zig
            guard let attr = cv.layoutAttributesForItem(at: IndexPath(item: i, section: 0)) else { continue }
            let parallax = (attr.center.y - centerY) * 0.1
            cell.setParallax(zigOffset: zigOffset, extraY: parallax)

            let focused = i == focusedIndex
            let aura = AstralLevelPaletteUIColor.aura(for: level.id)
            let unlocked = GameProgress.isLevelUnlocked(level.id)
            let showVideo = unlocked && focused
            cell.applyFocusState(focused: focused, auraColor: aura, showVideo: showVideo)
        }

        if focusChanged {
            attachPreviewIfNeeded()
        } else {
            previewLayer?.frame = hostingCell?.videoHost.bounds ?? .zero
        }
    }

    private func attachPreviewIfNeeded() {
        previewLayer?.removeFromSuperlayer()
        previewPlayer?.pause()
        previewPlayer = nil
        previewLayer = nil
        hostingCell = nil

        let level = levels[focusedIndex]
        guard GameProgress.isLevelUnlocked(level.id),
              let url = LevelBundleVideoURL.url(forLevelId: level.id),
              let cell = collectionView.cellForItem(at: IndexPath(item: focusedIndex, section: 0)) as? AstralLevelCell
        else { return }

        let player = AVPlayer(url: url)
        player.isMuted = true
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        let host = cell.videoHost
        host.layoutIfNeeded()
        layer.frame = host.bounds
        host.layer.addSublayer(layer)
        player.play()
        previewPlayer = player
        previewLayer = layer
        hostingCell = cell
        cell.applyFocusState(focused: true, auraColor: AstralLevelPaletteUIColor.aura(for: level.id), showVideo: true)
    }

    private func updateBackgroundForScrollPosition() {
        let cv = collectionView!
        let centerY = cv.contentOffset.y + cv.bounds.height * 0.5
        var closest = 0
        var best = CGFloat.greatestFiniteMagnitude
        for i in 0..<levels.count {
            guard let attr = cv.layoutAttributesForItem(at: IndexPath(item: i, section: 0)) else { continue }
            let d = abs(attr.center.y - centerY)
            if d < best {
                best = d
                closest = i
            }
        }
        let next = min(closest + 1, levels.count - 1)
        guard let a = cv.layoutAttributesForItem(at: IndexPath(item: closest, section: 0)),
              let b = cv.layoutAttributesForItem(at: IndexPath(item: next, section: 0))
        else { return }
        let span = b.center.y - a.center.y
        let u = span != 0 ? (centerY - a.center.y) / span : 0
        let t = max(0, min(1, u))
        let from = AstralLevelPaletteUIColor.deep(for: levels[closest].id)
        let to = AstralLevelPaletteUIColor.deep(for: levels[next].id)
        let mid = closest == next ? from : interpolateColor(from: from, to: to, t: t)
        let outer = interpolateColor(from: mid, to: UIColor.black, t: 0.55)
        bgGradient.colors = [mid.cgColor, outer.cgColor]
    }

    private func updateGlowPath() {
        let cv = collectionView!
        var centers: [CGPoint] = []
        for i in 0..<levels.count {
            guard let attr = cv.layoutAttributesForItem(at: IndexPath(item: i, section: 0)) else { continue }
            let pt: CGPoint
            if let cell = cv.cellForItem(at: IndexPath(item: i, section: 0)) as? AstralLevelCell {
                let m = CGPoint(x: cell.videoHost.bounds.midX, y: cell.videoHost.bounds.midY)
                pt = cell.videoHost.convert(m, to: glowHost)
            } else {
                var c = cv.convert(attr.center, to: glowHost)
                let zigOffset: CGFloat = (i % 2 == 0) ? -zig : zig
                c.x += zigOffset
                pt = c
            }
            centers.append(pt)
        }
        guard centers.count > 1 else { return }
        let path = UIBezierPath()
        path.move(to: centers[0])
        for i in 0..<(centers.count - 1) {
            let p0 = centers[i]
            let p1 = centers[i + 1]
            let mid = CGPoint(x: (p0.x + p1.x) * 0.5, y: (p0.y + p1.y) * 0.5)
            let dx = p1.x - p0.x
            let dy = p1.y - p0.y
            let len = max(hypot(dx, dy), 1)
            let nx = -dy / len
            let ny = dx / len
            let wave = CGFloat(sin(Double(i) * 0.88 + 0.15) * 36 + cos(Double(i) * 0.47) * 14)
            let ctrl = CGPoint(x: mid.x + nx * wave, y: mid.y + ny * wave)
            path.addQuadCurve(to: p1, controlPoint: ctrl)
        }
        glowGradientLayer.frame = glowHost.bounds
        glowShape.frame = CGRect(origin: .zero, size: glowHost.bounds.size)
        glowShape.path = path.cgPath
    }

    func openFocusedLevel() {
        let level = levels[focusedIndex]
        guard GameProgress.isLevelUnlocked(level.id) else { return }
        GameProgress.currentLevelId = level.id
        onPickLevel?(level)
    }
}

extension AstralLevelSelectionViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        levels.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AstralLevelCell.reuseId, for: indexPath) as! AstralLevelCell
        let level = levels[indexPath.item]
        let zigOffset = (indexPath.item % 2 == 0) ? -zig : zig
        cell.configure(
            level: level,
            unlocked: GameProgress.isLevelUnlocked(level.id),
            cleared: GameProgress.isLevelCleared(level.id),
            zigOffset: zigOffset,
            thumbnail: thumbnailCache[level.id]
        )
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        focusedIndex = indexPath.item
        attachPreviewIfNeeded()
        openFocusedLevel()
    }
}
