import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:program/fitur/live_shopping/presentation/providers/live_shopping_provider.dart';

class ViewerLiveScreen extends ConsumerWidget {
  const ViewerLiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PERBAIKAN: Dengarkan status isLiveEnded dari provider
    ref.listen<LiveShoppingState>(liveShoppingProvider, (previous, next) {
      // Jika state isLiveEnded berubah menjadi true
      if (next.isLiveEnded && (previous?.isLiveEnded == false || previous == null)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Siaran langsung telah berakhir.")),
          );
          // Kembali ke halaman sebelumnya dengan aman
          if (context.canPop()) {
            context.pop();
          }
        }
      }
    });

    final hostVideoTrack =
    ref.watch(liveShoppingProvider.select((state) => state.remoteVideoTrack));

    void handleLeave() {
      ref.read(liveShoppingProvider.notifier).leaveRoom();
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/live');
      }
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        handleLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: handleLeave,
          ),
          title: const Text("Menonton Live"),
        ),
        body: hostVideoTrack != null
            ? HMSVideoView(track: hostVideoTrack)
            : const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Menunggu siaran dari Jastiper..."),
            ],
          ),
        ),
      ),
    );
  }
}