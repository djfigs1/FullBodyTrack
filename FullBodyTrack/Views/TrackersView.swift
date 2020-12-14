//
//  TrackersView.swift
//  FullBodyTrack
//
//  Created by DJ Figueroa on 12/13/20.
//

import SwiftUI

struct TrackersView: View {
    
    var trackers: [UniqueTracker] = getTrackers() ?? []
    
    var body: some View {
        List(trackers) { tracker in
            TrackerRow(tracker: tracker.tracker)
        }
    }
}

struct TrackerRow: View {
    
    var tracker: Tracker
    
    var body: some View {
        VStack {
            Text(tracker.name).bold()
            Text("\(tracker.markers.count) markers")
        }
    }
}

struct TrackersView_Previews: PreviewProvider {
    static var previews: some View {
        TrackersView(trackers: [])
    }
}
