//
//  CameraView.swift
//  FullBodyTrack
//
//  Created by DJ Figueroa on 12/13/20.
//

import Foundation
import SwiftUI

struct Viewfinder: UIViewRepresentable {
    
    @EnvironmentObject var trackerManager: TrackerManager
    
    func makeUIView(context: Context) -> some UIView {
        let viewfinder = CameraViewfinder()
        trackerManager.cameraSession.viewfinder = viewfinder
        return viewfinder
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        
    }
}

struct CameraView: View {
    @EnvironmentObject var trackerManager: TrackerManager
    
    var body: some View {
        VStack {
            CameraControls()
            Viewfinder()
        }
    }
}
