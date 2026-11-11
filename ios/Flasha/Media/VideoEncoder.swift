@preconcurrency import AVFoundation
import Foundation

/// Convertit une vidéo au format FLASHA Vidéo : recadrée au centre pour remplir
/// 1080 × 1920, 30 images par seconde, HEVC à 2,5 Mbit/s, son AAC stéréo à 96 kbit/s,
/// 60 secondes au plus, en couleurs SDR (Rec. 709), prête pour le streaming.
nonisolated enum VideoEncoder {
    @concurrent static func encode(_ source: URL, to destination: URL) async throws -> EncodedVideo {
        let asset = AVURLAsset(url: source)
        let duration = try await asset.load(.duration)
        guard let video = try await asset.loadTracks(withMediaType: .video).first else {
            throw FlashaMediaError.unreadable
        }
        let audio = try await asset.loadTracks(withMediaType: .audio).first
        let (naturalSize, preferredTransform) = try await video.load(.naturalSize, .preferredTransform)

        let format = FlashaFormat.Video.self
        let target = format.size
        let limit = CMTime(seconds: format.maxDuration, preferredTimescale: 600)
        let range = CMTimeRange(start: .zero, duration: CMTimeMinimum(duration, limit))

        // L'image : orientée, mise à l'échelle et recadrée au centre, à 30 i/s.
        let composition = AVMutableVideoComposition()
        composition.renderSize = target
        composition.frameDuration = CMTime(value: 1, timescale: format.frameRate)
        composition.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
        composition.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
        composition.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = range
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: video)
        layer.setTransform(
            fillTransform(natural: naturalSize, preferred: preferredTransform, target: target),
            at: .zero
        )
        instruction.layerInstructions = [layer]
        composition.instructions = [instruction]

        try? FileManager.default.removeItem(at: destination)
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = range
        let writer = try AVAssetWriter(outputURL: destination, fileType: .mp4)
        // L'index au début du fichier : la lecture commence avant la fin du téléchargement.
        writer.shouldOptimizeForNetworkUse = true

        let videoOutput = AVAssetReaderVideoCompositionOutput(
            videoTracks: [video],
            videoSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            ]
        )
        videoOutput.videoComposition = composition
        videoOutput.alwaysCopiesSampleData = false
        reader.add(videoOutput)

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: Int(target.width),
            AVVideoHeightKey: Int(target.height),
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: format.bitRate,
                AVVideoExpectedSourceFrameRateKey: Int(format.frameRate),
                AVVideoMaxKeyFrameIntervalKey: format.keyFrameInterval,
            ] as [String: Any],
        ])
        videoInput.expectsMediaDataInRealTime = false
        writer.add(videoInput)
        var pumps = [Pump(output: videoOutput, input: videoInput, label: "video")]

        if let audio {
            // Le son : décodé en PCM stéréo 44,1 kHz, réencodé en AAC.
            let audioOutput = AVAssetReaderTrackOutput(track: audio, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: format.audioSampleRate,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ])
            audioOutput.alwaysCopiesSampleData = false
            reader.add(audioOutput)
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: format.audioSampleRate,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: format.audioBitRate,
            ])
            audioInput.expectsMediaDataInRealTime = false
            writer.add(audioInput)
            pumps.append(Pump(output: audioOutput, input: audioInput, label: "audio"))
        }

        guard reader.startReading() else { throw reader.error ?? FlashaMediaError.unreadable }
        guard writer.startWriting() else { throw writer.error ?? FlashaMediaError.encoder }
        writer.startSession(atSourceTime: range.start)

        await withTaskGroup(of: Void.self) { group in
            for pump in pumps {
                group.addTask { await pump.run() }
            }
        }

        if reader.status == .failed {
            writer.cancelWriting()
            throw reader.error ?? FlashaMediaError.unreadable
        }
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? FlashaMediaError.encoder }

        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        let bytes = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        return EncodedVideo(url: destination, bytes: bytes, duration: range.duration.seconds, size: target)
    }

    /// Oriente la vidéo (portrait ou paysage), puis la met à l'échelle et la centre pour
    /// remplir `target`.
    static func fillTransform(natural: CGSize, preferred: CGAffineTransform, target: CGSize) -> CGAffineTransform {
        let rect = CGRect(origin: .zero, size: natural).applying(preferred)
        let scale = max(target.width / rect.width, target.height / rect.height)
        return preferred
            .concatenating(CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(
                translationX: (target.width - rect.width * scale) / 2,
                y: (target.height - rect.height * scale) / 2
            ))
    }
}

/// Fait passer les échantillons d'une piste du lecteur à l'écrivain, à son rythme.
private nonisolated final class Pump: @unchecked Sendable {
    private let output: AVAssetReaderOutput
    private let input: AVAssetWriterInput
    private let queue: DispatchQueue
    private var finished = false

    init(output: AVAssetReaderOutput, input: AVAssetWriterInput, label: String) {
        self.output = output
        self.input = input
        self.queue = DispatchQueue(label: "app.flasha.encoder.\(label)")
    }

    func run() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            input.requestMediaDataWhenReady(on: queue) { [self] in
                guard !finished else { return }
                while input.isReadyForMoreMediaData {
                    guard let sample = output.copyNextSampleBuffer(), input.append(sample) else {
                        input.markAsFinished()
                        finished = true
                        continuation.resume()
                        return
                    }
                }
            }
        }
    }
}
