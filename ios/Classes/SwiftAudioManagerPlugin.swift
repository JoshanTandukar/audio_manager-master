import Flutter
import UIKit

public class SwiftAudioManagerPlugin: NSObject, FlutterPlugin {
    fileprivate var registrar: FlutterPluginRegistrar!
    fileprivate static let instance: SwiftAudioManagerPlugin = {
        return SwiftAudioManagerPlugin()
    }()
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "audio_manager", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
        
        instance.registrar = registrar
        AudioManager.default.onEvents = { event in
            switch event {
            case .error(let e):
                DispatchQueue.main.async {
                    AudioManager.default.clean()
                }
                channel.invokeMethod("error", arguments: e.description)
                break
            case .ended:
                channel.invokeMethod("ended", arguments: nil)
                break
            case .stop:
                channel.invokeMethod("stop", arguments: nil)
                break
            case .ready:
                break
            case .playing:
                break
            case .pause:
                break
            }
    }

     func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? Dictionary<String,Any> ?? [:]
        let url = arguments["url"] as? String
        print("arguments: ", arguments)
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "start":
            guard var url = url else {
                result("参数错误")
                return
            }
            AudioManager.default.desc = arguments["desc"] as? String
            if let cover = arguments["cover"] as? String, let isLocalCover = arguments["isLocalCover"] as? Bool {
                if !isLocalCover, let _cover = URL(string: cover) {
                    let request = URLRequest(url: _cover)
                    NSURLConnection.sendAsynchronousRequest(request, queue: OperationQueue.main) { (_, data, error) in
                        if let data = data {
                            AudioManager.default.cover = UIImageView(image: UIImage(data: data))
                        }
                        if let error = error as NSError? {
                            result(error.description)
                        }
                    }
//                }else if let path = self.getLocal(SwiftAudioManagerPlugin.instance.registrar, path: cover) {
//                    AudioManager.default.cover = UIImageView(image: UIImage(contentsOfFile: path))
                }
            }
            let isAuto = arguments["isAuto"] as? Bool ?? true
            AudioManager.default.isAuto = isAuto
        case "play":
            AudioManager.default.play(url)
            result(AudioManager.default.playing)
        case "pause":
            AudioManager.default.pause(url)
            result(AudioManager.default.playing)
        case "stop":
            AudioManager.default.stop()
        case "release":
            AudioManager.default.clean()
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func getLocal(_ registrar: FlutterPluginRegistrar, path: String) -> String? {
        let key = registrar.lookupKey(forAsset: path)
        return Bundle.main.path(forResource: key, ofType: nil)
    }

     func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [AnyHashable : Any] = [:]) -> Bool {
        AudioManager.default.registerBackground()
        return true
    }

//    public func applicationWillResignActive(_ application: UIApplication) {
//        backTaskId = backgroundPlayerID(backTaskId)
//    }

         var _: UIBackgroundTaskIdentifier = .invalid
    /// 设置后台任务ID
     func backgroundPlayerID(_ backTaskId: UIBackgroundTaskIdentifier) -> UIBackgroundTaskIdentifier {
        var taskId = UIBackgroundTaskIdentifier.invalid;
        taskId = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        if taskId != .invalid && backTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backTaskId)
        }
        return taskId
    }
}

}
