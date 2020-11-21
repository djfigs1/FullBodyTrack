//
//  CameraControls.swift
//  FullBodyTrack
//
//  Created by DJ Figueroa on 8/26/20.
//

import SwiftUI

struct CameraControls: View {
    
    @EnvironmentObject var markerTracker: MarkerTracker
    @State private var winSize = 5
    @State private var refine = true
    
    var body: some View {
        let refineBinding = Binding(
            get: { self.refine },
            set: { self.refine = $0; OpenCVWrapper.setCameraRefine($0)}
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
            Text("FPS: \(markerTracker.fps)")
        }
    }
    
}
