import AVFoundation
import SwiftUI

/// La caméra FLASHA : prête dès l'ouverture. Appui court pour une photo, appui long
/// pour filmer, pincer pour zoomer, toucher pour faire la mise au point.
struct CameraScreen: View {
    @Environment(AppStore.self) private var store
    @State private var controller = CameraController()
    @State private var authorized = false
    @State private var flash: AVCaptureDevice.FlashMode = .auto
    @State private var showsGrid = false
    @State private var zoom: CGFloat = 1
    @State private var zoomAtStart: CGFloat = 1
    @State private var focusPoint: CGPoint?
    @State private var flashOverlay = false
    @State private var recording = false
    @State private var recordProgress: CGFloat = 0
    @State private var captured: CapturedPhoto?
    @State private var recorded: EncodedVideo?
    @State private var converting = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                viewfinder(size: proxy.size)
                if showsGrid {
                    GridOverlay().allowsHitTesting(false)
                }
                if let focusPoint {
                    Circle()
                        .stroke(.yellow, lineWidth: 2)
                        .frame(width: 70, height: 70)
                        .position(focusPoint)
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }
                Color.white
                    .opacity(flashOverlay ? 0.9 : 0)
                    .allowsHitTesting(false)
                controls
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Theme.night)
        .task {
            authorized = await CameraController.requestAccess()
            if authorized {
                controller.start()
            }
        }
        .onDisappear { controller.stop() }
        .overlay {
            if converting {
                VStack(spacing: 12) {
                    ProgressView().controlSize(.large).tint(.white)
                    Text("Conversion en FLASHA Vidéo…").font(.headline)
                }
                .foregroundStyle(.white)
                .padding(28)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            }
        }
        .fullScreenCover(item: $recorded) { video in
            VideoEditorView(video: video)
                .environment(store)
        }
        .fullScreenCover(item: $captured) { photo in
            EditorView(image: photo.image)
                .environment(store)
        }
    }

    @ViewBuilder
    private func viewfinder(size: CGSize) -> some View {
        Group {
            if authorized && CameraController.isAvailable {
                CameraPreview(controller: controller)
            } else {
                ZStack {
                    Theme.gradient
                    VStack(spacing: 12) {
                        Image(systemName: "camera.aperture")
                            .font(.system(size: 56))
                            .symbolEffect(.pulse)
                        Text(authorized ? "Caméra indisponible : mode démonstration" : "Autorisez la caméra dans Réglages")
                            .font(.callout.weight(.semibold))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.white)
                    .padding(32)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
            controller.focus(at: CGPoint(x: location.x / size.width, y: location.y / size.height))
            withAnimation(.spring(duration: 0.3)) { focusPoint = location }
            Task {
                try? await Task.sleep(for: .seconds(1))
                withAnimation { focusPoint = nil }
            }
        }
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    zoom = max(1, min(zoomAtStart * value.magnification, 8))
                    controller.zoom(to: zoom)
                }
                .onEnded { _ in zoomAtStart = zoom }
        )
    }

    private var controls: some View {
        VStack {
            HStack {
                Text("flasha")
                    .font(.system(.title2, design: .serif, weight: .heavy).italic())
                    .foregroundStyle(.white)
                Spacer()
                VStack(spacing: 14) {
                    roundButton(flashSymbol, label: "Flash") { cycleFlash() }
                    roundButton("arrow.triangle.2.circlepath.camera", label: "Changer de caméra") {
                        controller.switchCamera()
                    }
                    roundButton(showsGrid ? "grid.circle.fill" : "grid.circle", label: "Grille") {
                        showsGrid.toggle()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 64)

            Spacer()

            if zoom > 1.05 {
                Text(String(format: "%.1f×", Double(zoom)))
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.4), in: Capsule())
                    .foregroundStyle(.white)
            }

            shutter
                .padding(.bottom, 24)
        }
    }

    private var shutter: some View {
        ZStack {
            Circle()
                .stroke(.white, lineWidth: 5)
                .frame(width: 84, height: 84)
            Circle()
                .trim(from: 0, to: recordProgress)
                .stroke(Color.red, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 84, height: 84)
            Circle()
                .fill(recording ? AnyShapeStyle(Color.red) : AnyShapeStyle(Theme.halo))
                .frame(width: recording ? 44 : 68, height: recording ? 44 : 68)
        }
        .animation(.spring(duration: 0.3), value: recording)
        .contentShape(Circle())
        .onTapGesture { takePhoto() }
        .onLongPressGesture(minimumDuration: 0.3, maximumDistance: 40) {
            startRecording()
        } onPressingChanged: { pressing in
            if !pressing {
                stopRecording()
            }
        }
        .accessibilityLabel("Déclencheur")
        .accessibilityHint("Toucher pour une photo, maintenir pour filmer")
        .accessibilityAddTraits(.isButton)
    }

    private var flashSymbol: String {
        switch flash {
        case .on: "bolt.fill"
        case .off: "bolt.slash.fill"
        default: "bolt.badge.automatic.fill"
        }
    }

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(label)
    }

    private func cycleFlash() {
        switch flash {
        case .auto: flash = .on
        case .on: flash = .off
        default: flash = .auto
        }
    }

    private func takePhoto() {
        withAnimation(.easeOut(duration: 0.05)) { flashOverlay = true }
        withAnimation(.easeOut(duration: 0.4).delay(0.05)) { flashOverlay = false }
        guard authorized && CameraController.isAvailable else {
            // Le simulateur n'a pas de caméra : une photo de démonstration.
            captured = CapturedPhoto(image: .flashaPlaceholder())
            return
        }
        let mode = flash
        Task {
            if let image = await controller.capture(flash: mode) {
                captured = CapturedPhoto(image: image)
            }
        }
    }

    // L'appui long filme ; au relâchement, la vidéo est convertie en FLASHA Vidéo.
    private func startRecording() {
        recording = true
        recordProgress = 0
        withAnimation(.linear(duration: FlashaFormat.Video.maxDuration)) { recordProgress = 1 }
        if authorized && CameraController.isAvailable {
            controller.startRecording()
        }
    }

    private func stopRecording() {
        guard recording else { return }
        recording = false
        withAnimation(.easeOut(duration: 0.2)) { recordProgress = 0 }
        Task {
            guard let raw = await controller.stopRecording() else { return }
            converting = true
            let destination = MediaStore.shared.temporaryURL(kind: .video)
            recorded = try? await VideoEncoder.encode(raw, to: destination)
            converting = false
            try? FileManager.default.removeItem(at: raw)
        }
    }
}

/// Une photo prise, pour ouvrir l'éditeur.
struct CapturedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// La grille de cadrage : les tiers.
struct GridOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                for i in 1...2 {
                    let x = proxy.size.width * CGFloat(i) / 3
                    let y = proxy.size.height * CGFloat(i) / 3
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
            }
            .stroke(.white.opacity(0.35), lineWidth: 1)
        }
    }
}
