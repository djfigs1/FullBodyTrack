//
//  SteamVRView.swift
//  FullBodyTrack
//
//  Created by DJ Figueroa on 12/26/20.
//

import SwiftUI

struct SteamVRView: View {
    
    @EnvironmentObject var trackerManager: TrackerManager
    @EnvironmentObject var vrConnectionManager: SteamVRConnectionManager
    
    var body: some View {
        VStack {
            Text(vrConnectionManager.connected ? "Connected" : "Disconnected")
            Button("Connect") {
                vrConnectionManager.connect(host: "192.168.1.22", port: 8082)
            }
            
            Button("Advertise Trackers") {
                trackerManager.advertiseTrackers()
            }.disabled(!vrConnectionManager.connected)
        }
    }
}

struct SteamVRView_Previews: PreviewProvider {
    static var previews: some View {
        SteamVRView()
    }
}
