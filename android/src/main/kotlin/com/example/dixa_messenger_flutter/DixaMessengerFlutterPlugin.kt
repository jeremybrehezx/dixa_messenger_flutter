package com.example.dixa_messenger_flutter

import android.app.Activity
import android.app.Application
import android.content.Context
import com.dixa.messenger.DixaMessenger
import com.dixa.messenger.LogLevel
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.ConcurrentHashMap

class DixaMessengerFlutterPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var binaryMessenger: io.flutter.plugin.common.BinaryMessenger
    private var activity: Activity? = null
    private val instanceChannels = ConcurrentHashMap<String, MethodChannel>()
    private val instanceConfigs = ConcurrentHashMap<String, DixaMessenger.Configuration>()
    private var currentInstance: String? = null
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        binaryMessenger = flutterPluginBinding.binaryMessenger
        channel = MethodChannel(binaryMessenger, "dixa_messenger_flutter")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "createInstance" -> createInstance(call, result)
            "removeInstance" -> removeInstance(call, result)
            else -> result.notImplemented()
        }
    }
    
    private fun createInstance(call: MethodCall, result: Result) {
        val instanceName = call.argument<String>("instanceName")!!
        val configMap = call.argument<Map<String, Any>>("config")!!
        
        try {
            // Create configuration
            val configBuilder = DixaMessenger.Configuration.Builder()
                .setApiKey(configMap["apiKey"] as String)
            
            // Set log level
            val logLevelStr = configMap["logLevel"] as? String
            logLevelStr?.let {
                val logLevel = when(it) {
                    "error" -> LogLevel.ERROR
                    "warning" -> LogLevel.WARNING
                    "all" -> LogLevel.ALL
                    else -> LogLevel.NONE
                }
                configBuilder.setLogLevel(logLevel)
            }
            
            // Set preferred language
            val preferredLanguage = configMap["preferredLanguage"] as? String
            preferredLanguage?.let {
                configBuilder.setPreferredLanguage(it)
            }
            
            // Set authentication
            val authConfig = configMap["authentication"] as? Map<String, Any>
            authConfig?.let { auth ->
                when (auth["type"] as String) {
                    "claimed" -> {
                        val username = auth["username"] as String
                        val email = auth["email"] as String
                        configBuilder.setUserCredentials(username, email)
                    }
                    "verified" -> {
                        val token = auth["verificationToken"] as String
                        configBuilder.setVerificationToken(token)
                    }
                }
            }
            
            val config = configBuilder.build()
            instanceConfigs[instanceName] = config
            
            // Initialize DixaMessenger for this instance
            activity?.let { act ->
                if (currentInstance == null) {
                    DixaMessenger.init(config, act.application)
                    currentInstance = instanceName
                }
                
                // Create instance-specific channel
                val instanceChannel = MethodChannel(
                    binaryMessenger,
                    "dixa_messenger_flutter/$instanceName"
                )
                instanceChannel.setMethodCallHandler { call, result ->
                    handleInstanceMethod(instanceName, call, result)
                }
                instanceChannels[instanceName] = instanceChannel
                
                result.success(null)
            } ?: result.error("NO_ACTIVITY", "Activity not available", null)
            
        } catch (e: Exception) {
            result.error("INIT_ERROR", "Failed to initialize Dixa Messenger", e.message)
        }
    }
    
    private fun removeInstance(call: MethodCall, result: Result) {
        val instanceName = call.argument<String>("instanceName")!!
        instanceChannels.remove(instanceName)?.setMethodCallHandler(null)
        result.success(null)
    }
    
    private fun switchToInstance(instanceName: String) {
        val config = instanceConfigs[instanceName] ?: return
        activity?.let { act ->
            DixaMessenger.init(config, act.application)
            currentInstance = instanceName
        }
    }
    
    private fun handleInstanceMethod(instanceName: String, call: MethodCall, result: Result) {
        // Switch to the correct instance before performing any operation
        if (currentInstance != instanceName) {
            switchToInstance(instanceName)
        }

        when (call.method) {
            "openMessenger" -> {
                activity?.let { act ->
                    DixaMessenger.openMessenger(act)
                    result.success(null)
                } ?: result.error("NO_ACTIVITY", "Activity not available", null)
            }
            "openMessengerSheet" -> {
                val offsetPx = call.argument<Int>("offsetPx") ?: 0
                activity?.let { act ->
                    DixaMessenger.openMessenger(act)
                    result.success(null)
                } ?: result.error("NO_ACTIVITY", "Activity not available", null)
            }
            "updateUserCredentials" -> {
                val username = call.argument<String>("username")!!
                val email = call.argument<String>("email")!!
                DixaMessenger.updateUserCredentials(username, email)
                result.success(null)
            }
            "setVerificationToken" -> {
                val token = call.argument<String>("token")!!
                // Note: Direct token update not supported, need to reinitialize
                result.error("NOT_SUPPORTED", "Direct token update not supported", null)
            }
            "clearUserCredentials" -> {
                DixaMessenger.clearUserCredentials()
                result.success(null)
            }
            "clearVerificationToken" -> {
                DixaMessenger.clearVerificationToken()
                result.success(null)
            }
            "setUnreadMessagesCountListener" -> {
                DixaMessenger.setUnreadMessagesCountListener { count ->
                    instanceChannels[instanceName]?.invokeMethod("onUnreadCountChanged", 
                        mapOf("count" to count))
                }
                result.success(null)
            }
            "registerPushNotificationToken" -> {
                val token = call.argument<String>("token")!!
                DixaMessenger.PushNotifications.registerNewToken(token)
                result.success(null)
            }
            "processPushNotification" -> {
                // This would need RemoteMessage object, simplified for now
                result.success(false)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        instanceChannels.values.forEach { it.setMethodCallHandler(null) }
        instanceChannels.clear()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }
}