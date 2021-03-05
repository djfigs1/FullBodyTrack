//
//  AppDelegate.swift
//  FullBodyTrack
//
//  Created by DJ Figueroa on 8/5/20.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
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
                OpenCVWrapper.setCameraPropeties(codableCamPropsToObjC(codable: props))
                print (props)
            }
        }
        
        // Start capture session
        TrackerManager.shared.cameraSession.setUpAVCapture() { error in
            guard let error = error else {
                print ("AVCapture initialized!")
                TrackerManager.shared.cameraSession.startCapturing()
                return
            }
            print ("Error initalizing AVCapture: \(error.localizedDescription)")
        }
        
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

