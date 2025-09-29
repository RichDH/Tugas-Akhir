import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/core/services/api_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class LiveShoppingState {
  final bool isLoading;
  final bool isConnected;
  final HMSVideoTrack? localVideoTrack;
  final HMSVideoTrack? remoteVideoTrack;
  final String? error;
  final String? currentRole;
  final bool isLiveEnded;
  final List<HMSMessage> messages;
  final double currentItemPrice;
  final HMSPeer? hostPeer;
  final bool isJoining;
  final String? roomId;
  final String? sessionId; // TAMBAHAN: untuk tracking session ID

  LiveShoppingState({
    this.isLoading = false,
    this.isConnected = false,
    this.localVideoTrack,
    this.remoteVideoTrack,
    this.error,
    this.currentRole,
    this.isLiveEnded = false,
    this.messages = const [],
    this.currentItemPrice = 0.0,
    this.hostPeer,
    this.isJoining = false,
    this.roomId,
    this.sessionId,
  });

  LiveShoppingState copyWith({
    bool? isLoading,
    bool? isConnected,
    HMSVideoTrack? localVideoTrack,
    HMSVideoTrack? remoteVideoTrack,
    String? error,
    String? currentRole,
    bool? isLiveEnded,
    List<HMSMessage>? messages,
    double? currentItemPrice,
    HMSPeer? hostPeer,
    bool? isJoining,
    String? roomId,
    String? sessionId,
  }) {
    return LiveShoppingState(
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      localVideoTrack: localVideoTrack ?? this.localVideoTrack,
      remoteVideoTrack: remoteVideoTrack ?? this.remoteVideoTrack,
      error: error,
      currentRole: currentRole ?? this.currentRole,
      isLiveEnded: isLiveEnded ?? this.isLiveEnded,
      messages: messages ?? this.messages,
      currentItemPrice: currentItemPrice ?? this.currentItemPrice,
      hostPeer: hostPeer ?? this.hostPeer,
      isJoining: isJoining ?? this.isJoining,
      roomId: roomId ?? this.roomId,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

class LiveShoppingNotifier extends StateNotifier<LiveShoppingState>
    implements HMSUpdateListener {
  HMSSDK? _hmsSDK;
  final ApiService _apiService;
  final FirebaseFirestore _firestore;
  final Ref _ref;
  bool _disposed = false;

  LiveShoppingNotifier(this._ref)
      : _apiService = ApiService(),
        _firestore = FirebaseFirestore.instance,
        super(LiveShoppingState());

  // FUNGSI YANG DIPERBAIKI: Inisialisasi HMS SDK
  Future<void> _initializeHMSSDK() async {
    try {
      if (_hmsSDK != null) {
        debugPrint("Disposing existing HMS SDK...");
        _hmsSDK!.removeUpdateListener(listener: this);
        try {
          await _hmsSDK!.leave();
        } catch (e) {
          debugPrint("Error leaving during cleanup: $e");
        }
      }

      debugPrint("Creating new HMS SDK instance...");
      _hmsSDK = HMSSDK();
      _hmsSDK!.addUpdateListener(listener: this);

    } catch (e) {
      debugPrint("Error initializing HMS SDK: $e");
    }
  }

  // FUNGSI BARU: End active room di server 100ms untuk broadcaster
  Future<void> _endActiveRoomOnServer(String roomId) async {
    try {
      debugPrint("Ending active room on 100ms server: $roomId");

      // Panggil API untuk end active room
      const String baseUrl = 'https://api.100ms.live/v2';
      const String managementToken = 'YOUR_MANAGEMENT_TOKEN_HERE'; // Ganti dengan management token Anda

      final url = Uri.parse('$baseUrl/active-rooms/$roomId/end-room');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $managementToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'reason': 'Live shopping session ended by host',
          'lock': false,
        }),
      );

      debugPrint("API Response Status: ${response.statusCode}");
      debugPrint("API Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('Active room ended successfully: ${responseData['message']}');
      } else if (response.statusCode == 404) {
        debugPrint('Room already inactive or not found');
        return; // Room sudah tidak aktif, tidak perlu error
      } else {
        debugPrint('Failed to end active room. Status: ${response.statusCode}');
        throw HttpException('Failed to end active room: ${response.statusCode}');
      }

    } catch (e) {
      debugPrint("Error ending active room on server: $e");
      // Tidak throw error karena ini fallback mechanism
    }
  }

  // FUNGSI TAMBAHAN: End dan lock room sebagai fallback
  Future<void> _endAndLockRoomOnServer(String roomId) async {
    try {
      debugPrint("Ending and locking room on 100ms server: $roomId");

      const String baseUrl = 'https://api.100ms.live/v2';
      const String managementToken = 'YOUR_MANAGEMENT_TOKEN_HERE'; // Ganti dengan management token Anda

      final url = Uri.parse('$baseUrl/active-rooms/$roomId/end-room');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $managementToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'reason': 'Live shopping session permanently ended',
          'lock': true, // Lock room permanently
        }),
      );

      debugPrint("Lock API Response Status: ${response.statusCode}");
      debugPrint("Lock API Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('Room ended and locked successfully: ${responseData['message']}');
      } else if (response.statusCode == 404) {
        debugPrint('Room already inactive or not found for locking');
      } else {
        debugPrint('Failed to end and lock room. Status: ${response.statusCode}');
      }

    } catch (e) {
      debugPrint("Error ending and locking room on server: $e");
    }
  }

  // FUNGSI BARU: Send end live message to all participants
  Future<void> _broadcastLiveEndMessage() async {
    try {
      if (_hmsSDK != null) {
        final endPayload = jsonEncode({
          'type': 'LIVE_ENDED',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        await _hmsSDK!.sendBroadcastMessage(message: endPayload, type: 'metadata');
        debugPrint("Broadcast live end message sent");
      }
    } catch (e) {
      debugPrint("Error broadcasting live end message: $e");
    }
  }

  // FUNGSI YANG DIPERBAIKI: Reset complete state
  Future<void> resetState() async {
    debugPrint("=== RESETTING LIVE SHOPPING STATE ===");

    try {
      // 1. Leave current room if connected
      if (_hmsSDK != null && state.isConnected) {
        debugPrint("Leaving current room...");
        await _hmsSDK!.leave();
        await Future.delayed(const Duration(milliseconds: 1500));
      }

      // 2. Reset state COMPLETELY
      if (!_disposed) {
        state = LiveShoppingState();
        debugPrint("State reset completed - isConnected: ${state.isConnected}, role: ${state.currentRole}");
      }

      // 3. Reinitialize HMS SDK
      await _initializeHMSSDK();
      debugPrint("HMS SDK reinitialized");

    } catch (e) {
      debugPrint("Error during reset: $e");
      if (!_disposed) {
        state = LiveShoppingState(error: "Reset error: $e");
      }
    }
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isNotEmpty && _hmsSDK != null) {
      _hmsSDK!.sendBroadcastMessage(message: message.trim());

      final localPeer = await _hmsSDK!.getLocalPeer();
      if (localPeer != null) {
        final localMessage = HMSMessage(
          messageId: DateTime.now().millisecondsSinceEpoch.toString(),
          message: message.trim(),
          sender: localPeer,
          time: DateTime.now(),
          type: "chat",
          hmsMessageRecipient: HMSMessageRecipient(
            hmsMessageRecipientType: HMSMessageRecipientType.BROADCAST,
            recipientPeer: null,
            recipientRoles: null,
          ),
        );
        _addMessageToState(localMessage);
      }
    }
  }

  // FUNGSI YANG DIPERBAIKI: Join room dengan session ID tracking
  Future<void> joinRoom({
    required String roomId,
    required String userId,
    required String username,
    required String role,
    String? liveTitle,
    double? initialPrice,
  }) async {
    debugPrint("=== STARTING JOIN ROOM PROCESS ===");
    debugPrint("Room ID: $roomId, User: $username, Role: $role");

    if (_disposed) {
      debugPrint("Notifier disposed, aborting join");
      return;
    }

    // Set session ID untuk tracking (untuk broadcaster gunakan userId, untuk viewer gunakan roomId)
    final sessionId = role == 'broadcaster' ? userId : roomId;

    state = state.copyWith(
      isLoading: true,
      isJoining: true,
      error: null,
      currentRole: role,
      isLiveEnded: false,
      currentItemPrice: initialPrice ?? 0.0,
      messages: [],
      roomId: roomId,
      sessionId: sessionId,
    );

    try {
      // Ensure HMS SDK is ready
      if (_hmsSDK == null) {
        await _initializeHMSSDK();
      }

      // Handle broadcaster specific setup
      if (role == 'broadcaster') {
        debugPrint("Setting up Firestore for broadcaster...");
        await _firestore.collection('live_sessions').doc(userId).set({
          'hostId': userId,
          'hostName': username,
          'roomId': roomId,
          'title': liveTitle ?? 'Live Shopping',
          'status': 'ongoing',
          'itemPrice': initialPrice ?? 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint("Firestore setup completed");
      }

      // Get token and join
      debugPrint("Getting 100ms token...");
      final token = await _apiService.get100msToken(
          roomId: roomId, userId: userId, role: role);
      debugPrint("Token received, building SDK...");

      if (_hmsSDK != null) {
        await _hmsSDK!.build();
        debugPrint("SDK built, joining room...");

        HMSConfig config = HMSConfig(authToken: token, userName: username);
        await _hmsSDK!.join(config: config);
        debugPrint("Join request sent to HMS");
      } else {
        throw Exception("HMS SDK not initialized");
      }

    } catch (e) {
      debugPrint("Error joining room: $e");
      if (!_disposed) {
        state = state.copyWith(
          isLoading: false,
          isJoining: false,
          error: e.toString(),
        );
      }
    }
  }

  void updateAndBroadcastPrice(double price) {
    state = state.copyWith(currentItemPrice: price);
    final payload = jsonEncode({
      'type': 'SET_PRICE',
      'price': price,
    });
    _hmsSDK?.sendBroadcastMessage(message: payload, type: 'metadata');
  }

  Future<void> placeOrder({
    required String sessionId,
    required String itemName,
    required String description,
    required int quantity,
    required double price,
  }) async {
    final currentUser = _ref.read(firebaseAuthProvider).currentUser;
    if (currentUser == null) throw Exception("Anda harus login untuk memesan.");

    final buyerProfile = await _firestore.collection('users').doc(currentUser.uid).get();
    final buyerName = buyerProfile.data()?['username'] ?? 'Pembeli Anonim';

    final orderData = {
      'sessionId': sessionId,
      'hostId': sessionId,
      'buyerId': currentUser.uid,
      'buyerName': buyerName,
      'itemName': itemName,
      'description': description,
      'quantity': quantity,
      'pricePerItem': price,
      'totalPrice': price * quantity,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      final newOrder = await _firestore.collection('orders').add(orderData);
      await _firestore
          .collection('live_sessions')
          .doc(sessionId)
          .collection('orders')
          .doc(newOrder.id)
          .set(orderData);
    } catch (e) {
      debugPrint("Gagal membuat pesanan: $e");
      throw Exception("Gagal mengirim pesanan. Coba lagi.");
    }
  }

  Future<void> processOrder({
    required String sessionId,
    required String orderId,
    required String newStatus,
  }) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({'status': newStatus});
      await _firestore
          .collection('live_sessions')
          .doc(sessionId)
          .collection('orders')
          .doc(orderId)
          .delete();
    } catch (e) {
      debugPrint("Gagal memproses pesanan: $e");
      throw Exception('Gagal memproses pesanan. Coba lagi.');
    }
  }

  // PERBAIKAN: Method session store yang benar untuk HMS SDK
  Future<void> _endSessionViaSessionStore() async {
    try {
      if (_hmsSDK != null) {
        // HMS SDK menggunakan HMSSessionStore, bukan getSessionMetadata()
        debugPrint("Attempting to set session ended flag...");

        // Kirim metadata message untuk session ended
        final endPayload = jsonEncode({
          'type': 'SESSION_ENDED',
          'endedBy': 'host',
          'timestamp': DateTime.now().millisecondsSinceEpoch
        });

        await _hmsSDK!.sendBroadcastMessage(message: endPayload, type: 'metadata');
        debugPrint("Session ended metadata sent");
      }
    } catch (e) {
      debugPrint("Error ending session via session store: $e");
    }
  }

  // SOLUSI TAMBAHAN: Menggunakan direct message untuk force disconnect
  Future<void> _forceDisconnectAllPeers() async {

    try {

      if (_hmsSDK != null) {

        final room = await _hmsSDK!.getRoom();

        if (room != null && room.peers != null) {

          for (var peer in room.peers!) {

            if (!peer.isLocal && peer.role?.name != 'broadcaster') {

              try {

                await _hmsSDK!.sendDirectMessage(

                  message: jsonEncode({'type': 'FORCE_DISCONNECT'}),

                  peerTo: peer,

                );

              } catch (e) {

                debugPrint("Error sending direct message to ${peer.name}: $e");

              }

            }
          }
          debugPrint("Force disconnect messages sent to all peers");
        }
      }
    } catch (e) {
      debugPrint("Error force disconnecting peers: $e");
    }
  }

  // FUNGSI YANG DIPERBAIKI: Leave room dengan multiple cleanup methods
  Future<void> leaveRoom() async {
    debugPrint("=== LEAVING ROOM ===");
    debugPrint("Current role: ${state.currentRole}");
    debugPrint("Current room ID: ${state.roomId}");
    debugPrint("Current session ID: ${state.sessionId}");

    final userIsBroadcaster = state.currentRole == 'broadcaster';
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final roomId = state.roomId;

    try {
      // STEP 1: Jika broadcaster, lakukan multiple cleanup methods
      if (userIsBroadcaster && roomId != null) {
        debugPrint("Broadcasting live end message to all participants...");
        await _broadcastLiveEndMessage();

        // TAMBAHAN: Coba multiple methods untuk memastikan room benar-benar end
        debugPrint("Attempting session store cleanup...");
        await _endSessionViaSessionStore();

        debugPrint("Force disconnecting all peers...");
        await _forceDisconnectAllPeers();

        // Tunggu sebentar agar message terkirim
        await Future.delayed(const Duration(milliseconds: 2000));

        debugPrint("Ending active room on 100ms server...");
        await _endActiveRoomOnServer(roomId);
      }

      // STEP 2: Leave HMS room
      if (_hmsSDK != null) {
        debugPrint("Leaving HMS room...");
        await _hmsSDK!.leave();
        debugPrint("Left HMS room successfully");

        // TAMBAHAN: Tunggu sebentar setelah leave
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      // STEP 3: Update Firestore status
      if (userIsBroadcaster && userId != null) {
        debugPrint("Updating Firestore status...");
        await _firestore.collection('live_sessions').doc(userId).update({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
        }).catchError((e) => debugPrint("Gagal update status live: $e"));
      }

      // STEP 4: TAMBAHAN - Jika masih ada active session, coba end via different method
      if (userIsBroadcaster && roomId != null) {
        debugPrint("Double checking - attempting alternative end room...");
        await Future.delayed(const Duration(milliseconds: 2000));
        try {
          await _endAndLockRoomOnServer(roomId); // Method alternatif dengan lock=true
        } catch (e) {
          debugPrint("Alternative end room failed: $e");
        }
      }

    } catch (e) {
      debugPrint("Error during leave process: $e");
    }

    // STEP 5: Reset state
    await resetState();
  }

  @override
  void onMessage({required HMSMessage message}) {
    if (_disposed) return;

    if (message.type == 'chat') {
      _addMessageToState(message);
    } else if (message.type == 'metadata') {
      try {
        final data = jsonDecode(message.message);
        if (data['type'] == 'SET_PRICE') {
          final newPrice = (data['price'] as num).toDouble();
          state = state.copyWith(currentItemPrice: newPrice);
        } else if (data['type'] == 'LIVE_ENDED') {
          // PERBAIKAN: Handle live end message dari broadcaster
          debugPrint("Received live end message from broadcaster");
          if (state.currentRole != 'broadcaster') {
            state = state.copyWith(isLiveEnded: true);
          }
        }
      } catch (e) {
        debugPrint("Gagal memproses pesan data: $e");
      }
    }

    // TAMBAHAN: Handle direct messages untuk force disconnect
    if (message.hmsMessageRecipient?.hmsMessageRecipientType == HMSMessageRecipientType.DIRECT) {
      try {
        final data = jsonDecode(message.message);
        if (data['type'] == 'FORCE_DISCONNECT') {
          debugPrint("Received force disconnect message from broadcaster");
          if (state.currentRole != 'broadcaster') {
            state = state.copyWith(isLiveEnded: true);
          }
        }
      } catch (e) {
        debugPrint("Error handling direct message: $e");
      }
    }
  }

  void _addMessageToState(HMSMessage message) {
    if (_disposed) return;

    final currentMessages = List<HMSMessage>.from(state.messages);
    currentMessages.add(message);
    state = state.copyWith(messages: currentMessages);
  }

  @override
  void onJoin({required HMSRoom room}) {
    debugPrint("=== ON JOIN CALLBACK ===");
    debugPrint("Room name: ${room.name}");
    debugPrint("Room ID: ${room.id}");
    debugPrint("Peers count: ${room.peers?.length ?? 0}");

    if (_disposed) {
      debugPrint("Notifier disposed, ignoring onJoin");
      return;
    }

    // Update state to connected
    state = state.copyWith(
      isLoading: false,
      isConnected: true,
      isJoining: false,
    );

    debugPrint("State updated - isConnected: ${state.isConnected}, role: ${state.currentRole}");

    // Handle peers and tracks
    if (room.peers != null) {
      for (var peer in room.peers!) {
        if (!peer.isLocal) {
          final videoTrack = peer.videoTrack;
          if (videoTrack != null && videoTrack is HMSVideoTrack) {
            state = state.copyWith(remoteVideoTrack: videoTrack, hostPeer: peer);
          }
        }
      }
    }
  }

  @override
  void onPeerUpdate({required HMSPeer peer, required HMSPeerUpdate update}) {
    debugPrint("Peer update: ${peer.name} - $update");

    if (_disposed) return;

    if (update == HMSPeerUpdate.peerLeft && !peer.isLocal) {
      // PERBAIKAN: Tambahkan pengecekan role
      if (peer.role?.name == 'broadcaster' || peer.role?.name == 'host') {
        debugPrint("Broadcaster/Host left the room");
        state = state.copyWith(isLiveEnded: true);
      }
    }
  }

  @override
  void onTrackUpdate({required HMSTrack track, required HMSTrackUpdate trackUpdate, required HMSPeer peer}) {
    debugPrint("Track update: ${track.kind} - $trackUpdate from ${peer.name}");

    if (_disposed) return;

    if (track.kind == HMSTrackKind.kHMSTrackKindVideo) {
      if (trackUpdate == HMSTrackUpdate.trackAdded) {
        if (peer.isLocal) {
          state = state.copyWith(localVideoTrack: track as HMSVideoTrack);
        } else {
          state = state.copyWith(remoteVideoTrack: track as HMSVideoTrack, hostPeer: peer);
        }
      } else if (trackUpdate == HMSTrackUpdate.trackRemoved) {
        if (peer.isLocal) {
          state = state.copyWith(localVideoTrack: null);
        } else {
          // PERBAIKAN: Hanya set live ended jika track dari broadcaster/host
          if (peer.role?.name == 'broadcaster' || peer.role?.name == 'host') {
            state = state.copyWith(remoteVideoTrack: null, isLiveEnded: true, hostPeer: null);
          }
        }
      }
    }
  }

  @override
  void onHMSError({required HMSException error}) {
    debugPrint("=== HMS ERROR ===");
    debugPrint("Code: ${error.code}");
    debugPrint("Message: ${error.message}");
    debugPrint("Description: ${error.description}");

    if (_disposed) return;

    state = state.copyWith(
      isLoading: false,
      isJoining: false,
      error: "HMS Error (${error.code}): ${error.message}",
    );
  }

  @override
  void onChangeTrackStateRequest({required HMSTrackChangeRequest hmsTrackChangeRequest}) {}
  @override
  void onReconnected() {}
  @override
  void onReconnecting() {}
  @override
  void onRemovedFromRoom({required HMSPeerRemovedFromPeer hmsPeerRemovedFromPeer}) {
    // PERBAIKAN: Handle removed from room
    debugPrint("Removed from room: ${hmsPeerRemovedFromPeer.reason}");
    if (!_disposed) {
      state = state.copyWith(isLiveEnded: true);
    }
  }
  @override
  void onRoleChangeRequest({required HMSRoleChangeRequest roleChangeRequest}) {}
  @override
  void onUpdateSpeakers({required List<HMSSpeaker> updateSpeakers}) {}
  @override
  void onSessionStoreAvailable({HMSSessionStore? hmsSessionStore}) {}
  @override
  void onPeerListUpdate({required List<HMSPeer> addedPeers, required List<HMSPeer> removedPeers}) {}
  @override
  void onRoomUpdate({required HMSRoom room, required HMSRoomUpdate update}) {
    // PERBAIKAN: Handle room update
    debugPrint("Room update: $update");
    if (update == HMSRoomUpdate.roomPeerCountUpdated) {
      debugPrint("Peer count updated: ${room.peerCount}");
    }
  }
  @override
  void onAudioDeviceChanged({HMSAudioDevice? currentAudioDevice, List<HMSAudioDevice>? availableAudioDevice}) {}

  @override
  void dispose() {
    debugPrint("=== DISPOSING LIVE SHOPPING NOTIFIER ===");
    _disposed = true;

    try {
      _hmsSDK?.removeUpdateListener(listener: this);
      _hmsSDK?.leave().catchError((e) => debugPrint("Error leaving during dispose: $e"));
    } catch (e) {
      debugPrint("Error disposing HMS SDK: $e");
    }

    super.dispose();
  }
}

final liveShoppingProvider =
StateNotifierProvider.autoDispose<LiveShoppingNotifier, LiveShoppingState>((ref) {
  final notifier = LiveShoppingNotifier(ref);

  // Auto-initialize HMS SDK
  notifier._initializeHMSSDK();

  return notifier;
});

final liveSessionsStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) {
  return FirebaseFirestore.instance
      .collection('live_sessions')
      .where('status', isEqualTo: 'ongoing')
      .orderBy('createdAt', descending: true)
      .snapshots();
});

final liveOrdersStreamProvider = StreamProvider.autoDispose.family<QuerySnapshot, String>((ref, sessionId) {
  return FirebaseFirestore.instance
      .collection('live_sessions')
      .doc(sessionId)
      .collection('orders')
      .orderBy('timestamp', descending: true)
      .snapshots();
});