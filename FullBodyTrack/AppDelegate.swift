//
//  AppDelegate.swift
//  FullBodyTrack
//
//  Created by DJ Figueroa on 8/5/20.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {


    public let cameraSession = CameraSession()
    public let markerTracker = MarkerTracker()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize OpenCV
        OpenCVWrapper.initialize()
        
        if let marker_dict = Bundle.main.path(forResource: "opencv_aruco_markers", ofType: "aruco") {
            print ("Found marker dict: ", marker_dict)
            if let mdata = FileManager.default.contents(atPath: marker_dict) {
                if let dict = String(data: mdata, encoding: .utf8) {
                    print ("Did find dict, setting...")
                    OpenCVWrapper.setDictionaryFrom(dict)
                }
                
            }
        }
        
        // Initialize directories
        createDirectories()
        
        // Get Camera Calibration
        if let cameraCalibratrionProfiles = getCameraCalibrationProfiles() {
            if let props = cameraCalibratrionProfiles.first {
                OpenCVWrapper.setCameraPropeties(props)
                print (props)
            }
        }
        
        /*// Override point for customization after application launch.
        let decoder = JSONDecoder()
        //let cameraProperties = try! decoder.decode(CodableCameraProperties.self, from: Data(cameraCalibString.utf8))
        if let path = Bundle.main.path(forResource: "cube_tracker", ofType: "json") {
            print ("found path")
            if let contentData = FileManager.default.contents(atPath: path) {
                if let tracker = try? decoder.decode(Tracker.self, from: contentData) {
                    print ("got tracker")
                    addTracker(tracker)
                }
            }
        }
        
        if let path = Bundle.main.path(forResource: "calib_tracker", ofType: "json") {
            print ("found path")
            if let contentData = FileManager.default.contents(atPath: path) {
                if let tracker = try? decoder.decode(Tracker.self, from: contentData) {
                    print ("got tracker")
                    addTracker(tracker)
                }
            }
        }*/
        
        SteamVRConnectionManager.shared.connect(host: "192.168.1.22", port: 8082)
        self.cameraSession.delegate = markerTracker
        markerTracker.delegate = SteamVRConnectionManager.shared
        SteamVRConnectionManager.shared.advertiseTrackers()
        
        print (OpenCVWrapper.openCVVersionString())
        return true
    }
    
    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

