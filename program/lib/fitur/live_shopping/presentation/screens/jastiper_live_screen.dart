import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:program/fitur/live_shopping/presentation/providers/live_shopping_provider.dart';

class JastiperLiveScreen extends ConsumerWidget {
  const JastiperLiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HMSVideoTrack? localVideoTrack =
    ref.watch(liveShoppingProvider.select((state) => state.localVideoTrack));

    void handleLeave() {
      ref.read(liveShoppingProvider.notifier).leaveRoom();
      context.go('/feed');
    }

    // PERBAIKAN FINAL: Menggunakan PopScope dengan onPopInvokedWithResult
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        handleLeave();
      },
      child: Scaffold(
        body: localVideoTrack != null
            ? HMSVideoView(track: localVideoTrack, matchParent: true)
            : const Center(child: CircularProgressIndicator()),
        floatingActionButton: FloatingActionButton(
          onPressed: handleLeave,
          child: const Icon(Icons.call_end),
          backgroundColor: Colors.red,
        ),
      ),
    );
  }
}