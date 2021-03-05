//
//  SteamVRConnectionManager.swift
//  FullBodyTrack
//
//  Created by DJ Figueroa on 9/1/20.
//

import Foundation
import Network

class SteamVRConnectionManager: NSObject, ObservableObject {
    
    @Published var connected = false
    
    var connection:NWConnection?
    var networkedTrackers = Dictionary<String, Int8>()
   
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
        handshake_data.append(UIDevice.current.name.data(using: .ascii)!)
        handshake_data.append(0x00)
        connection.send(content: handshake_data, completion: NWConnection.SendCompletion.contentProcessed(({ (err) in
            DispatchQueue.main.async {
                self.connected = true
            }
            
            print ("Handshake")
            guard let err=err else {return}
            print ("Error when handshaking: \(err.localizedDescription)")
        })))
        
    }
    
    func advertiseTrackers(trackers: [TrackerManager.Tracker])
    {
        guard let connection=connection else {return}
        
        var tracker_advertise_data = Data()
        tracker_advertise_data.append(OPENVR_PACKET_TYPE.ADVERTISE.rawValue)
        var tracker_id: Int8 = 1
        for tracker in trackers {
            self.networkedTrackers[tracker.id] = tracker_id
            tracker_advertise_data.append(UInt8(bitPattern: tracker_id))
            tracker_advertise_data.append(tracker.id.data(using: .ascii)!)
            tracker_advertise_data.append(0x00)
            tracker_id += 1
        }

        connection.send(content: tracker_advertise_data, completion: NWConnection.SendCompletion.contentProcessed(({ (err) in
            print ("Did advertise")
            guard let err=err else {return}
            print ("Error when advertising trackers: \(err.localizedDescription)")
        })))
        
    }

    func updateTrackers(trackerLocations: [TrackerLocation]) {
        guard let connection=connection else {return}
        var tracker_update_data = Data()
        tracker_update_data.append(OPENVR_PACKET_TYPE.UPDATE.rawValue)
        for tracker in trackerLocations {
            if let tracker_char = self.networkedTrackers[tracker.tracker_id] {
                // Negative tracker ids indicate that the tracker is not visible
                let tracker_char_byte = tracker.visible ? tracker_char : -tracker_char
                tracker_update_data.append(contentsOf: [UInt8(bitPattern: tracker_char_byte)])
                
                var rvec = tracker.rvec
                var tvec = tracker.tvec
                
                // Only append rvec/tvec if it's visible
                if (tracker.visible) {
                    tracker_update_data.append(Data(bytes: &rvec, count: 24))
                    tracker_update_data.append(Data(bytes: &tvec, count: 24))
                }
            }
        }
        
        connection.send(content: tracker_update_data, completion: NWConnection.SendCompletion.contentProcessed(({ (err) in
            guard let err=err else {return}
            print ("Error when sending tracker data: \(err.localizedDescription)")
        })))
    }
    
    func translateWorld(x: Double, y: Double, z: Double, pitch: Double, yaw: Double, roll: Double) {
        
    }
    
    func vec3ToSteamVR(_ vec: Vector3d) -> Vector3d{
        return Vector3d(x: vec.x, y: vec.z, z: vec.y)
    }
}
