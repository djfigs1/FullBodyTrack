//
//  FileManager.swift
//  FullBodyTrack
//
//  Created by DJ Figueroa on 12/13/20.
//

import Foundation

let CALIBRATION_DIRECTORY = "calibration"
let TRACKERS_DIRECTORY = "trackers"

func createDirectories() {
    let filesURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let trackersURL = filesURL.appendingPathComponent(TRACKERS_DIRECTORY)
    if !FileManager.default.fileExists(atPath: trackersURL.path) {
        print ("Trackers doesn't exist")
        do {
            try FileManager.default.createDirectory(at: trackersURL, withIntermediateDirectories: false, attributes: nil)
            print ("Created trackers directory")
        } catch {
            print ("Error creating trackers directory: \(error.localizedDescription)")
        }
    }
    
    let calibrationURL = filesURL.appendingPathComponent(CALIBRATION_DIRECTORY)
    if !FileManager.default.fileExists(atPath: calibrationURL.path) {
        print ("Calibration doesn't exist")
        do {
            try FileManager.default.createDirectory(at: calibrationURL, withIntermediateDirectories: false, attributes: nil)
            print ("Created calibration directory")
        } catch {
            print ("Error creating calibration directory: \(error.localizedDescription)")
        }
    }
}

func getCameraCalibrationProfiles() -> [CameraProperties]? {
    let filesURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let calibrationURL = filesURL.appendingPathComponent(CALIBRATION_DIRECTORY)
    do {
        let calibrationFiles = try FileManager.default.contentsOfDirectory(at: calibrationURL, includingPropertiesForKeys: nil, options: [])
        var camera_properties: [CameraProperties] = []
        let decoder = JSONDecoder()
        for file in calibrationFiles {
            var isDirectory = ObjCBool(false)
            if (FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory)) {
                if (!isDirectory.boolValue) {
                    if (file.pathExtension == "json") {
                        if let props = try? decoder.decode(CodableCameraProperties.self, from: Data(contentsOf: file)) {
                            camera_properties.append(codableToCameraProperties(codable: props))
                        }
                    }
                }
            }
        }
        return camera_properties
    } catch {
        print ("Couldn't search for camera properties")
        return nil
    }
}

func getTrackers() -> [UniqueTracker]? {
    let filesURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let trackersURL = filesURL.appendingPathComponent(TRACKERS_DIRECTORY)
    do {
        let trackerFiles = try FileManager.default.contentsOfDirectory(at: trackersURL, includingPropertiesForKeys: nil, options: [])
        var trackers: [UniqueTracker] = []
        let decoder = JSONDecoder()
        for file in trackerFiles {
            var isDirectory = ObjCBool(false)
            if (FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory)) {
                if (!isDirectory.boolValue) {
                    if (file.pathExtension == "json") {
                        if let tracker = try? decoder.decode(Tracker.self, from: Data(contentsOf: file)) {
                            let uniqueTracker = UniqueTracker(id: file.lastPathComponent, tracker: tracker, active: false)
                            trackers.append(uniqueTracker)
                        }
                    }
                }
            }
        }
        for tracker in trackers {
            print (tracker.id)
        }
        return trackers
    } catch {
        print ("Couldn't search for trackers")
        return nil
    }
}

func saveCameraCalibration(_ properties: CameraProperties) {
    let camera = cameraPropertiesToCodable(properties: properties)
    let filesURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let calibrationURL = filesURL.appendingPathComponent(CALIBRATION_DIRECTORY)
    let calibrationFileName = "calib-0.json"
    let calibrationFileURL = calibrationURL.appendingPathComponent(calibrationFileName)
    if (FileManager.default.fileExists(atPath: calibrationFileURL.path)) {
        print ("Calibration file already exists, overwriting it...")
    }
    let json_encoder = JSONEncoder()
    do {
        let json = try json_encoder.encode(camera)
        try json.write(to: calibrationFileURL)
    } catch let error {
        print ("Error when saving camera calibration: \(error)")
    }
}

/*
func getLevelsFromDirectory() -> [BSLevel]? {
    let filesURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let chartsURL = filesURL.appendingPathComponent(LEVELS_DIRECTORY)
    do {
        let levelFiles = try FileManager.default.contentsOfDirectory(at: chartsURL, includingPropertiesForKeys: nil, options: [])
        var levels = [BSLevel]()
        for file in levelFiles {
            var isDirectroy = ObjCBool(true)
            if (FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectroy)) {
                if (isDirectroy.boolValue) {
                    if let level = getLevelFromDirectory(levelURL: file) {
                        levels.append(level)
                    }
                }
            }
        }
        return levels
    } catch {
        
    }
    //TODO: Return levels
    return nil
}

func getLevelFromDirectory(levelURL: URL) -> BSLevel? {
    let infoURL = levelURL.appendingPathComponent("Info.dat")
    if (FileManager.default.fileExists(atPath: infoURL.path)) {
        do {
            let infoData = try Data(contentsOf: infoURL)
            let info = try JSONDecoder().decode(BSLevelInfo.self, from: infoData)
            return BSLevel(directoryURL: levelURL, levelInfo: info)
        } catch {
            print ("Error: \(error.localizedDescription)")
        }
    } else {
        print("Error: Can't find Info.dat")
        return nil
    }
    return nil
}
*/
