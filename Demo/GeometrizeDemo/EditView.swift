import SwiftUI
import Photos
import Geometrize

/// 主要編輯畫面 — 圖在上,浮動圓角卡片在下。
///
/// 卡片四邊都跟螢幕保持 12pt 內距,bottom 距離 = safeArea.bottom + 12,圓角用
/// `UIScreen.concentricRadius(inset: 12)` 跟硬體螢幕同心。
///
/// 兩種狀態,單一容器之間切換:
///   - **collapsed**:狀態 pill(進度/目標 · 風格) + 行動列(Tune / 主按鈕 / 分享)。
///   - **expanded**:grabber + 標題 + 三個純 icon(Style/Shapes/Advanced) + tab content +
///     行動列釘在底。展開時卡片變高,圖片自動擠小。
///
/// BorderBeam 在 `phase == .drawing` 時繞整個螢幕邊跑(顯示器同心圓角)。
struct EditView: View {
    let asset: PHAsset
    @EnvironmentObject var photos: PhotoLibraryService
    @EnvironmentObject var toasts: ToastCenter
    @StateObject private var runner = GeometrizeRunner()

    @State private var sourceLoaded = false
    @State private var peeking = false
    @State private var expanded = false
    @State private var activeTab: TuneTab = .style
    @State private var shareSheet: ShareItem?

    // 卡片幾何
    private let cardInset: CGFloat = 12
    // Inside-card horizontal padding. Needs to be larger than `cardInset` because the squircle
    // curve at the corners (radius ~43pt on iPhone 17 Pro) eats inward — content at 12pt would
    // visually crowd the curve.
    private let contentInset: CGFloat = 18
    private let collapsedHeight: CGFloat = 116
    private let expandedRatio: CGFloat = 0.6
    private let expandedMin: CGFloat = 380
    private let expandedMax: CGFloat = 580

    private var cardCornerRadius: CGFloat { UIScreen.concentricRadius(inset: cardInset) }

    enum TuneTab: String, CaseIterable, Identifiable {
        case style, shapes, advanced
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .style: return "circle.grid.cross"
            case .shapes: return "square.on.circle"
            case .advanced: return "slider.horizontal.3"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let cardH = expanded
                ? min(max(geo.size.height * expandedRatio, expandedMin), expandedMax)
                : collapsedHeight

            ZStack(alignment: .bottom) {
                Color(.systemGroupedBackground).ignoresSafeArea()

                imageArea
                    .padding(.horizontal, cardInset)
                    .padding(.top, 4)
                    .padding(.bottom, cardH + cardInset + 8)

                bottomCard
                    .frame(height: cardH)
                    .padding(.horizontal, cardInset)
                    .padding(.bottom, cardInset)
            }
            // Bouncy spring drives the height + bottom-card morph.
            .animation(.spring(response: 0.5, dampingFraction: 0.68), value: expanded)
        }
        // GeometryReader frame 延伸到螢幕底邊(忽略 bottom safe area),這樣 cardInset (12pt)
        // 才是離螢幕真正底邊的距離,而不是離 safe area 底邊。home indicator 由系統 overlay 在
        // 卡片上方,卡片表面在 indicator 區域延伸也沒問題。
        .ignoresSafeArea(.container, edges: .bottom)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { moreMenu }
        }
        .borderBeam(
            border: Theme.accent,
            hideFadeBorder: true,
            beam: Theme.beamColors,
            beamBlur: 28,
            cornerRadius: UIScreen.displayCornerRadiusAdjusted,
            isEnabled: runner.phase == .drawing
        )
        .sheet(item: $shareSheet) { ExportShareView(items: [$0.url]) }
        .onAppear { loadSource() }
        .onDisappear { runner.stop() }
    }

    // MARK: - Image

    private var imageArea: some View {
        ZStack {
            if let source = runner.sourceImage {
                Image(uiImage: source).resizable().scaledToFit()
                    .opacity(originalOpacity)
            }
            if let result = runner.resultImage, runner.phase != .idle {
                Image(uiImage: result).resizable().scaledToFit()
                    .opacity(resultOpacity)
            }
            if runner.sourceImage == nil {
                ProgressView().tint(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onTapImage() }
        .onLongPressGesture(minimumDuration: 0.1, maximumDistance: 30, perform: {}, onPressingChanged: onLongPress)
        .animation(Theme.crossfade, value: runner.phase)
        .animation(Theme.crossfade, value: peeking)
    }

    private var originalOpacity: Double {
        switch runner.phase {
        case .idle: return 1
        case .drawing: return 0
        case .done: return peeking ? 1 : 0
        }
    }
    private var resultOpacity: Double {
        switch runner.phase {
        case .idle: return 0
        case .drawing: return 1
        case .done: return peeking ? 0 : 1
        }
    }

    // MARK: - Card

    private var bottomCard: some View {
        VStack(spacing: 0) {
            // Top half of the card — only visible when expanded. Slides down + fades when
            // closing, slides in from above + fades when opening.
            if expanded {
                VStack(spacing: 0) {
                    expandedHeader
                    tabBar
                        .padding(.horizontal, contentInset)
                        .padding(.top, 4)
                    ScrollView {
                        Group {
                            switch activeTab {
                            case .style:    styleSection
                            case .shapes:   shapesSection
                            case .advanced: advancedSection
                            }
                        }
                        .padding(.horizontal, contentInset)
                        .padding(.top, 14)
                        .padding(.bottom, 12)
                    }
                    .frame(maxHeight: .infinity)
                    Divider()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            } else {
                // Push the status pill + action row down so they sit tight against the bottom.
                Spacer(minLength: 0)
                statusPills
                    .padding(.bottom, 8)
                    .transition(.scale(scale: 0.92, anchor: .bottom).combined(with: .opacity))
            }

            actionRow
                .padding(.horizontal, contentInset)
                .padding(.top, expanded ? 10 : 0)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(.black.opacity(0.06), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 22, y: 6)
    }

    private var expandedHeader: some View {
        VStack(spacing: 6) {
            Capsule().fill(.tertiary).frame(width: 36, height: 5).padding(.top, 10)
            HStack {
                Text("Tune").font(.headline)
                Spacer()
                Button("Done") {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.68)) { expanded = false }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, contentInset)
            .padding(.top, 2)
        }
    }

    /// 三個純 icon,active 是 primary 顏色,inactive 用 quaternary 灰掉。沒有 capsule、沒有文字。
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(TuneTab.allCases) { tab in
                Button {
                    withAnimation(.spring(duration: 0.25, bounce: 0)) { activeTab = tab }
                } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(activeTab == tab ? .primary : .quaternary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Horizontal strip of small pills — progress, similarity %, style.
    private var statusPills: some View {
        HStack(spacing: 6) {
            progressPill
            if runner.phase != .idle {
                similarityPill
            }
            stylePill
        }
        .padding(.horizontal, contentInset)
    }

    private var progressPill: some View {
        let target = runner.derivedParameters().targetCount
        let text: String = {
            switch runner.phase {
            case .idle:
                return target > 0 ? "0 / \(target)" : "Ready"
            case .drawing, .done:
                return target > 0
                    ? "\(runner.shapeCount) / \(target)"
                    : "\(runner.shapeCount)"
            }
        }()
        return HStack(spacing: 5) {
            phaseDot
            Text(text)
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color(.tertiarySystemFill)))
    }

    /// Similarity = (1 - normalized RMS error). Higher = closer to target image.
    private var similarityPill: some View {
        let similarity = max(0, min(1, 1 - runner.score)) * 100
        return HStack(spacing: 4) {
            Image(systemName: "checkmark.seal.fill")
                .font(.caption2)
                .foregroundStyle(Theme.accent)
            Text(String(format: "%.1f%%", similarity))
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color(.tertiarySystemFill)))
    }

    private var stylePill: some View {
        Text(runner.styleSummary().label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color(.tertiarySystemFill)))
    }

    @ViewBuilder
    private var phaseDot: some View {
        switch runner.phase {
        case .idle:
            Circle().fill(.secondary).frame(width: 6, height: 6)
        case .drawing:
            Circle().fill(Theme.accent).frame(width: 7, height: 7)
                .phaseAnimator([0.4, 1.0]) { content, opacity in content.opacity(opacity) }
                animation: { _ in .easeInOut(duration: 0.6) }
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Theme.accent)
        }
    }

    // MARK: - Action row (collapsed & expanded share this)

    private var actionRow: some View {
        HStack(spacing: 10) {
            chipButton(title: "Tune", systemIcon: "slider.horizontal.3") {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.68)) { expanded.toggle() }
            }
            .disabled(runner.phase == .drawing || runner.sourceImage == nil)

            primaryButton

            chipIconButton(systemName: "square.and.arrow.up") { exportSVG() }
                .disabled(runner.shapeCount == 0)
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        let label: String = {
            switch runner.phase {
            case .idle: return "Geometrize"
            case .drawing: return "Stop"
            case .done: return "Again"
            }
        }()
        let icon: String = {
            switch runner.phase {
            case .idle: return "play.fill"
            case .drawing: return "stop.fill"
            case .done: return "arrow.counterclockwise"
            }
        }()

        Button {
            switch runner.phase {
            case .idle: runner.start()
            case .drawing: runner.stop()
            case .done: runner.reset()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Capsule().fill(runner.phase == .drawing ? Color.red : Theme.accent))
        }
        .buttonStyle(.plain)
        .disabled(runner.sourceImage == nil)
    }

    private func chipButton(title: String, systemIcon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemIcon)
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Capsule().fill(Color(.tertiarySystemFill)))
        }
        .buttonStyle(.plain)
    }

    private func chipIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color(.tertiarySystemFill)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sections

    private var styleSection: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                PhotosStylePositionPad(
                    config: .init(count: 11, size: 130, tint: .primary, circleSize: 3,
                                  touchPointSize: 30, influcenceRadius: 56),
                    position: $runner.padPosition
                )
                .frame(width: 130, height: 130)

                VStack(alignment: .leading, spacing: 6) {
                    Text(runner.styleSummary().label).font(.title3.weight(.semibold))
                    Text(runner.styleSummary().detail).font(.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    HStack(spacing: 12) {
                        miniStat("Cand", "\(runner.derivedParameters().candidates)")
                        miniStat("Mut",  "\(runner.derivedParameters().mutations)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack { cornerLabel("Speed"); Spacer(); cornerLabel("Quality") }
                .frame(width: 130)

            Divider()
            stepSlider
        }
    }

    private var stepSlider: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Stop at").font(.subheadline.weight(.semibold))
                Spacer()
                Text(stepDisplay).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: {
                        runner.useTargetCountOverride
                            ? runner.targetCountOverride
                            : Double(runner.derivedParameters().targetCount)
                    },
                    set: { v in
                        runner.useTargetCountOverride = true
                        runner.targetCountOverride = v
                    }
                ),
                in: 0...3000,
                step: 50
            )
            .tint(Theme.accent)
            HStack {
                Button("Reset to Style") { runner.useTargetCountOverride = false }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(runner.useTargetCountOverride ? Theme.accent : Color(.tertiaryLabel))
                    .disabled(!runner.useTargetCountOverride)
                Spacer()
                Text("0 = unlimited").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private var stepDisplay: String {
        let v = runner.useTargetCountOverride
            ? Int(runner.targetCountOverride)
            : runner.derivedParameters().targetCount
        return v == 0 ? "∞" : "\(v) shapes"
    }

    private func miniStat(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(k).font(.caption2).foregroundStyle(.tertiary).textCase(.uppercase)
            Text(v).font(.subheadline.weight(.semibold).monospacedDigit())
        }
    }

    private func cornerLabel(_ s: String) -> some View {
        Text(s).font(.caption2).foregroundStyle(.tertiary)
    }

    private var shapesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tap to toggle. At least one must remain.")
                .font(.footnote).foregroundStyle(.secondary)
            let columns = [GridItem(.adaptive(minimum: 86), spacing: 8)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(ShapeType.allCases, id: \.rawValue) { type in
                    let selected = runner.shapeTypes.contains(type)
                    Button {
                        if selected {
                            if runner.shapeTypes.count > 1 { runner.shapeTypes.remove(type) }
                        } else {
                            runner.shapeTypes.insert(type)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: shapeIcon(for: type)).font(.caption.weight(.semibold))
                            Text(shapeLabel(for: type)).font(.footnote.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(selected ? Color.primary : Color(.tertiarySystemFill)))
                        .foregroundStyle(selected ? Color(.systemBackground) : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $runner.useOverrides.animation()) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Manual override").font(.subheadline.weight(.semibold))
                    Text("Bypass the Style pad and dial values yourself.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: Theme.accent))

            if runner.useOverrides {
                slider("Alpha", $runner.alphaOverride, 16...255, "%.0f")
                slider("Candidates / step", $runner.candidatesOverride, 10...300, "%.0f")
                slider("Mutations / candidate", $runner.mutationsOverride, 20...500, "%.0f")
                slider("Max dimension", $runner.maxDimensionOverride, 64...512, "%.0f px")
            } else {
                let p = runner.derivedParameters()
                readout("Alpha", "\(p.alpha)")
                readout("Candidates / step", "\(p.candidates)")
                readout("Mutations / candidate", "\(p.mutations)")
                readout("Max dimension", "\(p.maxDimension) px")
            }
        }
    }

    private func readout(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.subheadline)
            Spacer()
            Text(v).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func slider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, _ fmt: String) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(String(format: fmt, value.wrappedValue))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range).tint(Theme.accent)
        }
    }

    // MARK: - Toolbar

    private var moreMenu: some View {
        Menu {
            if runner.phase == .done {
                Button { saveImage() } label: { Label("Save to Photos", systemImage: "square.and.arrow.down") }
                Button { exportSVG() } label: { Label("Export SVG", systemImage: "doc.richtext") }
                Button { exportJSON() } label: { Label("Export JSON", systemImage: "curlybraces") }
                Divider()
            }
            Button(role: .destructive) { runner.reset() } label: { Label("Reset", systemImage: "arrow.counterclockwise") }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .disabled(runner.phase == .idle)
    }

    // MARK: - Gestures

    private func onTapImage() {
        guard runner.phase == .idle, runner.sourceImage != nil else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if expanded { withAnimation(.spring(response: 0.5, dampingFraction: 0.68)) { expanded = false } }
        runner.start()
    }
    private func onLongPress(_ pressing: Bool) {
        guard runner.phase == .done else { return }
        if pressing { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
        peeking = pressing
    }

    // MARK: - Actions

    private func loadSource() {
        guard !sourceLoaded else { return }
        sourceLoaded = true
        photos.fullImage(for: asset, maxDimension: 1024) { image in
            Task { @MainActor in
                if let image { self.runner.loadImage(image) }
            }
        }
    }
    private func saveImage() {
        guard let img = runner.resultImage else { return }
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        toasts.show(Toast(symbol: "checkmark.circle.fill", title: "Saved to Photos"))
    }
    private func exportSVG() {
        let svg = runner.exportSVG()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("geometrize.svg")
        try? svg.write(to: url, atomically: true, encoding: .utf8)
        shareSheet = ShareItem(url: url)
    }
    private func exportJSON() {
        let json = runner.exportJSON()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("shapes.json")
        try? json.write(to: url, atomically: true, encoding: .utf8)
        shareSheet = ShareItem(url: url)
    }

    private func shapeLabel(for type: ShapeType) -> String {
        switch type {
        case .rectangle: return "Rect"
        case .rotatedRectangle: return "Rot Rect"
        case .triangle: return "Triangle"
        case .ellipse: return "Ellipse"
        case .rotatedEllipse: return "Rot Ellipse"
        case .circle: return "Circle"
        case .line: return "Line"
        case .quadraticBezier: return "Bezier"
        }
    }
    private func shapeIcon(for type: ShapeType) -> String {
        switch type {
        case .rectangle: return "rectangle"
        case .rotatedRectangle: return "rectangle.portrait.rotate"
        case .triangle: return "triangle"
        case .ellipse: return "oval"
        case .rotatedEllipse: return "oval.portrait"
        case .circle: return "circle"
        case .line: return "line.diagonal"
        case .quadraticBezier: return "scribble"
        }
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ExportShareView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
