//
//  CameraControls.swift
//  FullBodyTrack
//
//  Created by DJ Figueroa on 8/26/20.
//

import SwiftUI
import AVFoundation

struct CameraControls: View {
    
    @EnvironmentObject var markerTracker: MarkerTracker
    @State private var winSize = 5
    @State private var refine = true
    @State private var flashlight = false
    
    var body: some View {
        let refineBinding = Binding(
            get: { self.refine },
            set: { self.refine = $0; OpenCVWrapper.setCameraRefine($0)}
        )
        
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
            Picker(selection: $markerTracker.currentTrackingMode, label: Text("Mode")) {
                Text("Disabled").tag(MarkerTracker.TrackingMode.DISABLED)
                Text("Calibrate").tag(MarkerTracker.TrackingMode.CALIBRATE)
                Text("Markers").tag(MarkerTracker.TrackingMode.MARKERS)
                Text("Trackers").tag(MarkerTracker.TrackingMode.TRACKERS)
            }.pickerStyle(SegmentedPickerStyle())
            Button("Capture Board", action: {markerTracker.captureBoard()}).disabled(markerTracker.currentTrackingMode != .CALIBRATE)
            Button("Calibrate Captured Boards", action:{markerTracker.calibrateStoredBoards()}).disabled(markerTracker.boardPoses < 10)
            Toggle("Corner Refine", isOn: refineBinding)
            Toggle("Flashlight", isOn: flashlightBinding)
        }
    }
    
}
