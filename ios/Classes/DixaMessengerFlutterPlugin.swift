import Flutter
import UIKit
import DixaMessenger

public class DixaMessengerFlutterPlugin: NSObject, FlutterPlugin {
    private var instanceChannels: [String: FlutterMethodChannel] = [:]
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "dixa_messenger_flutter", binaryMessenger: registrar.messenger())
        let instance = DixaMessengerFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "createInstance":
            createInstance(call, result: result)
        case "removeInstance":
            removeInstance(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func createInstance(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let instanceName = args["instanceName"] as? String,
              let configMap = args["config"] as? [String: Any],
              let apiKey = configMap["apiKey"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }
        
        // Create configuration
        var config = DixaConfiguration().apikey(apiKey)
        
        // Set log level
        if let logLevelStr = configMap["logLevel"] as? String {
            let logLevel: LogLevel
            switch logLevelStr {
            case "error": logLevel = .error
            case "warning": logLevel = .warning
            case "all": logLevel = .all
            default: logLevel = .none
            }
            config = config.logLevel(logLevel)
        }
        
        // Set push environment
        if let pushEnvStr = configMap["pushEnvironment"] as? String {
            let pushEnv: PushEnvironment = pushEnvStr == "sandbox" ? .sandbox : .production
            config = config.pushEnvironment(pushEnv)
        }
        
        // Set supported languages
        if let supportedLanguages = configMap["supportedLanguages"] as? [String] {
            config = config.supportedLanguages(supportedLanguages)
        }
        
        // Configure messenger
        Messenger.configure(config)
        
        // Handle authentication
        if let authConfig = configMap["authentication"] as? [String: Any],
           let authType = authConfig["type"] as? String {
            switch authType {
            case "claimed":
                if let username = authConfig["username"] as? String,
                   let email = authConfig["email"] as? String {
                    Messenger.updateUserCredentials(username: username, email: email)
                }
            case "verified":
                if let token = authConfig["verificationToken"] as? String {
                    Messenger.verifyUser(token: token)
                }
            default:
                break
            }
        }
        
        // Create instance-specific channel
        let instanceChannel = FlutterMethodChannel(
            name: "dixa_messenger_flutter/\(instanceName)",
            binaryMessenger: registrar.messenger()
        )
        
        instanceChannel.setMethodCallHandler { [weak self] call, result in
            self?.handleInstanceMethod(instanceName: instanceName, call: call, result: result)
        }
        
        instanceChannels[instanceName] = instanceChannel
        result(nil)
    }
    
    private func removeInstance(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let instanceName = args["instanceName"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }
        
        instanceChannels[instanceName]?.setMethodCallHandler(nil)
        instanceChannels.removeValue(forKey: instanceName)
        result(nil)
    }
    
    private func handleInstanceMethod(instanceName: String, call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "openMessenger":
            guard let viewController = UIApplication.shared.windows.first?.rootViewController else {
                result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "No root view controller", details: nil))
                return
            }
            Messenger.openMessenger(from: viewController, style: .fullScreen)
            result(nil)
            
        case "updateUserCredentials":
            guard let args = call.arguments as? [String: Any],
                  let username = args["username"] as? String,
                  let email = args["email"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            Messenger.updateUserCredentials(username: username, email: email)
            result(nil)
            
        case "setVerificationToken":
            guard let args = call.arguments as? [String: Any],
                  let token = args["token"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            Messenger.verifyUser(token: token)
            result(nil)
            
        case "clearUserCredentials":
            Messenger.clearUserCredentials()
            result(nil)
            
        case "clearVerificationToken":
            Messenger.clearVerificationToken()
            result(nil)
            
        case "setUnreadMessagesCountListener":
            Messenger.unreadMessagesCountListener { [weak self] count in
                self?.instanceChannels[instanceName]?.invokeMethod("onUnreadCountChanged", arguments: ["count": count])
            }
            result(nil)
            
        case "registerPushNotificationToken":
            guard let args = call.arguments as? [String: Any],
                  let tokenStr = args["token"] as? String,
                  let tokenData = tokenStr.data(using: .utf8) else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid token", details: nil))
                return
            }
            Messenger.pushNotification.register(deviceToken: tokenData)
            result(nil)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}