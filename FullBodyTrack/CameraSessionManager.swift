/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The implementation of a utility class that facilitates frame captures from the device
 camera.
*/

import AVFoundation
import CoreGraphics
import CoreVideo
import UIKit
import VideoToolbox

protocol CameraSessionDelegate: AnyObject {
    func didCaptureBuffer(buffer: CVImageBuffer)
}

/// - Tag: VideoCapture
class CameraSession: NSObject, ObservableObject {
    
    enum CaptureResolution: Int32 {
        case hd720p = 1280
        case hd1080p = 1920
        case hd4K = 3840
    }
    
    let captureSession = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    var cameraPosition = AVCaptureDevice.Position.back
    
    var viewfinder: CameraViewfinder?
    var delegate: CameraSessionDelegate?
    
    @Published var captureResolution: CaptureResolution = .hd1080p {
        didSet {
            do {
                try self.setUpAVCapture()
                self.startCapturing(completion: nil)
            } catch {
                print ("Couldn't change resolution")
            }
            
        }
    }
    
    @Published var exposure: Double = 500 {
        didSet {
            self.setExposure(exposure: exposure)
        }
    }
    
    //private let captureSessionQueue = DispatchQueue(label: "com.figsware.camera-processing-thread")
    private let captureSessionQueue = DispatchQueue(label: "com.figsware.camera-processing-thread", qos: .userInitiated, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
    
    func updateViewfinder(img: UIImage) {
        guard let viewfinder=self.viewfinder else { return }
        DispatchQueue.main.async {
            viewfinder.imageView.image = img
        }
    }
    
    func updateViewfinder(img: CGImage) {
        guard let viewfinder=self.viewfinder else { return }
        let new_img = UIImage(cgImage: img)
        DispatchQueue.main.async {
            viewfinder.imageView.image = new_img
        }
        
    }
    
    public func setUpAVCapture(completion: @escaping (Error?) -> Void) {
        DispatchQueue.main.async {
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
    
    private func setUpAVCapture() throws {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        
        captureSession.beginConfiguration()
        
        try setCaptureSessionInput(resolution: captureResolution)
        try setCaptureSessionOutput()

        captureSession.commitConfiguration()
    }
    
    
    public func setExposure(exposure: Double) {
        guard let captureDevice = AVCaptureDevice.default(
                .builtInWideAngleCamera,
            for: AVMediaType.video,
            position: cameraPosition) else {
                return
        }
        
        do {
            try captureDevice.lockForConfiguration()
            captureDevice.exposureMode = .custom
            captureDevice.setExposureModeCustom(duration: CMTimeMake(value: 1, timescale: Int32(exposure)), iso: 50, completionHandler: nil)
            captureDevice.unlockForConfiguration()
        } catch {
                
        }
    }
    
    /**
     Configures the capture for capturing video
     */
    private func setCaptureSessionInput(resolution: CaptureResolution) throws {
        // Use the default capture device to obtain access to the physical device
        // and associated properties.
        
        guard let captureDevice = AVCaptureDevice.default(
                .builtInWideAngleCamera,
            for: AVMediaType.video,
            position: cameraPosition) else {
                return
        }
        
        let targetWidth = captureResolution.rawValue
        
        captureSession.sessionPreset = .inputPriority
        
        var bestFormat: AVCaptureDevice.Format?
        var bestFrameRateRange: AVFrameRateRange?
        for format in captureDevice.formats {
            for range in format.videoSupportedFrameRateRanges {
                if format.formatDescription.dimensions.width == targetWidth {
                    if range.maxFrameRate > bestFrameRateRange?.maxFrameRate ?? 0 {
                        bestFormat = format
                        bestFrameRateRange = range
                    }
                }
            }
        }
        
        if let bestFormat = bestFormat, let bestFrameRateRange = bestFrameRateRange {
            do {
                try captureDevice.lockForConfiguration()
                print ("Activating format: \(bestFormat)")
                captureDevice.activeFormat = bestFormat
                captureDevice.exposureMode = .custom
                captureDevice.setExposureModeCustom(duration: CMTimeMake(value: 1, timescale: Int32(exposure)), iso: 500, completionHandler: nil)
                captureDevice.activeVideoMinFrameDuration = bestFrameRateRange.minFrameDuration
                captureDevice.activeVideoMaxFrameDuration = bestFrameRateRange.maxFrameDuration
                captureDevice.unlockForConfiguration()
            } catch {
                print ("Error setting capture format: \(error.localizedDescription)")
            }
        }

        // Remove any existing inputs.
        captureSession.inputs.forEach { input in
            captureSession.removeInput(input)
        }

        // Create an instance of AVCaptureDeviceInput to capture the data from
        // the capture device.
        guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            print ("Can't create capture device")
            return
        }

        guard captureSession.canAddInput(videoInput) else {
            print ("Can't add input")
            return
        }

        captureSession.addInput(videoInput)
        
        print (captureSession.inputs)
        print ("actual", (captureSession.inputs.first! as! AVCaptureDeviceInput).device.activeFormat)
    }
    
    /**
     Configures the video output buffer to be processed by OpenCV
     */

    private func setCaptureSessionOutput() throws {
        // Remove any previous outputs.
        captureSession.outputs.forEach { output in
            captureSession.removeOutput(output)
        }

        // Set the pixel type for OpenCV
        let settings: [String: Any] = [
            String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA
        ]
        
        videoOutput.videoSettings = settings
        
        // Discard newer frames that arrive while the dispatch queue is already busy with
        // an older frame.
        videoOutput.alwaysDiscardsLateVideoFrames = true

        videoOutput.setSampleBufferDelegate(self, queue: captureSessionQueue)

        guard captureSession.canAddOutput(videoOutput) else {
            return
        }

        captureSession.addOutput(videoOutput)

        // Update the video orientation
        if let connection = videoOutput.connection(with: .video),
            connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }

    /// Begin capturing frames.
    ///
    /// - Note: This is performed off the main thread as starting a capture session can be time-consuming.
    ///
    /// - parameters:
    ///     - completionHandler: Handler called once the session has started running.
    public func startCapturing(completion completionHandler: (() -> Void)? = nil) {
        
        captureSessionQueue.async {
            if !self.captureSession.isRunning {
                // Invoke the startRunning method of the captureSession to start the
                // flow of data from the inputs to the outputs.
                self.captureSession.startRunning()
            }
            
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = true
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
        
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        
        captureSessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
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

        if let pixelBuffer = sampleBuffer.imageBuffer {
            delegate.didCaptureBuffer(buffer: pixelBuffer)
        }
    }
}
