@preconcurrency import AVFoundation
import UIKit

/// La caméra : une session AVFoundation, configurée et pilotée sur sa propre file,
/// pour que l'interface reste fluide pendant l'ouverture de la caméra.
nonisolated final class CameraController: NSObject, @unchecked Sendable, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "app.flasha.camera")
    private let photoOutput = AVCapturePhotoOutput()
    private var input: AVCaptureDeviceInput?
    private var completion: (@Sendable (UIImage?) -> Void)?

    /// Demande l'accès à la caméra si nécessaire.
    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    /// `false` sur le simulateur, qui n'a pas de caméra.
    static var isAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
            || AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

    func start() {
        queue.async { [self] in
            if session.inputs.isEmpty {
                configure(position: .back)
            }
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func configure(position: AVCaptureDevice.Position) {
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
           let newInput = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(newInput) {
            session.addInput(newInput)
            input = newInput
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
        }
        session.commitConfiguration()
    }

    /// Passe de la caméra arrière à la caméra avant, et inversement.
    func switchCamera() {
        queue.async { [self] in
            let next: AVCaptureDevice.Position = input?.device.position == .back ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: next),
                  let newInput = try? AVCaptureDeviceInput(device: device)
            else { return }
            session.beginConfiguration()
            if let input {
                session.removeInput(input)
            }
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                input = newInput
            } else if let input {
                session.addInput(input)
            }
            session.commitConfiguration()
        }
    }

    /// Zoom progressif, de 1× à 8× (selon l'objectif).
    func zoom(to factor: CGFloat) {
        queue.async { [self] in
            guard let device = input?.device, (try? device.lockForConfiguration()) != nil else { return }
            let maximum = min(device.activeFormat.videoMaxZoomFactor, 8)
            device.videoZoomFactor = max(1, min(factor, maximum))
            device.unlockForConfiguration()
        }
    }

    /// Mise au point et exposition tactiles ; `point` va de (0, 0) à (1, 1).
    func focus(at point: CGPoint) {
        queue.async { [self] in
            guard let device = input?.device, (try? device.lockForConfiguration()) != nil else { return }
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        }
    }

    /// Prend une photo ; `nil` si la caméra n'est pas disponible.
    func capture(flash: AVCaptureDevice.FlashMode, _ completion: @escaping @Sendable (UIImage?) -> Void) {
        queue.async { [self] in
            guard session.isRunning, !session.inputs.isEmpty else {
                completion(nil)
                return
            }
            let settings = AVCapturePhotoSettings()
            if photoOutput.supportedFlashModes.contains(flash) {
                settings.flashMode = flash
            }
            self.completion = completion
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    /// Prend une photo et attend le résultat.
    func capture(flash: AVCaptureDevice.FlashMode) async -> UIImage? {
        await withCheckedContinuation { continuation in
            capture(flash: flash) { image in
                continuation.resume(returning: image)
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        let image = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
        queue.async { [self] in
            completion?(image)
            completion = nil
        }
    }
}
