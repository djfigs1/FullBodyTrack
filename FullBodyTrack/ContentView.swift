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
        TabView {
            CameraView()
                .tabItem {
                    Image(systemName: "camera.viewfinder")
                    Text("Camera")
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
