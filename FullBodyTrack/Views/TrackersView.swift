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
            TrackerRow(unique: tracker).onTapGesture {
                addTracker(tracker.tracker)
                print ("Added tracker \(tracker.id)")
            }
        }
    }
}

struct TrackerRow: View {
    
    var unique: UniqueTracker
    
    var body: some View {
        VStack (alignment: .leading, spacing: 0) {
            Text(unique.tracker.name).bold()
            Text(unique.active ? "Tracked" : "Not Tracked")
            Text("\(unique.tracker.markers.count) markers")
        }
    }
}

struct TrackersView_Previews: PreviewProvider {
    let empty_dict = Dictionary<Int, [[Float]]>()
    static var previews: some View {
        TrackersView(trackers: [
            //UniqueTracker(id: "a", tracker: Tracker(name: "a", markers: empty_dict), active: false)
        ])
    }
}
