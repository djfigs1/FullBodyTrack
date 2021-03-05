//
//  CameraControls.swift
//  FullBodyTrack
//
//  Created by DJ Figueroa on 8/26/20.
//

import SwiftUI
import AVFoundation

struct CameraControls: View {
    
    @EnvironmentObject var trackerManager: TrackerManager
    @State private var winSize = 5
    @State private var refine = true
    @State private var flashlight = false
    
    var body: some View {
        
        let flashlightBinding = Binding(
            get: { self.flashlight },
            set: {
                self.flashlight = $0;
                guard let device = AVCaptureDevice.default(for: .video) else { return }
                if device.hasTorch {
                    do {
                        try device.lockForConfiguration()

                        if self.flashlight == true {
                            device.torchMode = .on
                        } else {
                            device.torchMode = .off
                        }

                        device.unlockForConfiguration()
                    } catch {
                        print("Torch could not be used")
                    }
                } else {
                    print("Torch is not available")
                }
            }
        )
        
        VStack {
            Picker(selection: $trackerManager.currentTrackingMode, label: Text("Mode")) {
                Text("Disabled").tag(TrackerManager.TrackingMode.DISABLED)
                Text("Calibrate").tag(TrackerManager.TrackingMode.CALIBRATE)
                Text("Markers").tag(TrackerManager.TrackingMode.MARKERS)
                Text("Trackers").tag(TrackerManager.TrackingMode.TRACKERS)
            }.pickerStyle(SegmentedPickerStyle())
            Picker(selection: $trackerManager.cameraSession.captureResolution, label: Text("Resolution")) {
                Text("720p").tag(CameraSession.CaptureResolution.hd720p)
                Text("1080p").tag(CameraSession.CaptureResolution.hd1080p)
                Text("4K").tag(CameraSession.CaptureResolution.hd4K)
            }.pickerStyle(SegmentedPickerStyle())
            //Text("FPS: \(trackerManager.fps)")
            //Button("Capture Board", action: {markerTracker.captureBoard()}).disabled(markerTracker.currentTrackingMode != .CALIBRATE)
            //Button("Calibrate Captured Boards", action:{markerTracker.calibrateStoredBoards()}).disabled(markerTracker.boardPoses < 10)
            Slider(value: $trackerManager.cameraSession.exposure, in: 60...1000) {
                Text("Exposure")
            }
            Toggle("Show Preview", isOn: $trackerManager.showPreview)
            Toggle("Flashlight", isOn: flashlightBinding)
        }
    }
    
}
