//
//  ArucoTracker.swift
//  FullBodyTrack
//
//  Created by DJ Figueroa on 8/26/20.
//

import Foundation

struct Tracker: Codable {
    var name: String
    var markers: Dictionary<Int, [[Float]]>
}

func addTracker(_ tracker: Tracker) {
    let trackerobj = TrackerObj()
    trackerobj.serial = tracker.name
    for (marker, corners) in tracker.markers {
        trackerobj.markers[marker as NSNumber] = corners as [[NSNumber]]
    }
    
    OpenCVWrapper.addTracker(trackerobj)
    
}



//@objc class TrackerC: NSObject {
//    class var name: NSString
//    class var markers: NSArray<NSArray<NSNumber>>
//}
