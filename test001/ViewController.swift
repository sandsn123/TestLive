//
//  ViewController.swift
//  test001
//
//  Created by sai on 2020/11/4.
//

import UIKit
import HaishinKit
import Photos
import MediaToolbox
import CoreFoundation
import VideoToolbox

class ViewController: UIViewController {
    var liveButton: UIButton!
    var rtmpStream: RTMPStream!
    var rtmpConnection: RTMPConnection!
    var timer: Timer?
    private var firstPublishTime: Int64?
    var lastTimeStr: String = ""
    private var hasRegistRtmpObserver = false
    
    var url = "rtmps://live-api-s.facebook.com:443/rtmp/"
    var key = "1275497276161627?s_bl=1&s_hv=0&s_psm=1&s_sc=1275497302828291&s_sw=0&s_vt=api-s&a=AbwYuU4rhE8TqgZ2"
    
    var isLiving = false
    override func viewDidLoad() {
        super.viewDidLoad()
       
        setupRtmpConnection()
    }


}

extension ViewController {
    private func setupRtmpConnection() {
        rtmpConnection = RTMPConnection()
        rtmpStream = RTMPStream(connection: rtmpConnection)
        //        if let orientation = DeviceUtil.videoOrientation(by: UIApplication.shared.statusBarOrientation) {
        //            rtmpStream.orientation = orientation
        //        }
        rtmpStream.orientation = getCameraLandscapeOrientation()
        rtmpStream.delegate = self
        rtmpStream.attachCamera(AVCaptureDevice.default(for: .video)) { error in
            logger.warn(error.description)
        }
        rtmpStream.captureSettings = [
            .fps: 30,
            .sessionPreset: AVCaptureSession.Preset.hd1280x720,
            .continuousAutofocus: true,
            .continuousExposure: true,
            //         .preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode.auto
        ]
        rtmpStream.attachAudio(AVCaptureDevice.default(for: .audio)) { error in
            logger.warn(error.description)
        }
        rtmpStream.videoSettings = [
            .width: 1280,
            .height: 720,
            .bitrate: 2 * 1000 * 1024,
            .profileLevel: kVTProfileLevel_H264_Baseline_AutoLevel,
            .maxKeyFrameIntervalDuration: 2,
        ]
        rtmpStream.audioSettings = [
            .muted: false,
            .bitrate: 128 * 1024,
            .sampleRate: 44100,
        ]
        
        let hkView = HKView(frame: view.bounds)
        hkView.videoGravity = AVLayerVideoGravity.resizeAspectFill
        hkView.attachStream(rtmpStream)

        // add ViewController#view
        view.addSubview(hkView)
        
        let btn = UIButton(frame: CGRect(x: 80, y: 80, width: 80, height: 40))
        btn.setTitle("点击直播", for: .normal)
        btn.addTarget(self, action: #selector(onTappedLiveButton(sender:)), for: .touchUpInside)
        liveButton = btn
        btn.backgroundColor = .red
        self.view.addSubview(btn)
    }
    
    func getCameraLandscapeOrientation() -> AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        default:
            switch UIApplication.shared.statusBarOrientation {
            case .landscapeLeft:
                return .landscapeLeft
            case .landscapeRight:
                return .landscapeRight
            default:
                return .landscapeLeft
            }
        }
    }
    @objc func onTappedLiveButton(sender: UIButton) {
        if isLiving {
            self.stopLiveUI()
        } else {
            self.excuteLive()
        }
    }
    func excuteLive() {
        guard !isLiving else {
            return
        }
        setupTimer()
        self.liveButton.setTitle("准备直播", for: .normal)
        if !self.hasRegistRtmpObserver {
            rtmpConnection.addEventListener(.rtmpStatus, selector:#selector(rtmpStatusHandler(_:)), observer: self)
            rtmpConnection.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
            rtmpStream.addObserver(self, forKeyPath: "currentFPS", options: .new, context: nil)
            self.hasRegistRtmpObserver = true
        }
        rtmpConnection.connect(url)
        
    }
    
    func stopLiveUI() {
        guard isLiving else {
            return
        }
        self.isLiving = false
        self.liveButton.setTitle("点击直播", for: .normal)
        stopTimer()
        self.rtmpConnection.dispatch(.rtmpStatus, bubbles: false, data: RTMPStream.Code.connectClosed)
        self.rtmpConnection.close()
        if self.hasRegistRtmpObserver {
            rtmpConnection.removeEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler(_:)), observer: self)
            rtmpStream.removeObserver(self, forKeyPath: "currentFPS", context: nil)
            self.hasRegistRtmpObserver = false
        }
        
    }
    
    func setupTimer() {
        if self.timer == nil {
            timer = Timer(timeInterval: 1.0, target: self, selector: #selector(timerChange), userInfo: nil, repeats: true)
            timer?.fire()
            RunLoop.current.add(timer!, forMode: .common)
        }
    }
    
    func stopTimer() {
        if let timer = self.timer {
            timer.invalidate()
            self.timer = nil
        }
    }
    
    @objc func timerChange() {
        DispatchQueue.main.async {
            // TopView
            if self.isLiving {
                var timeStr = self.lastTimeStr
                if let firstTime = self.firstPublishTime {
                    let timeOffer = Date().milliStamp - firstTime
                    let time = timeOffer / 1000
                    timeStr = timerText(for: Int(time))
                }
                if timeStr != self.lastTimeStr {
                    self.liveButton.setTitle(timeStr, for: .normal)
                    self.lastTimeStr = timeStr
                }
            }
        }
        
    }
    
    func appendVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        rtmpStream?.appendSampleBuffer(sampleBuffer, withType: .video)
    }
    
    /// RTMP 连接回调
    @objc func rtmpStatusHandler(_ notification:Notification) {
        let e:Event = Event.from(notification)
        if let data = e.data as? RTMPStream.Code, data == .connectClosed {
            stopLiveUI()
        } else if let data:ASObject = e.data as? ASObject , let code:String = data["code"] as? String {
            switch code {
            case RTMPConnection.Code.connectSuccess.rawValue:
                print("\n-G8Live =========================\nConnected...\n\n")
                rtmpStream!.publish(key)
                
            //                retryCount = 0
            case RTMPStream.Code.publishStart.rawValue:

                print("\n-G8Live =========================\nWe are LIVE !! publishing to \(key) \n\n")
                self.isLiving = true
                self.firstPublishTime = Date().milliStamp
                
            default:
                print("\n-G8Live =========================\nFailed Error: \(code)\n\n")
                
                self.stopLiveUI()
                break
            }
        }
    }
    
    @objc
    private func rtmpErrorHandler(_ notification: Notification) {
      
        self.stopLiveUI()
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if Thread.isMainThread {
            print("\(rtmpStream.currentFPS)")
        }
        
    }
}

extension ViewController: RTMPStreamDelegate {
    func rtmpStreamDidClear(_ stream: RTMPStream) {
    }
    
    func rtmpStream(_ stream: HaishinKit.RTMPStream, didPublishInsufficientBW connection: HaishinKit.RTMPConnection){}

    func rtmpStream(_ stream: HaishinKit.RTMPStream, didPublishSufficientBW connection: HaishinKit.RTMPConnection){}
    
    func rtmpStream(_ stream: HaishinKit.RTMPStream, didOutput video: CMSampleBuffer) {
//        self.appendVideoSampleBuffer(video)
    }
    func rtmpStream(_ stream: HaishinKit.RTMPStream, didOutput audio: AVAudioBuffer, presentationTimeStamp: CMTime) {
        
    }
}


// get system time
extension Date {

    /// 获取当前 秒级 时间戳 - 10位
    var timeStamp : Int32 {
        let timeInterval: TimeInterval = self.timeIntervalSince1970
        let timeStamp = Int32(timeInterval)
        return timeStamp
    }

    /// 获取当前 毫秒级 时间戳 - 13位
    var milliStamp : Int64 {
        let timeInterval: TimeInterval = self.timeIntervalSince1970
        let millisecond = CLongLong(round(timeInterval*1000))
        return millisecond
    }
}

func timerText(for timeSinceNow: Int) -> String {
    let timeStr: String
    let time = timeSinceNow
    if time < 60 {
        timeStr = String(format: "00:00:%02d", time)
    } else if time < 3600 {
        timeStr = String(format: "00:%02d:%02d", time/60, time%60)
    } else {
        timeStr = String(format: "%02d:%02d:%02d", time/3600,(time-time/3600*3600)/60,time%60)
    }
   return timeStr + " "
}
