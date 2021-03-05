//
//  MarkerTracker.swift
//  FullBodyTrack
//
//  Created by DJ Figueroa on 8/5/20.
//

import Foundation


func quatToRvec(w: Double, x: Double, y: Double, z: Double) -> Vector3d {
    let length = sqrt(pow(x, 2) + pow(y, 2) + pow(z, 2))
    let theta = 2*acos(w)
    let ux = x / (length*theta)
    let uy = y / (length*theta)
    let uz = z / (length*theta)
    
    
    return Vector3d(x: ux, y: uy, z: uz)
    
}

protocol MarkerTrackerDelegate {
    func tracker(_ markerTracker: MarkerTracker, trackersWereUpdated trackers: [TrackerLocation])
}

class MarkerTracker: CameraSessionDelegate, ObservableObject {
    func didCaptureBuffer(buffer: CVImageBuffer) {
        
    }
    
    
    public enum TrackingMode {
        case DISABLED
        case CALIBRATE
        case MARKERS
        case TRACKERS
    }
    
    @Published var currentTrackingMode: TrackingMode = TrackingMode.TRACKERS
    @Published var boardPoses = 0;
    @Published var fps = 0.0;
    private var captureBoardPose = false;
    public var delegate: MarkerTrackerDelegate?
    private var fps_tracker:[(CFAbsoluteTime, CFAbsoluteTime)] = []
    
    func cameraSession(_ cameraSession: CameraSession, didCaptureBuffer buffer: CVImageBuffer, withIntrinsics intrinsics: matrix_float3x3?) {
        
        switch (self.currentTrackingMode) {
            case .DISABLED:
                return
            case .CALIBRATE:
                var output: ChArUcoBoardResult
                if (captureBoardPose) {
                    output = OpenCVWrapper.findChArUcoBoard(buffer, saveResult: true)
                    captureBoardPose = !output.boardFound; // only stop looking for a board if its found
                    print ("boards: \(OpenCVWrapper.boardsCaptured())")
                } else {
                    output = OpenCVWrapper.findChArUcoBoard(buffer, saveResult: false)
                }
                cameraSession.updateViewfinder(img: output.outputImage)
                
                DispatchQueue.main.async {
                    self.boardPoses = Int(OpenCVWrapper.boardsCaptured())
                }
                
                break
            case .MARKERS:
                let output = OpenCVWrapper.getMarkersFrom(buffer)
                cameraSession.updateViewfinder(img: output.outputImage)
                break
            case .TRACKERS:
                let output = OpenCVWrapper.getTrackersFrom(buffer);
                cameraSession.updateViewfinder(img: output.outputImage)
                break
        }
        
    }
    
    func calibrateStoredBoards() {
        //let properties = OpenCVWrapper.calibrateStoredBoards();
        //saveCameraCalibration(properties)
    }
    
    func setCameraProperties(properties: CameraProperties) {
        //OpenCVWrapper.setCameraPropeties(properties)
    }
    
    func captureBoard() {
        captureBoardPose = true
    }
}




