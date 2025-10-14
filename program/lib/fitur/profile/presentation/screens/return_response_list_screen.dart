// File: lib/fitur/profile/presentation/screens/return_response_list_screen.dart - PERBAIKAN AUTH
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/jualbeli/domain/entities/return_request_entity.dart';
import 'package:program/fitur/jualbeli/presentation/providers/return_request_provider.dart';

// ✅ SAFE PROVIDER UNTUK RETURN REQUESTS BY SELLER - MIRIP TRANSACTION HISTORY
final safeReturnRequestsBySellerProvider = StreamProvider.family<List<ReturnRequest>, String>((ref, sellerId) {
  final authState = ref.watch(authStateChangesProvider);

  return authState.when(
    loading: () => Stream.value([]),
    error: (error, _) => Stream.error(error),
    data: (user) {
      if (user == null) {
        return Stream.error('User not authenticated');
      }

      if (user.uid != sellerId) {
        return Stream.error('User ID mismatch');
      }

      final notifier = ref.watch(returnRequestProvider.notifier);
      return notifier.getReturnRequestsBySeller(sellerId)
          .where((requests) => requests.where((r) => 
              r.status == ReturnStatus.awaitingSellerResponse // ✅ HANYA YANG SUDAH DISETUJUI ADMIN
          ).toList().isNotEmpty)
          .map((requests) => requests.where((r) => 
              r.status == ReturnStatus.awaitingSellerResponse
          ).toList());
    },
  );
});

class ReturnResponseListScreen extends ConsumerWidget {
  const ReturnResponseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Retur yang Perlu Direspons')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Retur yang Perlu Direspons')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Auth Error: $error'),
              ElevatedButton(
                onPressed: () => ref.invalidate(authStateChangesProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Retur yang Perlu Direspons')),
            body: const Center(
              child: Text('Silakan login terlebih dahulu'),
            ),
          );
        }

        return _buildAuthenticatedContent(context, ref, user.uid);
      },
    );
  }

  Widget _buildAuthenticatedContent(BuildContext context, WidgetRef ref, String userId) {
    final returnRequestsAsync = ref.watch(safeReturnRequestsBySellerProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Retur yang Perlu Direspons'),
        backgroundColor: Colors.orange.shade50,
      ),
      body: returnRequestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_return,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tidak ada retur yang perlu direspons.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Retur akan muncul di sini setelah disetujui oleh admin.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(safeReturnRequestsBySellerProvider);
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return _ReturnResponseItem(request: request);
              },
            ),
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Memuat daftar retur...'),
            ],
          ),
        ),
        error: (err, stack) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Terjadi kesalahan:',
                    style: TextStyle(fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 8),
                Text(
                    err.toString().contains('permission-denied')
                        ? 'Sesi login bermasalah. Silakan logout dan login ulang.'
                        : err.toString(),
                    textAlign: TextAlign.center
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(authStateChangesProvider);
                    ref.invalidate(safeReturnRequestsBySellerProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReturnResponseItem extends ConsumerWidget {
  final ReturnRequest request;

  const _ReturnResponseItem({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buyerNameAsync = ref.watch(userNameProvider(request.buyerId));
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ID Retur: ${request.id.substring(0, 8)}...',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pending_actions,
                        size: 14,
                        color: Colors.orange,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Perlu Respons',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),

            // ✅ BUYER INFO
            buyerNameAsync.when(
              data: (name) => Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('Pembeli: ${name ?? 'Unknown'}'),
                ],
              ),
              loading: () => const Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('Memuat...'),
                ],
              ),
              error: (err, stack) => Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('Pembeli: ${request.buyerId.substring(0, 8)}...'),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ✅ DATE
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Dibuat: ${DateFormat('dd MMM yyyy, HH:mm').format(request.createdAt.toDate())}',
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(),

            // ✅ ALASAN RETUR
            Text(
              'Alasan Retur:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              request.reason,
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.black87,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            // ✅ EVIDENCE PREVIEW
            if (request.evidenceUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Foto Bukti:',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Container(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: request.evidenceUrls.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          request.evidenceUrls[index],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[300],
                              child: const Icon(Icons.error, color: Colors.grey),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ✅ BUTTON RESPON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push('/return-response/${request.id}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.reply, size: 18),
                label: const Text(
                  'Respon Retur',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}