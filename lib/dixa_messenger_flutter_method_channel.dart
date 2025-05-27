import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dixa_messenger_flutter_platform_interface.dart';

/// An implementation of [DixaMessengerFlutterPlatform] that uses method channels.
class MethodChannelDixaMessengerFlutter extends DixaMessengerFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('dixa_messenger_flutter');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
