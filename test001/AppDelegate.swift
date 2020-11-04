//
//  AppDelegate.swift
//  test001
//
//  Created by sai on 2020/11/4.
//

import UIKit
import Photos
import Logboard

let logger = Logboard.with("com.haishinkit.Exsample.iOS")

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setPreferredSampleRate(44_100)
            // https://stackoverflow.com/questions/51010390/avaudiosession-setcategory-swift-4-2-ios-12-play-sound-on-silent
            if #available(iOS 10.0, *) {
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            } else {
                session.perform(NSSelectorFromString("setCategory:withOptions:error:"), with: AVAudioSession.Category.playAndRecord, with: [AVAudioSession.CategoryOptions.allowBluetooth])
                try? session.setMode(.default)
            }
            try session.setActive(true)
        } catch {
        }

         if PHPhotoLibrary.authorizationStatus() == .notDetermined {
             
             PHPhotoLibrary.requestAuthorization({ (status) in
                 
                 if status == .authorized {
                     print("点同意")
                 } else if status == .denied || status == .restricted {
                     print("点拒绝")
                 }
                 
             })
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

