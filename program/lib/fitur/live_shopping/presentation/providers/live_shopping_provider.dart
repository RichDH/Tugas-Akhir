import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:program/core/services/api_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// PERBAIKAN: Tambahkan state isLiveEnded
class LiveShoppingState {
  final bool isLoading;
  final bool isConnected;
  final HMSVideoTrack? localVideoTrack;
  final HMSVideoTrack? remoteVideoTrack;
  final String? error;
  final String? currentRole;
  final bool isLiveEnded; // Untuk menandakan live sudah berakhir

  LiveShoppingState({
    this.isLoading = false,
    this.isConnected = false,
    this.localVideoTrack,
    this.remoteVideoTrack,
    this.error,
    this.currentRole,
    this.isLiveEnded = false,
  });

  LiveShoppingState copyWith({
    bool? isLoading,
    bool? isConnected,
    HMSVideoTrack? localVideoTrack,
    HMSVideoTrack? remoteVideoTrack,
    String? error,
    String? currentRole,
    bool? isLiveEnded,
  }) {
    return LiveShoppingState(
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      localVideoTrack: localVideoTrack ?? this.localVideoTrack,
      remoteVideoTrack: remoteVideoTrack ?? this.remoteVideoTrack,
      error: error,
      currentRole: currentRole ?? this.currentRole,
      isLiveEnded: isLiveEnded ?? this.isLiveEnded,
    );
  }
}

class LiveShoppingNotifier extends StateNotifier<LiveShoppingState>
    implements HMSUpdateListener {
  final HMSSDK _hmsSDK;
  final ApiService _apiService;
  final FirebaseFirestore _firestore;

  LiveShoppingNotifier()
      : _hmsSDK = HMSSDK(),
        _apiService = ApiService(),
        _firestore = FirebaseFirestore.instance,
        super(LiveShoppingState()) {
    _hmsSDK.addUpdateListener(listener: this);
  }

  Future<void> joinRoom({
    required String roomId,
    required String userId,
    required String username,
    required String role,
    String? liveTitle,
  }) async {
    state = state.copyWith(isLoading: true, error: null, currentRole: role, isLiveEnded: false);
    try {
      if (role == 'broadcaster') {
        await _firestore.collection('live_sessions').doc(userId).set({
          'hostId': userId,
          'hostName': username,
          'roomId': roomId,
          'title': liveTitle ?? 'Live Shopping',
          'status': 'ongoing',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      final token = await _apiService.get100msToken(
          roomId: roomId, userId: userId, role: role);
      await _hmsSDK.build();
      HMSConfig config = HMSConfig(authToken: token, userName: username);
      await _hmsSDK.join(config: config);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> leaveRoom() async {
    final userIsBroadcaster = state.currentRole == 'broadcaster';
    final userId = FirebaseAuth.instance.currentUser?.uid;
    await _hmsSDK.leave();
    if (userIsBroadcaster && userId != null) {
      await _firestore.collection('live_sessions').doc(userId).update({
        'status': 'ended',
      }).catchError((e) => debugPrint("Gagal update status live: $e"));
    }
    state = LiveShoppingState();
  }

  @override
  void onJoin({required HMSRoom room}) {
    state = state.copyWith(isLoading: false, isConnected: true);
    if (room.peers != null) {
      for (var peer in room.peers!) {
        if (!peer.isLocal) {
          final videoTrack = peer.videoTrack;
          if (videoTrack != null && videoTrack is HMSVideoTrack) {
            state = state.copyWith(remoteVideoTrack: videoTrack);
          }
        }
      }
    }
  }

  // PERBAIKAN: Implementasikan onPeerUpdate untuk mendeteksi Jastiper keluar
  @override
  void onPeerUpdate({required HMSPeer peer, required HMSPeerUpdate update}) {
    // Jika ada pengguna yang keluar (leave) dan dia bukan kita (berarti dia Jastiper/host)
    if (update == HMSPeerUpdate.peerLeft && !peer.isLocal) {
      // Set state bahwa siaran telah berakhir
      state = state.copyWith(isLiveEnded: true);
    }
  }

  @override
  void onTrackUpdate(
      {required HMSTrack track,
        required HMSTrackUpdate trackUpdate,
        required HMSPeer peer}) {
    if (track.kind == HMSTrackKind.kHMSTrackKindVideo) {
      if (trackUpdate == HMSTrackUpdate.trackAdded) {
        if (peer.isLocal) {
          state = state.copyWith(localVideoTrack: track as HMSVideoTrack);
        } else {
          state = state.copyWith(remoteVideoTrack: track as HMSVideoTrack);
        }
      } else if (trackUpdate == HMSTrackUpdate.trackRemoved) {
        if (peer.isLocal) {
          state = state.copyWith(localVideoTrack: null);
        } else {
          // Saat track host dihapus, tandai juga live berakhir
          state = state.copyWith(remoteVideoTrack: null, isLiveEnded: true);
        }
      }
    }
  }

  @override
  void onHMSError({required HMSException error}) {
    state = state.copyWith(isLoading: false, error: error.message);
  }

  // ... (Sisa override method lainnya biarkan kosong) ...
  @override
  void onChangeTrackStateRequest({required HMSTrackChangeRequest hmsTrackChangeRequest}) {}
  @override
  void onMessage({required HMSMessage message}) {}
  @override
  void onReconnected() {}
  @override
  void onReconnecting() {}
  @override
  void onRemovedFromRoom({required HMSPeerRemovedFromPeer hmsPeerRemovedFromPeer}) {}
  @override
  void onRoleChangeRequest({required HMSRoleChangeRequest roleChangeRequest}) {}
  @override
  void onUpdateSpeakers({required List<HMSSpeaker> updateSpeakers}) {}
  @override
  void onSessionStoreAvailable({HMSSessionStore? hmsSessionStore}) {}
  @override
  void onPeerListUpdate({required List<HMSPeer> addedPeers, required List<HMSPeer> removedPeers}) {}
  @override
  void onRoomUpdate({required HMSRoom room, required HMSRoomUpdate update}) {}

  @override
  void onAudioDeviceChanged({HMSAudioDevice? currentAudioDevice, List<HMSAudioDevice>? availableAudioDevice}) {
    // TODO: implement onAudioDeviceChanged
  }
}

final liveShoppingProvider =
StateNotifierProvider.autoDispose<LiveShoppingNotifier, LiveShoppingState>((ref) {
  return LiveShoppingNotifier();
});

final liveSessionsStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) {
  return FirebaseFirestore.instance
      .collection('live_sessions')
      .where('status', isEqualTo: 'ongoing')
      .orderBy('createdAt', descending: true)
      .snapshots();
});