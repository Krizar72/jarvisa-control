import AppKit
import ScreenCaptureKit
import CoreImage
import CoreMedia

final class CaptureEngine: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private let queue = DispatchQueue(label: "it.krizar.jarvisa.frames", qos: .userInitiated)
    private let context = CIContext(options: [.cacheIntermediates: false])
    var onFrame: ((CGImage) -> Void)?
    var onError: ((Error) -> Void)?

    @MainActor
    func start(display: SCDisplay, content: SCShareableContent) async throws {
        let excluded = content.applications.filter {
            $0.processID == ProcessInfo.processInfo.processIdentifier || $0.bundleIdentifier == Bundle.main.bundleIdentifier
        }
        let filter = SCContentFilter(display: display, excludingApplications: excluded, exceptingWindows: [])
        let config = SCStreamConfiguration()
        let bounds = CGDisplayBounds(display.displayID)
        let scale = min(2, 1440 / max(bounds.width, 1))
        config.width = max(2, Int(bounds.width * scale))
        config.height = max(2, Int(bounds.height * scale))
        config.minimumFrameInterval = CMTime(value: 1, timescale: 10)
        config.queueDepth = 3
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        config.capturesAudio = false
        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        stream = newStream
        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        do { try await newStream.startCapture() }
        catch { stream = nil; throw error }
    }

    @MainActor
    func stop() async throws {
        guard let old = stream else { return }
        stream = nil
        try await old.stopCapture()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, buffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int,
              status == SCFrameStatus.complete.rawValue,
              let pixelBuffer = buffer.imageBuffer else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let image = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        DispatchQueue.main.async { [weak self, weak stream] in
            guard let self, let stream, self.stream === stream else { return }
            self.onFrame?(image)
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self, weak stream] in
            guard let self, let stream, self.stream === stream else { return }
            self.stream = nil
            self.onError?(error)
        }
    }
}
