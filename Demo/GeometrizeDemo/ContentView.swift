import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Geometrize

struct ContentView: View {
    @StateObject private var runner = GeometrizeRunner()
    @State private var photoItem: PhotosPickerItem?
    @State private var shareSheet: ShareItem?
    @State private var sampleSourceWarning: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    imagePane
                    statsRow
                    actions
                    presetsCard
                    shapesCard
                    qualityCard
                    backgroundCard
                    exportCard
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Geometrize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Load sample image", systemImage: "photo") { loadSample() }
                        Button("Reset parameters", systemImage: "arrow.counterclockwise") { runner.resetDefaults() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                    }
                }
            }
            .onChange(of: photoItem) { _, newValue in
                Task { await loadPicked(newValue) }
            }
            .sheet(item: $shareSheet) { item in
                ShareView(items: [item.url])
            }
        }
    }

    // MARK: - Image pane

    private var imagePane: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                paneTile(title: "Target", systemIcon: "photo", image: runner.sourceImage)
                paneTile(title: "Approximation", systemIcon: "paintpalette", image: runner.resultImage)
            }
        }
    }

    private func paneTile(title: String, systemIcon: String, image: UIImage?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: systemIcon)
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.tertiarySystemBackground))
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 170)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 10) {
            stat("Shapes", value: "\(runner.shapeCount)", icon: "square.on.square")
            stat("Error", value: String(format: "%.4f", runner.score), icon: "function")
            stat("State", value: runner.isRunning ? "Running" : "Idle", icon: runner.isRunning ? "play.circle" : "pause.circle")
        }
    }

    private func stat(_ label: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption)
            }
            .foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 10) {
            if runner.isRunning {
                Button(role: .destructive) { runner.stop() } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button { runner.start() } label: {
                    Label("Geometrize", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .disabled(runner.sourceImage == nil)
            }

            if let warning = sampleSourceWarning {
                Text(warning).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Presets

    private var presetsCard: some View {
        card(title: "Presets", icon: "wand.and.stars", help: "One-tap parameter bundles to explore the design space.") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Preset.all) { preset in
                        Button {
                            runner.applyPreset(preset)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.name).font(.footnote.weight(.semibold))
                                Text(preset.detail).font(.caption2).foregroundStyle(.secondary)
                            }
                            .frame(width: 180, alignment: .leading)
                            .padding(10)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .disabled(runner.isRunning)
    }

    // MARK: - Shapes card

    private var shapesCard: some View {
        card(title: "Shape Primitives",
             icon: "triangle.fill",
             help: "Pick which shape types the optimizer is allowed to place. More variety usually helps detailed regions.") {
            let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]
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
                        HStack(spacing: 6) {
                            Image(systemName: icon(for: type)).font(.caption)
                            Text(label(for: type)).font(.caption.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .background(selected ? Color.accentColor : Color(.tertiarySystemBackground))
                        .foregroundStyle(selected ? .white : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .disabled(runner.isRunning)
    }

    // MARK: - Quality / runtime card

    private var qualityCard: some View {
        card(title: "Optimization",
             icon: "slider.horizontal.3",
             help: "Higher numbers mean better fits per shape but slower steps. Tweak `alpha` for opacity layering.") {
            VStack(spacing: 14) {
                paramSlider(
                    title: "Alpha",
                    value: $runner.alpha,
                    range: 16...255,
                    format: "%.0f / 255",
                    help: "Opacity of each placed shape. Lower = layered translucent strokes."
                )
                paramSlider(
                    title: "Candidates per step",
                    value: $runner.candidatesPerStep,
                    range: 10...300,
                    format: "%.0f",
                    help: "Random shapes generated each step before hill-climbing. More = better starting point, slower step."
                )
                paramSlider(
                    title: "Mutations per candidate",
                    value: $runner.mutationsPerStep,
                    range: 20...500,
                    format: "%.0f",
                    help: "Hill-climb iterations applied to each candidate. More = finer fit per shape."
                )
                paramSlider(
                    title: "Max image dimension",
                    value: $runner.maxDimension,
                    range: 64...512,
                    format: "%.0f px",
                    help: "Downscale source to this max side before fitting. Smaller = much faster, less detail."
                )
                paramSlider(
                    title: "Shapes per UI refresh",
                    value: $runner.shapesPerBatch,
                    range: 1...20,
                    format: "%.0f",
                    help: "How many shapes to fit between preview refreshes. Higher reduces overhead at the cost of choppier preview."
                )
                paramSlider(
                    title: "Stop at total shapes",
                    value: $runner.targetShapeCount,
                    range: 0...2000,
                    format: { v in v == 0 ? "∞" : "\(Int(v))" },
                    help: "Auto-stop after N shapes. 0 = run until you press Stop."
                )
            }
        }
        .disabled(runner.isRunning)
    }

    // MARK: - Background card

    private var backgroundCard: some View {
        card(title: "Background",
             icon: "square.fill",
             help: "Starting fill of the approximation canvas — usually the image's average color converges fastest.") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Background mode", selection: $runner.backgroundMode) {
                    ForEach(BackgroundMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if runner.backgroundMode == .custom {
                    ColorPicker("Custom color", selection: $runner.customBackgroundColor, supportsOpacity: false)
                        .font(.footnote)
                }
            }
        }
        .disabled(runner.isRunning)
    }

    // MARK: - Export card

    private var exportCard: some View {
        card(title: "Export", icon: "square.and.arrow.up", help: "Export the generated shape stream.") {
            HStack {
                Button {
                    share(filename: "geometrize.svg", contents: runner.exportSVG())
                } label: {
                    Label("SVG", systemImage: "doc.richtext")
                        .frame(maxWidth: .infinity)
                }
                Button {
                    share(filename: "shapes.json", contents: runner.exportJSON())
                } label: {
                    Label("JSON", systemImage: "curlybraces")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .disabled(runner.shapeCount == 0)
        }
    }

    // MARK: - Card helper

    @ViewBuilder
    private func card<Content: View>(title: String, icon: String, help: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
            }
            if let help { Text(help).font(.caption).foregroundStyle(.secondary) }
            content()
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Slider helper

    private func paramSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String, help: String) -> some View {
        paramSlider(title: title, value: value, range: range, format: { String(format: format, $0) }, help: help)
    }

    private func paramSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, format: @escaping (Double) -> String, help: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.footnote.weight(.medium))
                Spacer()
                Text(format(value.wrappedValue))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
            Text(help).font(.caption2).foregroundStyle(.tertiary)
        }
    }

    // MARK: - Helpers

    private func label(for type: ShapeType) -> String {
        switch type {
        case .rectangle: return "Rectangle"
        case .rotatedRectangle: return "Rot. Rect"
        case .triangle: return "Triangle"
        case .ellipse: return "Ellipse"
        case .rotatedEllipse: return "Rot. Ellipse"
        case .circle: return "Circle"
        case .line: return "Line"
        case .quadraticBezier: return "Bezier"
        }
    }

    private func icon(for type: ShapeType) -> String {
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

    private func loadPicked(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
        await MainActor.run {
            sampleSourceWarning = nil
            runner.loadImage(image)
        }
    }

    private func loadSample() {
        // Generate a small synthetic "sample" if no image is on hand — colored gradient circles on a light background.
        let size = CGSize(width: 320, height: 320)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Background gradient.
        let space = CGColorSpaceCreateDeviceRGB()
        let bg = CGGradient(colorsSpace: space,
                            colors: [UIColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 1).cgColor,
                                     UIColor(red: 1.0, green: 0.7, blue: 0.85, alpha: 1).cgColor] as CFArray,
                            locations: [0, 1])!
        ctx.drawLinearGradient(bg, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])

        let palette: [UIColor] = [
            UIColor.systemPurple, UIColor.systemTeal, UIColor.systemOrange,
            UIColor.systemIndigo, UIColor.systemPink, UIColor.systemYellow
        ]
        for i in 0..<6 {
            let r = CGFloat.random(in: 30...90)
            let x = CGFloat.random(in: r...(size.width - r))
            let y = CGFloat.random(in: r...(size.height - r))
            ctx.setFillColor(palette[i].withAlphaComponent(0.85).cgColor)
            ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        if let img = UIGraphicsGetImageFromCurrentImageContext() {
            runner.loadImage(img)
            sampleSourceWarning = "Loaded a generated sample. Tap the photo icon to pick your own image."
        }
    }

    private func share(filename: String, contents: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? contents.write(to: url, atomically: true, encoding: .utf8)
        shareSheet = ShareItem(url: url)
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
}
