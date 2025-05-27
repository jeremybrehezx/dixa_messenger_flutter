library;

import 'package:flutter/services.dart';

/// Main class for managing multiple Dixa Messenger instances
class DixaMessengerFlutter {
  static const MethodChannel _channel = MethodChannel('dixa_messenger_flutter');
  static final Map<String, DixaMessengerInstance> _instances = {};
  
  // Private constructor to prevent instantiation
  DixaMessengerFlutter._();
  
  /// Creates and configures a new messenger instance
  /// 
  /// [instanceName] - Unique identifier for this messenger instance
  /// [config] - Configuration for the messenger
  static Future<DixaMessengerInstance> createInstance(
    String instanceName,
    DixaMessengerConfig config,
  ) async {
    if (_instances.containsKey(instanceName)) {
      throw Exception('Instance with name $instanceName already exists');
    }
    
    await _channel.invokeMethod('createInstance', {
      'instanceName': instanceName,
      'config': config.toMap(),
    });
    
    final instance = DixaMessengerInstance._(instanceName);
    _instances[instanceName] = instance;
    return instance;
  }
  
  /// Gets an existing messenger instance by name
  static DixaMessengerInstance? getInstance(String instanceName) {
    return _instances[instanceName];
  }
  
  /// Removes a messenger instance
  static Future<void> removeInstance(String instanceName) async {
    await _channel.invokeMethod('removeInstance', {
      'instanceName': instanceName,
    });
    _instances.remove(instanceName);
  }
}

/// Represents a single Dixa Messenger instance
class DixaMessengerInstance {
  final String instanceName;
  late final MethodChannel _instanceChannel;
  
  DixaMessengerInstance._(this.instanceName) {
    _instanceChannel = MethodChannel('dixa_messenger_flutter/$instanceName');
  }
  
  /// Opens the messenger interface
  Future<void> openMessenger() async {
    await _instanceChannel.invokeMethod('openMessenger');
  }
  
  /// Opens the messenger as a bottom sheet (Android only)
  /// [offsetPx] - Optional offset from top in pixels
  Future<void> openMessengerSheet({int offsetPx = 0}) async {
    await _instanceChannel.invokeMethod('openMessengerSheet', {
      'offsetPx': offsetPx,
    });
  }
  
  /// Updates user credentials for claimed authentication
  Future<void> updateUserCredentials(String username, String email) async {
    await _instanceChannel.invokeMethod('updateUserCredentials', {
      'username': username,
      'email': email,
    });
  }
  
  /// Sets verification token for verified authentication
  Future<void> setVerificationToken(String token) async {
    await _instanceChannel.invokeMethod('setVerificationToken', {
      'token': token,
    });
  }
  
  /// Clears user credentials
  Future<void> clearUserCredentials() async {
    await _instanceChannel.invokeMethod('clearUserCredentials');
  }
  
  /// Clears verification token
  Future<void> clearVerificationToken() async {
    await _instanceChannel.invokeMethod('clearVerificationToken');
  }
  
  /// Sets listener for unread messages count
  Future<void> setUnreadMessagesCountListener(
    Function(int count) onUnreadCountChanged,
  ) async {
    _instanceChannel.setMethodCallHandler((call) async {
      if (call.method == 'onUnreadCountChanged') {
        final count = call.arguments['count'] as int;
        onUnreadCountChanged(count);
      }
    });
    
    await _instanceChannel.invokeMethod('setUnreadMessagesCountListener');
  }
  
  /// Registers FCM token for push notifications
  Future<void> registerPushNotificationToken(String token) async {
    await _instanceChannel.invokeMethod('registerPushNotificationToken', {
      'token': token,
    });
  }
  
  /// Processes incoming push notification
  Future<bool> processPushNotification(Map<String, dynamic> message) async {
    final result = await _instanceChannel.invokeMethod('processPushNotification', {
      'message': message,
    });
    return result as bool;
  }
}

/// Configuration class for Dixa Messenger
class DixaMessengerConfig {
  final String apiKey;
  final DixaLogLevel logLevel;
  final String? preferredLanguage;
  final List<String>? supportedLanguages;
  final DixaAuthenticationConfig? authentication;
  final DixaPushEnvironment pushEnvironment;
  
  const DixaMessengerConfig({
    required this.apiKey,
    this.logLevel = DixaLogLevel.none,
    this.preferredLanguage,
    this.supportedLanguages,
    this.authentication,
    this.pushEnvironment = DixaPushEnvironment.production,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'apiKey': apiKey,
      'logLevel': logLevel.name,
      'preferredLanguage': preferredLanguage,
      'supportedLanguages': supportedLanguages,
      'authentication': authentication?.toMap(),
      'pushEnvironment': pushEnvironment.name,
    };
  }
}

/// Authentication configuration
class DixaAuthenticationConfig {
  final DixaAuthenticationType type;
  final String? username;
  final String? email;
  final String? verificationToken;
  
  const DixaAuthenticationConfig.anonymous() : 
    type = DixaAuthenticationType.anonymous,
    username = null,
    email = null,
    verificationToken = null;
  
  const DixaAuthenticationConfig.claimed({
    required this.username,
    required this.email,
  }) : type = DixaAuthenticationType.claimed,
       verificationToken = null;
  
  const DixaAuthenticationConfig.verified({
    required this.verificationToken,
  }) : type = DixaAuthenticationType.verified,
       username = null,
       email = null;
  
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'username': username,
      'email': email,
      'verificationToken': verificationToken,
    };
  }
}

/// Log levels for Dixa Messenger
enum DixaLogLevel {
  none,
  error,
  warning,
  all,
}

/// Authentication types
enum DixaAuthenticationType {
  anonymous,
  claimed,
  verified,
}

/// Push notification environments
enum DixaPushEnvironment {
  production,
  sandbox,
}