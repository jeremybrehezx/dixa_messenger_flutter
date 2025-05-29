import Flutter
import UIKit
import DixaMessenger

public class DixaMessengerFlutterPlugin: NSObject, FlutterPlugin {
    private var instanceChannels: [String: FlutterMethodChannel] = [:]
    private var instanceConfigs: [String: DixaConfiguration] = [:]
    private var registrar: FlutterPluginRegistrar?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "dixa_messenger_flutter", binaryMessenger: registrar.messenger())
        let instance = DixaMessengerFlutterPlugin()
        instance.registrar = registrar
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let methodNotImplemented = FlutterMethodNotImplemented
        
        switch call.method {
        case "createInstance":
            Task { @MainActor in
                await createInstance(call, result: result)
            }
        case "removeInstance":
            Task { @MainActor in
                await removeInstance(call, result: result)
            }
        default:
            result(methodNotImplemented)
        }
    }
    
    @MainActor
    private func createInstance(_ call: FlutterMethodCall, result: @escaping FlutterResult) async {
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
            let pushEnv: DixaConfiguration.PushEnvironment = pushEnvStr == "sandbox" ? .sandbox : .production
            config = config.pushEnvironment(pushEnv)
        }
        
        // Set supported languages
        if let supportedLanguages = configMap["supportedLanguages"] as? [String] {
            config = config.supportedLanguages(supportedLanguages)
        }
        
        // Store configuration for this instance
        instanceConfigs[instanceName] = config
        
        // Configure messenger for this instance
        await Messenger.configure(config)
        
        // Handle authentication
        if let authConfig = configMap["authentication"] as? [String: Any],
           let authType = authConfig["type"] as? String {
            switch authType {
            case "claimed":
                if let username = authConfig["username"] as? String,
                   let email = authConfig["email"] as? String {
                    await Messenger.updateUserCredentials(username: username, email: email)
                }
            case "verified":
                if let token = authConfig["verificationToken"] as? String {
                    await Messenger.verifyUser(with: token)
                }
            default:
                break
            }
        }
        
        // Create instance-specific channel
        guard let registrar = registrar else {
            result(FlutterError(code: "NO_REGISTRAR", message: "No registrar available", details: nil))
            return
        }
        
        let instanceChannel = FlutterMethodChannel(
            name: "dixa_messenger_flutter/\(instanceName)",
            binaryMessenger: registrar.messenger()
        )
        
        instanceChannel.setMethodCallHandler { [weak self] call, result in
            Task {
                await self?.handleInstanceMethod(instanceName: instanceName, call: call, result: result)
            }
        }
        
        instanceChannels[instanceName] = instanceChannel
        result(nil)
    }
    
    @MainActor
    private func removeInstance(_ call: FlutterMethodCall, result: @escaping FlutterResult) async {
        guard let args = call.arguments as? [String: Any],
              let instanceName = args["instanceName"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }
        
        instanceChannels[instanceName]?.setMethodCallHandler(nil)
        instanceChannels.removeValue(forKey: instanceName)
        instanceConfigs.removeValue(forKey: instanceName)
        result(nil)
    }
    
    @MainActor
    private func handleInstanceMethod(instanceName: String, call: FlutterMethodCall, result: @escaping FlutterResult) async {
        let methodNotImplemented = FlutterMethodNotImplemented
        
        // Ensure we have the correct configuration for this instance
        guard let config = instanceConfigs[instanceName] else {
            result(FlutterError(code: "NO_CONFIG", message: "No configuration found for instance", details: nil))
            return
        }
        
        // Reconfigure messenger with the correct configuration
        await Messenger.configure(config)
        
        switch call.method {
        case "openMessenger":
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "No root view controller", details: nil))
                return
            }
            await Messenger.openMessenger(from: rootViewController)
            result(nil)
            
        case "updateUserCredentials":
            guard let args = call.arguments as? [String: Any],
                  let username = args["username"] as? String,
                  let email = args["email"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            await Messenger.updateUserCredentials(username: username, email: email)
            result(nil)
            
        case "setVerificationToken":
            guard let args = call.arguments as? [String: Any],
                  let token = args["token"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            await Messenger.verifyUser(with: token)
            result(nil)
            
        case "clearUserCredentials":
            await Messenger.clearUserCredentials()
            result(nil)
            
        case "clearVerificationToken":
            await Messenger.clearVerificationToken()
            result(nil)
            
        case "setUnreadMessagesCountListener":
            await Messenger.unreadMessagesCountListener { [weak self] count in
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
            await Messenger.pushNotification.register(deviceToken: tokenData)
            result(nil)
            
        default:
            result(methodNotImplemented)
        }
    }
}