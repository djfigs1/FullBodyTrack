//
//  CameraView.swift
//  FullBodyTrack
//
//  Created by DJ Figueroa on 12/13/20.
//

import Foundation
import SwiftUI

struct Viewfinder: UIViewRepresentable {
    
    @EnvironmentObject var camSession: CameraSession
    
    func makeUIView(context: Context) -> some UIView {
        let viewfinder = CameraViewfinder()
        camSession.viewfinder = viewfinder
        return viewfinder
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        
    }
}

struct CameraView: View {
    @EnvironmentObject var camSession: CameraSession
    
    var body: some View {
        VStack {
            CameraControls().environmentObject(camSession.delegate as! MarkerTracker)
//            let cameraImage = Image(uiImage: camSession.img ?? UIImage())
//                .resizable()
//                .aspectRatio(contentMode: .fit)
            Viewfinder()
            
        }
    }
}
