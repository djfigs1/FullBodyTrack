//
//  SteamVRConnectionManager.swift
//  FullBodyTrack
//
//  Created by DJ Figueroa on 9/1/20.
//

import Foundation
import Network

class SteamVRConnectionManager: MarkerTrackerDelegate {
    
    var connection:NWConnection?
    static let shared = SteamVRConnectionManager()
    var locationCache:Dictionary<Int8, TrackerLocation> = Dictionary<Int8, TrackerLocation>()
   
    enum OPENVR_PACKET_TYPE: UInt8 {
        case HANDSHAKE = 0x00
        case ADVERTISE = 0x01
        case CALIBRATE = 0x02
        case UPDATE = 0x03
    }
    
    func connect(host: NWEndpoint.Host, port: NWEndpoint.Port) {
        if (connection != nil) {
            connection!.cancel()
        }
        
        connection = NWConnection(host: host, port: port, using: .udp)
        connection?.start(queue: .global())
        handshake()
    }
    
    func handshake()
    {
        guard let connection=connection else {return}
        var handshake_data = Data()
        handshake_data.append(OPENVR_PACKET_TYPE.HANDSHAKE.rawValue)
        connection.send(content: handshake_data, completion: NWConnection.SendCompletion.contentProcessed(({ (err) in
            print ("Handshake")
            guard let err=err else {return}
            print ("Error when handshaking: \(err.localizedDescription)")
        })))
    }
    
    func advertiseTrackers()
    {
        guard let connection=connection else {return}
        let trackers = OpenCVWrapper.getAllTrackers()
        var tracker_advertise_data = Data()
        tracker_advertise_data.append(OPENVR_PACKET_TYPE.ADVERTISE.rawValue)
        for tracker in trackers {
            tracker_advertise_data.append(UInt8(bitPattern: tracker.tracker_id))
            tracker_advertise_data.append(tracker.serial.data(using: .ascii)!)
            tracker_advertise_data.append(0x00)
        }
        
        connection.send(content: tracker_advertise_data, completion: NWConnection.SendCompletion.contentProcessed(({ (err) in
            print ("Did advertise")
            guard let err=err else {return}
            print ("Error when advertising trackers: \(err.localizedDescription)")
        })))
        
    }

    func tracker(_ markerTracker: MarkerTracker, trackersWereUpdated trackers: [TrackerLocation]) {
        guard let connection=connection else {return}
        var tracker_update_data = Data()
        tracker_update_data.append(OPENVR_PACKET_TYPE.UPDATE.rawValue)
        for tracker in trackers {
            var tracker_char = tracker.tracker_id
            locationCache[tracker_char] = tracker
            
            // Negative tracker ids indicate that the tracker is not visible
            tracker_char = tracker.visible ? tracker_char : -tracker_char
            tracker_update_data.append(contentsOf: [UInt8(bitPattern: tracker_char)])
            
            var rvec = tracker.rvec
            var tvec = tracker.tvec
            
            // Only append rvec/tvec if it's visible
            if (tracker.visible) {
                tracker_update_data.append(Data(bytes: &rvec, count: 24))
                tracker_update_data.append(Data(bytes: &tvec, count: 24))
            }
        }
        
        connection.send(content: tracker_update_data, completion: NWConnection.SendCompletion.contentProcessed(({ (err) in
            guard let err=err else {return}
            print ("Error when sending tracker data: \(err.localizedDescription)")
        })))
    }
    
    func calibrateTracker(location: TrackerLocation, o_rvec: Vector3d, o_tvec: Vector3d) {
        guard let connection=connection else {return}
        if (!location.visible) {
            return;
        }
        var to_rvec = o_rvec
        var to_tvec = o_tvec
        
        var tracker_calibrate_data = Data()
        tracker_calibrate_data.append(OPENVR_PACKET_TYPE.CALIBRATE.rawValue)
        tracker_calibrate_data.append(Data(bytes: &location.rvec, count: 24))
        tracker_calibrate_data.append(Data(bytes: &location.tvec, count: 24))
        tracker_calibrate_data.append(Data(bytes: &to_rvec, count: 24))
        tracker_calibrate_data.append(Data(bytes: &to_tvec, count: 24))
        
        connection.send(content: tracker_calibrate_data, completion: NWConnection.SendCompletion.contentProcessed(({ (err) in
            guard let err=err else {return}
            print ("Error when sending calibration data: \(err.localizedDescription)")
        })))
        
    }
    
    func vec3ToSteamVR(_ vec: Vector3d) -> Vector3d{
        return Vector3d(x: vec.x, y: vec.z, z: vec.y)
    }
}
