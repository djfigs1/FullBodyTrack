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
    @State var shouldAppear: Bool = true
    
    var body: some View {
        TabView {
            CameraView()
                .tabItem {
                    Image(systemName: "camera.viewfinder")
                    Text("Camera")
                }
                .onAppear() {
                    if !self.shouldAppear {
                        self.shouldAppear = true
                        return
                    }
                    camSession.setUpAVCapture() { (error) in
                        guard let error = error else {
                            print ("AVCapture initialized!")
                            camSession.startCapturing()
                            UIApplication.shared.isIdleTimerDisabled = true
                            return
                        }
                        print ("Error initalizing AVCapture: \(error.localizedDescription)")
                    }
                }
            
            TrackersView()
                .tabItem {
                    Image(systemName: "perspective")
                    Text("Trackers")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
