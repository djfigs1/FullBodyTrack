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

struct CodableCameraProperties: Codable {
    var cx: Double
    var cy: Double
    var fx: Double
    var fy: Double
    var distCoeffs: [Double]
}

func codableToCameraProperties(codable: CodableCameraProperties) -> CameraProperties {
    var properties = CameraProperties()
    properties.cx = codable.cx
    properties.cy = codable.cy
    properties.fx = codable.fx
    properties.fy = codable.fy
    properties.distCoeffs = (codable.distCoeffs[0], codable.distCoeffs[1], codable.distCoeffs[2], codable.distCoeffs[3], codable.distCoeffs[4])
    return properties
}

func cameraPropertiesToCodable(properties: CameraProperties) -> CodableCameraProperties {
    let tmp = properties.distCoeffs
    return CodableCameraProperties(
        cx: properties.cx,
        cy: properties.cy,
        fx: properties.fx,
        fy: properties.fy,
        distCoeffs: [tmp.0, tmp.1, tmp.2, tmp.3, tmp.4]
    )
}

protocol MarkerTrackerDelegate {
    func tracker(_ markerTracker: MarkerTracker, trackersWereUpdated trackers: [TrackerLocation])
}

class MarkerTracker: CameraSessionDelegate, ObservableObject {
    
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
        
        if let intrinsics = intrinsics {
            let fx = intrinsics[0][0]
            let fy = intrinsics[1][1]
            let cx = intrinsics[0][2]
            let cy = intrinsics[1][2]
            var properties = CameraProperties()
            properties.cx = Double(cx)
            properties.cy = Double(cy)
            properties.fx = Double(fx)
            properties.fy = Double(fy)
            //properties.distCoeffs = (0.28223140224073295,-1.2092660956873478,-0.0019283605685783557,0.0022946695257412527,1.5125784871553691)
            OpenCVWrapper.setCameraPropeties(properties)
        }
        
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
                
                DispatchQueue.main.async {
                    self.boardPoses = Int(OpenCVWrapper.boardsCaptured())
                    cameraSession.img = output.outputImage
                }
                
                break
            case .MARKERS:
                let output = OpenCVWrapper.getMarkersFrom(buffer)
                cameraSession.updateViewfinder(img: output.outputImage)
                break
            case .TRACKERS:
                let start = CFAbsoluteTimeGetCurrent()
                let output = OpenCVWrapper.getTrackersFrom(buffer);
                let diff = CFAbsoluteTimeGetCurrent() - start
                self.fps_tracker.append((start, diff))
                cameraSession.updateViewfinder(img: output.outputImage)
                
                DispatchQueue.main.async {
                    self.fps = self.calculateFPS()
                    //self.delegate?.tracker(self, trackersWereUpdated: output.trackers)
                    //cameraSession.img = output.outputImage
                }
                break
        }
    }
    
    func calculateFPS() -> Double {
        let now = CFAbsoluteTimeGetCurrent()
        let copy = fps_tracker
    
        var totaltime = 0.0
        var index = 0
        for frame in copy {
            if (frame.0 < (now - 1)) {
                fps_tracker.remove(at: index)
                continue
            }
            totaltime += frame.1
            index += 1
        }
        if (index != 0) {
            return 1.0/(totaltime / Double(index))
        }
        return 0
    }
    
    func calibrateStoredBoards() {
        let properties = OpenCVWrapper.calibrateStoredBoards();
        print (properties)
        saveCameraCalibration(properties)
    }
    
    func setCameraProperties(_ codable_props: CodableCameraProperties) {
        let props = codableToCameraProperties(codable: codable_props)
        OpenCVWrapper.setCameraPropeties(props)
    }
    
    func captureBoard() {
        captureBoardPose = true;
    }
}

struct Tracker: Codable {
    var name: String
    var markers: Dictionary<Int, [[Float]]>
}

func addTracker(_ tracker: Tracker) {
    let trackerobj = TrackerObj()
    trackerobj.serial = tracker.name
    for (marker, corners) in tracker.markers {
        trackerobj.markers[marker as NSNumber] = corners as [[NSNumber]]
    }
    
    OpenCVWrapper.addTracker(trackerobj)
    
}
