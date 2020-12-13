/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The implementation of a utility class that facilitates frame captures from the device
 camera.
*/

import AVFoundation
import CoreVideo
import UIKit
import VideoToolbox

protocol CameraSessionDelegate: AnyObject {
    func cameraSession(_ cameraSession: CameraSession, didCaptureBuffer buffer: CVImageBuffer, withIntrinsics: matrix_float3x3?)
}

enum VideoResolution {
    
}

/// - Tag: VideoCapture
class CameraSession: NSObject, ObservableObject {
    enum VideoCaptureError: Error {
        case captureSessionIsMissing
        case invalidInput
        case invalidOutput
        case unknown
    }
    
    @Published var capturing = false
    @Published var img: UIImage? = nil
    var viewfinder: CameraViewfinder?

    /// The delegate to receive the captured frames.
    weak var delegate: CameraSessionDelegate?

    /// A capture session used to coordinate the flow of data from input devices to capture outputs.
    let captureSession = AVCaptureSession()

    /// A capture output that records video and provides access to video frames. Captured frames are passed to the
    /// delegate via the `captureOutput()` method.
    let videoOutput = AVCaptureVideoDataOutput()
    
    var capturePreset:AVCaptureSession.Preset = .hd1920x1080

    /// The current camera's position.
    private(set) var cameraPostion = AVCaptureDevice.Position.back

    /// The dispatch queue responsible for processing camera set up and frame capture.
    private let sessionQueue = DispatchQueue(
        label: "com.figsware.camera-processing-thread")

    /// Asynchronously sets up the capture session.
    ///
    /// - parameters:
    ///     - completion: Handler called once the camera is set up (or fails).
    public func setUpAVCapture(completion: @escaping (Error?) -> Void) {
        sessionQueue.async {
            do {
                try self.setUpAVCapture()
                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }
    
    public func updateViewfinder(img: UIImage) {
        if let viewfinder = viewfinder {
            viewfinder.updateWithImg(img: img)
        }
    }

    private func setUpAVCapture() throws {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }

        captureSession.beginConfiguration()
        
        captureSession.sessionPreset = self.capturePreset
        
        try setCaptureSessionInput()
        try setCaptureSessionOutput()

        captureSession.commitConfiguration()
    }

    private func setCaptureSessionInput() throws {
        // Use the default capture device to obtain access to the physical device
        // and associated properties.
        
        guard let captureDevice = AVCaptureDevice.default(
                .builtInWideAngleCamera,
            for: AVMediaType.video,
            position: cameraPostion) else {
                throw VideoCaptureError.invalidInput
        }
        
        
        
        var bestFormat: AVCaptureDevice.Format?
        var bestFrameRateRange: AVFrameRateRange?
        for format in captureDevice.formats {
            for range in format.videoSupportedFrameRateRanges {
                if range.maxFrameRate > bestFrameRateRange?.maxFrameRate ?? 0 {
                    bestFormat = format
                    bestFrameRateRange = range
                }
            }
        }
        
        if let bestFormat = bestFormat, let bestFrameRateRange = bestFrameRateRange {
            do {
                try! captureDevice.lockForConfiguration()
                captureDevice.exposureMode = .custom
                captureDevice.setExposureModeCustom(duration: CMTimeMake(value: 1, timescale: 1000), iso: 500, completionHandler: nil)
                //captureDevice.activeFormat = bestFormat
                //captureDevice.activeVideoMinFrameDuration = bestFrameRateRange.minFrameDuration
                //captureDevice.activeVideoMaxFrameDuration = bestFrameRateRange.minFrameDuration
                captureDevice.unlockForConfiguration()
                
                print (captureDevice.activeVideoMinFrameDuration, captureDevice.activeVideoMaxFrameDuration)
            }
        }

        // Remove any existing inputs.
        captureSession.inputs.forEach { input in
            captureSession.removeInput(input)
        }

        // Create an instance of AVCaptureDeviceInput to capture the data from
        // the capture device.
        guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            throw VideoCaptureError.invalidInput
        }

        guard captureSession.canAddInput(videoInput) else {
            throw VideoCaptureError.invalidInput
        }

        captureSession.addInput(videoInput)
    }

    private func setCaptureSessionOutput() throws {
        // Remove any previous outputs.
        captureSession.outputs.forEach { output in
            captureSession.removeOutput(output)
        }

        // Set the pixel type.
        let settings: [String: Any] = [
            String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA
        ]

        videoOutput.videoSettings = settings

        // Discard newer frames that arrive while the dispatch queue is already busy with
        // an older frame.
        videoOutput.alwaysDiscardsLateVideoFrames = true

        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)

        guard captureSession.canAddOutput(videoOutput) else {
            throw VideoCaptureError.invalidOutput
        }

        captureSession.addOutput(videoOutput)

        // Update the video orientation
        if let connection = videoOutput.connection(with: .video),
            connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
            connection.isCameraIntrinsicMatrixDeliveryEnabled = false
        }
    }

    /// Begin capturing frames.
    ///
    /// - Note: This is performed off the main thread as starting a capture session can be time-consuming.
    ///
    /// - parameters:
    ///     - completionHandler: Handler called once the session has started running.
    public func startCapturing(completion completionHandler: (() -> Void)? = nil) {
        
        sessionQueue.async {
            if !self.captureSession.isRunning {
                // Invoke the startRunning method of the captureSession to start the
                // flow of data from the inputs to the outputs.
                self.captureSession.startRunning()
            }

            DispatchQueue.main.async {
                self.capturing = true
            }
            
            if let completionHandler = completionHandler {
                DispatchQueue.main.async {
                    completionHandler()
                }
            }
        }
    }

    /// End capturing frames
    ///
    /// - Note: This is performed off the main thread, as stopping a capture session can be time-consuming.
    ///
    /// - parameters:
    ///     - completionHandler: Handler called once the session has stopping running.
    public func stopCapturing(completion completionHandler: (() -> Void)? = nil) {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            
            DispatchQueue.main.async {
                self.capturing = false
            }

            if let completionHandler = completionHandler {
                DispatchQueue.main.async {
                    completionHandler()
                }
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {

    public func captureOutput(_ output: AVCaptureOutput,
                              didOutput sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        guard let delegate = delegate else { return }
        
        var matrix: matrix_float3x3?
        if let camData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) as? Data {

            matrix = camData.withUnsafeBytes() {
                $0.pointee
            }
        }

        if let pixelBuffer = sampleBuffer.imageBuffer {
            sessionQueue.async {
                delegate.cameraSession(self, didCaptureBuffer: pixelBuffer, withIntrinsics: matrix)
            }
        }
        
        
    }
}
