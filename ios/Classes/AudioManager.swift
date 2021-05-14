//
//  AudioManager.swift
//
//  Created by Jerome Xiong on 2020/1/13.
//  Copyright © 2020 JeromeXiong. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer

open class AudioManager: NSObject {
    public enum Events {
        case ready, stop, playing, pause, ended, error(NSError)
    }

    public static let `default`: AudioManager = {
        return AudioManager()
    }()

    private override init() {
        super.init()
        setRemoteControl()
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    /// 事件回调  ⚠️使用weak防止内存泄露
    open var onEvents: ((Events)->Void)?
    /// 是否正在播放
    open fileprivate(set) var playing: Bool = false
    /// 最近播放的URL
    open fileprivate(set) var url: String?
    /// 标题
    open var desc: String?
    /// 封面图
    open var cover: UIImageView?
    /// 是否自动播放
    open var isAuto: Bool = true

    /// get current position /milisecond
    open var currentTime: Int {
        guard let currentTime = queue.currentItem?.currentTime() else {
            return 0
        }

        if CMTimeGetSeconds(currentTime).isNaN || CMTimeGetSeconds(currentTime).isInfinite{
            return 0
        }else{
            return Int(CMTimeGetSeconds(currentTime)) * 1000
        }
    }
    fileprivate var queue = AVQueuePlayer()
    fileprivate var _playingMusic = Dictionary<String, Any>()
    fileprivate var timeObserver: Any?
    fileprivate var observeStatus: NSKeyValueObservation?
    fileprivate var observeLoaded: NSKeyValueObservation?
    fileprivate var observeBufferEmpty: NSKeyValueObservation?
    fileprivate var observeCanPlay: NSKeyValueObservation?

    fileprivate let session = AVAudioSession.sharedInstance()
    fileprivate var interrupterStatus = false
}
public extension AudioManager {
    /// 必须要调用 start method 才能进行其他操作
    func start(_ link: String, isLocal: Bool = false) {
        var playerItem: AVPlayerItem? = _playingMusic[link] as? AVPlayerItem
        if playerItem == nil {
            stop(url)
            if isLocal {
                guard let path = Bundle.main.path(forResource: link, ofType: "") else {
                    onError(.custom(-1, "link [\(link)] is invalid"))
                    return
                }
                playerItem = AVPlayerItem(url: URL(fileURLWithPath: path))
            }else {
                guard let path = transformURLString(link)?.url else {
                    onError(.custom(-1, "link [\(link)] is invalid"))
                    return
                }
                playerItem = AVPlayerItem(url: path)
            }
            _playingMusic[link] = playerItem
            queue.replaceCurrentItem(with: playerItem)
            queue.actionAtItemEnd = .none
            if #available(iOS 10.0, *) {
                queue.automaticallyWaitsToMinimizeStalling = false
            }
            url = link
        }else {
            play(link)
        }

        observingProps()
        observingTimeChanges()
        setRemoteInfo()
        activateSession()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        NotificationCenter.default.addObserver(self, selector: #selector(playerFinishPlaying(_:)), name: .AVPlayerItemDidPlayToEndTime, object: queue.currentItem)
    }

    /// 播放▶️音乐🎵
    func play(_ link: String? = nil) {
        if playing { return }
        guard let playerItem = _playingMusic[link ?? url ?? ""] as? AVPlayerItem, playerItem.status == .readyToPlay else {
            onError(.notReady)
            return
        }
        queue.play()
        playing = true
        onEvents?(.playing)
    }

    /// 暂停⏸音乐🎵
    func pause(_ link: String? = nil) {
        if !playing { return }
        guard let _ = _playingMusic[link ?? url ?? ""] as? AVPlayerItem else {
            onError(.notReady)
            return
        }
        queue.pause()
        playing = false
        onEvents?(.pause)
    }

    /// 停止⏹音乐🎵
    func stop(_ link: String? = nil) {
        if let observer = timeObserver {
            timeObserver = nil
            queue.removeTimeObserver(observer)
            NotificationCenter.default.removeObserver(self)
        }
        let playerItem = _playingMusic[link ?? url ?? ""] as? AVPlayerItem
        if let playerItem = playerItem {
//            seek(to: 0, link: link ?? url ?? "")
            queue.remove(playerItem)
            _playingMusic.removeValue(forKey: link ?? url ?? "")
        }
        playing = false
        onEvents?(.stop)
    }

    /// 清除所有播放信息
    func clean() {
        stop()
        queue.removeAllItems()
        _playingMusic.removeAll()
        UIApplication.shared.endReceivingRemoteControlEvents()
    }
}
private enum AudioError {
    case notReady
    case custom(Int, String)

    var description: (Int, String) {
        switch self {
        case .notReady:
            return (0, "not ready to play")
        case let .custom(code, msg):
            return (code, msg)
        }
    }
}
fileprivate extension AudioManager {
    func onError(_ error: AudioError) {
        onEvents?(.error(NSError(domain: domain, code: error.description.0, userInfo: ["msg": error.description.1])))
    }
    var domain: String {
        return "\((#file as NSString).lastPathComponent)[\(#line)])"
    }
    func transformURLString(_ string: String) -> URLComponents? {
        guard let urlPath = string.components(separatedBy: "?").first else {
            return nil
        }

        if urlPath.contains("file:") {
            return URLComponents(url: URL(fileURLWithPath: urlPath), resolvingAgainstBaseURL: false)
        }

        var components = URLComponents(string: urlPath)
        if let queryString = string.components(separatedBy: "?").last {
            components?.queryItems = []
            let queryItems = queryString.components(separatedBy: "&")
            for queryItem in queryItems {
                guard let itemName = queryItem.components(separatedBy: "=").first,
                      let itemValue = queryItem.components(separatedBy: "=").last else {
                    continue
                }
                components?.queryItems?.append(URLQueryItem(name: itemName, value: itemValue))
            }
        }
        return components!
    }
    @objc func playerFinishPlaying(_ n: Notification) {
        queue.seek(to: CMTime.zero)
        stop()
        onEvents?(.ended)
    }
    /// 监听属性变化
    func observingProps() {
        observeStatus = queue.currentItem?.observe(\.status) {
            [weak self] _playerItem, change in
            guard let `self` = self else { return }
            if _playerItem.status == .readyToPlay {
                self.playing = self.isAuto
                if self.isAuto {
                    self.onEvents?(.playing)
                }else {
                    self.queue.pause()
                }
            }else {
                self.playing = false
            }
        }

        observeLoaded = queue.currentItem?.observe(\.loadedTimeRanges) {
            [weak self] _playerItem, change in
            guard let `self` = self else { return }
            let ranges = _playerItem.loadedTimeRanges
            guard let timeRange = ranges.first as? CMTimeRange else { return }
            let start = timeRange.start.seconds

//            self.buffer = cached / total * 100
        }

        observeCanPlay = queue.currentItem?.observe(\.isPlaybackLikelyToKeepUp) {
            [weak self] _playerItem, change in
        }
    }
    /// 监听时间变化
    func observingTimeChanges() {
        if let observer = timeObserver {
            timeObserver = nil
            queue.removeTimeObserver(observer)
        }
        let time = CMTimeMake(value: 1, timescale: 1)
        timeObserver = queue.addPeriodicTimeObserver(forInterval: time, queue: DispatchQueue.main, using: {[weak self] (currentPlayerTime) in
            self?.updateLockInfo()
        })
    }
}
// MARK: system
public extension AudioManager {
    /// 注册后台播放
    /// register in application didFinishLaunchingWithOptions method
    func registerBackground(){
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(audioSessionInterrupted(_:)), name: AVAudioSession.interruptionNotification, object: nil)
    }

    func activateSession() {
        do{
            try session.setActive(true)
            try session.setCategory(.playback, options: [.allowBluetooth, .mixWithOthers])
            if #available(iOS 10.0, *) {
                try session.setCategory(.playback, options: [.allowAirPlay, .allowBluetoothA2DP, .mixWithOthers])
            }
            try session.overrideOutputAudioPort(.speaker)

        }catch{}
    }

    /// 中断结束后继续播放
    /// register in application applicationDidBecomeActive
    func interrupterAction(_ isplay: Bool = false) {
        if playing {
            pause()
            interrupterStatus = true
            return
        }
        if interrupterStatus && isplay {
            play()
            interrupterStatus = false
        }
    }
}
fileprivate extension AudioManager {
    /// 锁屏操作
    func setRemoteControl() {
        let remote = MPRemoteCommandCenter.shared()
        remote.playCommand.removeTarget(self)
        remote.pauseCommand.removeTarget(self)
        remote.togglePlayPauseCommand.removeTarget(self)
        if #available(iOS 9.1, *) {
            remote.changePlaybackPositionCommand.removeTarget(self)
        }
        remote.previousTrackCommand.removeTarget(self)
        remote.nextTrackCommand.removeTarget(self)

        remote.playCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            self.play()
            return .success
        }
        remote.pauseCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            self.pause()
            return .success
        }
        remote.togglePlayPauseCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            if self.playing {
                self.pause()
            }else {
                self.play()
            }
            return .success
        }
        if #available(iOS 9.1, *) {
            remote.changePlaybackPositionCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
                let playback = event as! MPChangePlaybackPositionCommandEvent
//                self.seek(to: playback.positionTime)
                return .success
            }
        }
    }
    
    /// 锁屏信息
    func updateLockInfo() {
        guard let _ = url, playing == true else {
            return
        }
        let currentTime = Double(CMTimeGetSeconds(queue.currentTime()))
        setRemoteInfo()
    }
    func setRemoteInfo() {
        let center = MPNowPlayingInfoCenter.default()
        var infos = [String: Any]()
        infos[MPMediaItemPropertyArtist] = desc
        infos[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(currentTime / 1000)
        let image = cover?.image ?? UIImage()
        if #available(iOS 11.0, *) {
            infos[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: image)
        } else {
            let cover = image.withText(self.desc ?? "")!
            if #available(iOS 10.0, *) {
                infos[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: CGSize(width: 200,height: 200), requestHandler: { (size) -> UIImage in
                    return cover
                })
                
            } else {
                infos[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: image)
            }
        }
        
        center.nowPlayingInfo = infos
    }
}

fileprivate extension AudioManager {
    @objc func audioSessionInterrupted(_ n: Notification) {
        print("\n\n\n > > > > > Error Audio Session Interrupted \n\n\n")
        guard let userInfo = n.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        if type == .began {
            print("Interruption began, take appropriate actions")
            interrupterAction()
        }else {
            interrupterAction(true)
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    print("Interruption Ended - playback should resume")
                } else {
                    print("Interruption Ended - playback should NOT resume")
                }
            }
        }
    }
    @objc func handleRouteChange(_ n: Notification) {
        print("\n\n\n > > > > > Audio Route Changed ","\n\n\n")
        guard let userInfo = n.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue:reasonValue) else {
            return
        }
        
        let ports : [AVAudioSession.Port] = [.airPlay,.builtInMic,.bluetoothA2DP,.bluetoothHFP,.builtInReceiver,.bluetoothLE,.builtInReceiver,.headphones,.headsetMic]
        switch reason {
        case .newDeviceAvailable: //Get Notification When Device Connect
            let session = AVAudioSession.sharedInstance()
            for output in session.currentRoute.outputs where ports.contains(where: {$0 == output.portType}) {
                break
            }
        case .oldDeviceUnavailable:  //Get Notification When Device Disconnect
            if let previousRoute =
                userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                for output in previousRoute.outputs where ports.contains(where: {$0 == output.portType}) {
                    //Check Player State
                    
                    break
                }
            }
        default: ()
        }
    }
}
extension UIImage {
    func withText(_ text: String) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.size, false, 0.0)
        self.draw(in: CGRect(origin: .zero, size: self.size))
        
        // 将文字绘制到图片上面
        let rect = CGRect(origin: CGPoint(x: 0, y: self.size.height*0.4), size: self.size)
        
        // 设置文字样式
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        
        let dict: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 20),
            NSAttributedString.Key.foregroundColor: UIColor.green,
            NSAttributedString.Key.paragraphStyle: style
        ]
        (text as NSString).draw(in: rect, withAttributes: dict)
        
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext();
        return resultImage
    }
}

