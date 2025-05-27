import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'dixa_messenger_flutter_method_channel.dart';

abstract class DixaMessengerFlutterPlatform extends PlatformInterface {
  /// Constructs a DixaMessengerFlutterPlatform.
  DixaMessengerFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static DixaMessengerFlutterPlatform _instance = MethodChannelDixaMessengerFlutter();

  /// The default instance of [DixaMessengerFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelDixaMessengerFlutter].
  static DixaMessengerFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DixaMessengerFlutterPlatform] when
  /// they register themselves.
  static set instance(DixaMessengerFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
