//
//  TrackerManager.swift
//  FullBodyTrack
//
//  Created by DJ Figueroa on 12/25/20.
//

import Foundation
import SwiftUI

struct CameraProperties: Codable {
    public var cx: Double
    public var cy: Double
    public var fx: Double
    public var fy: Double
    public var distCoeffs: [Double]
}

func codableCamPropsToObjC(codable: CameraProperties) -> CameraPropertiesObjC {
    let objc_props = CameraPropertiesObjC()
    objc_props.fx = NSNumber(value: codable.fx)
    objc_props.fy = NSNumber(value: codable.fy)
    objc_props.cx = NSNumber(value: codable.cx)
    objc_props.cy = NSNumber(value: codable.cy)
    for val in codable.distCoeffs {
        objc_props.distCoeffs.append(NSNumber(value: val))
    }
    return objc_props
}

class TrackerManager: NSObject, ObservableObject, CameraSessionDelegate {
    
    struct TrackerData: Hashable, Codable {
        var name: String
        var markers: Dictionary<Int, [[Float]]>
    }

    class Tracker: Identifiable, ObservableObject {
        var manager: TrackerManager
        var id: String
        var data: TrackerData
        @Published var canBeAdded: Bool = true
        @Published var active: Bool = false {
            didSet {
                for tracker in self.manager.trackers {
                    tracker.canBeAdded = tracker.checkIfAddable()
                }
                
                if (active) {
                    OpenCVWrapper.addTracker(trackerobj)
                } else {
                    OpenCVWrapper.removeTracker(trackerobj)
                }
                
            }
        }
        var trackerobj: TrackerObj
        
        init (manager: TrackerManager, id: String, data: TrackerData) {
            self.manager = manager
            self.id = id
            self.data = data
            self.trackerobj = TrackerObj()
            trackerobj.tracker_id = id
            for (marker, corners) in data.markers {
                trackerobj.markers[marker as NSNumber] = corners as [[NSNumber]]
            }
        }
        
        func checkIfAddable() -> Bool {
            let marker_ids = Set(data.markers.keys)
            for tracker in self.manager.trackers {
                if (!tracker.active) {
                    continue
                }
                
                let other_marker_ids = Set(tracker.data.markers.keys)
                let intersection = marker_ids.intersection(other_marker_ids)
                if (intersection.count > 0) {
                    return false;
                }
            }
            return true;
        }
    }
    
    public enum TrackingMode {
        case DISABLED
        case CALIBRATE
        case MARKERS
        case TRACKERS
    }
    
    static var shared: TrackerManager = TrackerManager()
    @Published var vrConnectionManager = SteamVRConnectionManager()
    @Published var cameraSession = CameraSession()
    @Published var currentTrackingMode: TrackingMode = .TRACKERS
    @Published var showPreview: Bool = true {
        didSet {
            OpenCVWrapper.setShowPreviewWindow(showPreview)
        }
    }
    @Published var trackers: [Tracker] = []
    @Published var fps: Double = 0
    
    override init() {
        super.init()
        addTrackersFromFiles()
        cameraSession.delegate = self
    }
    
    func advertiseTrackers() {
        if (self.vrConnectionManager.connected) {
            var active_trackers: [Tracker] = []
            for tracker in trackers {
                if (tracker.active) {
                    active_trackers.append(tracker)
                }
            }
            self.vrConnectionManager.advertiseTrackers(trackers: active_trackers)
        }
    }
    
    static func setCameraProperties(properties: CameraProperties) {
        let objc_properties = CameraPropertiesObjC()
        objc_properties.cx = NSNumber(value: properties.cx)
        objc_properties.cy = NSNumber(value: properties.cy)
        objc_properties.fx = NSNumber(value: properties.fx)
        objc_properties.fy = NSNumber(value: properties.fy)
        var coeffs: [NSNumber] = []
        properties.distCoeffs.forEach { val in
            coeffs.append(NSNumber(value: val))
        }
        objc_properties.distCoeffs = coeffs
        OpenCVWrapper.setCameraPropeties(objc_properties)
    }
    
    func addTrackersFromFiles() {
        if let allTrackerData = getStoredTrackers() {
            for trackerData in allTrackerData {
                let tracker = Tracker(manager: self, id: trackerData.0, data: trackerData.1)
                self.trackers.append(tracker)
            }
        }
        
    }

    func didCaptureBuffer(buffer: CVImageBuffer) {
        switch (self.currentTrackingMode) {
            case .DISABLED:
                return
            case .CALIBRATE:
                /*
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
                */
                break
            case .MARKERS:
                let output = OpenCVWrapper.getMarkersFrom(buffer)
                cameraSession.updateViewfinder(img: output.outputImage)
                break
            case .TRACKERS:
                let output = OpenCVWrapper.getTrackersFrom(buffer);
                cameraSession.updateViewfinder(img: output.outputImage)
                self.didFindTrackers(trackers: output.trackers)
                break
        }
    }
    
    func didFindTrackers(trackers: [TrackerLocation]) {
        self.vrConnectionManager.updateTrackers(trackerLocations: trackers)
    }
}
