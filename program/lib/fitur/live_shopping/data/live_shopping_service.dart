import 'package:hmssdk_flutter/hmssdk_flutter.dart';

class LiveShoppingService {
  late final HMSSDK _hmsSdk;

  HMSSDK get sdk => _hmsSdk;

  Future<void> init({
    required String userName,
    required String authToken,
    required HMSUpdateListener listener,
  }) async {
    _hmsSdk = HMSSDK();
    _hmsSdk.addUpdateListener(listener: listener);

    final config = HMSConfig(
      userName: userName,
      authToken: authToken,
    );

    await _hmsSdk.join(config: config);
  }

  Future<void> leave() async {
    await _hmsSdk.leave();
  }
}
