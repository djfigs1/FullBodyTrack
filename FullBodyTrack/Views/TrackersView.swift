//
//  TrackersView.swift
//  FullBodyTrack
//
//  Created by DJ Figueroa on 12/13/20.
//

import SwiftUI

struct TrackersView: View {
    
    @EnvironmentObject var trackerManager: TrackerManager
    
    var body: some View {
        List(trackerManager.trackers) { tracker in
            TrackerRow(tracker: tracker)
        }
    }
}

struct TrackerRow: View {
    
    @ObservedObject var tracker: TrackerManager.Tracker
    
    var body: some View {
        Image(systemName: "perspective")
        VStack (alignment: .leading, spacing: 0) {
            Text(tracker.data.name).bold()
            Text("\(tracker.data.markers.count) markers")
        }
        Toggle("", isOn: $tracker.active).disabled(!tracker.canBeAdded && !tracker.active)
    }
}

struct TrackersView_Previews: PreviewProvider {
    let empty_dict = Dictionary<Int, [[Float]]>()
    static var previews: some View {
        TrackersView()
    }
}
