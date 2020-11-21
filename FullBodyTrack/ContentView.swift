//
//  ContentView.swift
//  FullBodyTrack
//
//  Created by DJ Figueroa on 8/5/20.
//

import SwiftUI
import ARKit

struct ContentView: View {
    
    @EnvironmentObject var camSession: CameraSession
    
    var body: some View {
        CameraControls().environmentObject(camSession.delegate as! MarkerTracker)
        Image(uiImage: camSession.img ?? UIImage())
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
