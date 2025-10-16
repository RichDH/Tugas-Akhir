// File: return_review_screen.dart - PERBAIKAN SESUAI STRUKTUR ASLI
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/jualbeli/presentation/providers/return_request_provider.dart';
import 'package:program/fitur/jualbeli/domain/entities/return_request_entity.dart';
import 'package:program/fitur/jualbeli/presentation/providers/transaction_provider.dart';

// ✅ SAFE PROVIDER UNTUK ADMIN RETURN REVIEW - PENDING REQUESTS
final safeAdminPendingReturnRequestsProvider = StreamProvider<List<ReturnRequest>>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final firestore = ref.watch(firebaseFirestoreProvider);

  return authState.when(
    loading: () => Stream.value([]),
    error: (error, _) => Stream.error('Auth error: $error'),
    data: (user) {
      if (user == null) {
        return Stream.error('User not authenticated');
      }

      print('🔍 [SafeAdminPendingReturnProvider] Admin user: ${user.uid}');

      try {
        return firestore
            .collection('return_requests')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots()
            .map((snapshot) {
          print('🔍 [SafeAdminPendingReturnProvider] Got ${snapshot.docs.length} pending requests');

          final requests = snapshot.docs.map((doc) {
            try {
              return ReturnRequest.fromFirestore(doc);
            } catch (e) {
              print('❌ [SafeAdminPendingReturnProvider] Error parsing doc ${doc.id}: $e');
              rethrow;
            }
          }).toList();

          return requests;
        });
      } catch (e) {
        print('❌ [SafeAdminPendingReturnProvider] Exception setting up stream: $e');
        return Stream.error('Setup error: $e');
      }
    },
  );
});

// ✅ SAFE PROVIDER UNTUK ADMIN RETURN FINALIZATION - RESPONDED REQUESTS
final safeAdminRespondedReturnRequestsProvider = StreamProvider<List<ReturnRequest>>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final firestore = ref.watch(firebaseFirestoreProvider);

  return authState.when(
    loading: () => Stream.value([]),
    error: (error, _) => Stream.error('Auth error: $error'),
    data: (user) {
      if (user == null) {
        return Stream.error('User not authenticated');
      }

      print('🔍 [SafeAdminRespondedReturnProvider] Admin user: ${user.uid}');

      try {
        return firestore
            .collection('return_requests')
            .where('status', isEqualTo: 'sellerResponded') // ✅ STATUS SETELAH JASTIPER RESPON
            .orderBy('createdAt', descending: true)
            .snapshots()
            .map((snapshot) {
          print('🔍 [SafeAdminRespondedReturnProvider] Got ${snapshot.docs.length} responded requests');

          final requests = snapshot.docs.map((doc) {
            try {
              return ReturnRequest.fromFirestore(doc);
            } catch (e) {
              print('❌ [SafeAdminRespondedReturnProvider] Error parsing doc ${doc.id}: $e');
              rethrow;
            }
          }).toList();

          return requests;
        });
      } catch (e) {
        print('❌ [SafeAdminRespondedReturnProvider] Exception setting up stream: $e');
        return Stream.error('Setup error: $e');
      }
    },
  );
});

class ReturnReviewScreen extends ConsumerWidget {
  const ReturnReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print('🔍 [ReturnReviewScreen] Building screen...');

    final authState = ref.watch(authStateChangesProvider);

    return DefaultTabController(
      length: 2, // ✅ DUA TAB: REVIEW & FINALISASI
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kelola Retur'),
          backgroundColor: Colors.blue.shade50,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                context.go('/admin/');
              }
            },
          ),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.rate_review),
                text: 'Review Retur',
              ),
              Tab(
                icon: Icon(Icons.gavel),
                text: 'Finalisasi',
              ),
            ],
          ),
        ),
        body: authState.when(
          loading: () {
            print('🔍 [ReturnReviewScreen] Auth loading...');
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memuat data autentikasi...'),
                ],
              ),
            );
          },
          error: (error, stack) {
            print('❌ [ReturnReviewScreen] Auth error: $error');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Terjadi kesalahan:'),
                  const SizedBox(height: 8),
                  Text('Auth Error: $error', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.invalidate(authStateChangesProvider);
                    },
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          },
          data: (user) {
            print('🔍 [ReturnReviewScreen] User authenticated: ${user?.uid}');

            if (user == null) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Silakan login sebagai admin terlebih dahulu'),
                  ],
                ),
              );
            }

            return TabBarView(
              children: [
                _buildReviewTab(context, ref), // ✅ TAB REVIEW
                _buildFinalizationTab(context, ref), // ✅ TAB FINALISASI
              ],
            );
          },
        ),
      ),
    );
  }

  // ✅ TAB REVIEW - UNTUK PENDING RETURNS
  Widget _buildReviewTab(BuildContext context, WidgetRef ref) {
    print('🔍 [ReturnReviewScreen] Building review tab...');

    final returnRequestsAsync = ref.watch(safeAdminPendingReturnRequestsProvider);

    return returnRequestsAsync.when(
      data: (requests) {
        print('🔍 [ReturnReviewScreen] Got ${requests.length} pending return requests');

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_turned_in,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Tidak ada permintaan retur yang perlu direview.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Semua retur sudah diproses.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(safeAdminPendingReturnRequestsProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Memuat ulang data retur...')),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(safeAdminPendingReturnRequestsProvider);
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _ReturnRequestCard(request: request, isFinalization: false);
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
            Text('Memuat data retur untuk review...'),
          ],
        ),
      ),
      error: (err, stack) => _buildErrorWidget(context, ref, err, () {
        ref.invalidate(safeAdminPendingReturnRequestsProvider);
      }),
    );
  }

  // ✅ TAB FINALISASI - UNTUK RESPONDED RETURNS
  Widget _buildFinalizationTab(BuildContext context, WidgetRef ref) {
    print('🔍 [ReturnReviewScreen] Building finalization tab...');

    final returnRequestsAsync = ref.watch(safeAdminRespondedReturnRequestsProvider);

    return returnRequestsAsync.when(
      data: (requests) {
        print('🔍 [ReturnReviewScreen] Got ${requests.length} responded return requests');

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.gavel,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Tidak ada retur yang perlu difinalisasi.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Retur akan muncul di sini setelah jastiper memberikan respons.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(safeAdminRespondedReturnRequestsProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Memuat ulang data finalisasi...')),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(safeAdminRespondedReturnRequestsProvider);
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _ReturnRequestCard(request: request, isFinalization: true);
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
            Text('Memuat data retur untuk finalisasi...'),
          ],
        ),
      ),
      error: (err, stack) => _buildErrorWidget(context, ref, err, () {
        ref.invalidate(safeAdminRespondedReturnRequestsProvider);
      }),
    );
  }

  Widget _buildErrorWidget(BuildContext context, WidgetRef ref, Object err, VoidCallback onRetry) {
    print('❌ [ReturnReviewScreen] Error: $err');

    if (err.toString().contains('permission-denied')) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Masalah Akses Database',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sesi login bermasalah atau hak akses admin tidak ditemukan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Terjadi kesalahan:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(err.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

// ✅ CARD COMPONENT UNTUK RETURN REQUEST - SESUAI STRUKTUR ASLI
class _ReturnRequestCard extends ConsumerWidget {
  final ReturnRequest request;
  final bool isFinalization;

  const _ReturnRequestCard({
    required this.request,
    required this.isFinalization,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFinalization ? Colors.blue.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFinalization ? Icons.gavel : Icons.pending,
                        size: 14,
                        color: isFinalization ? Colors.blue : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isFinalization ? 'Perlu Finalisasi' : 'Perlu Review',
                        style: TextStyle(
                          color: isFinalization ? Colors.blue : Colors.orange,
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

            // ✅ TRANSACTION INFO DENGAN ERROR HANDLING
            _buildTransactionInfo(ref, request.transactionId),

            const SizedBox(height: 12),

            // ✅ USER INFO DENGAN ERROR HANDLING
            _buildUserInfo(ref, request.buyerId, request.sellerId),

            const SizedBox(height: 8),

            // ✅ WAKTU PENGAJUAN
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Diajukan: ${DateFormat('dd MMM yyyy, HH:mm').format(request.createdAt.toDate())}'),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(),

            // ✅ ALASAN RETUR
            const Text(
              'Alasan Retur:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                request.reason,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
            ),

            // ✅ TAMPILKAN RESPONS JASTIPER JIKA ADA (UNTUK MODE FINALISASI)
            if (isFinalization && request.responseReason != null && request.responseReason!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Respons Jastiper:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.store, size: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        const Text(
                          'Jastiper telah merespons:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      request.responseReason!,
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (request.respondedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Direspon: ${DateFormat('dd MMM yyyy, HH:mm').format(request.respondedAt!.toDate())}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // ✅ EVIDENCE DENGAN ERROR HANDLING
            if (request.evidenceUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Bukti Pendukung:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: request.evidenceUrls.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _showImageDialog(context, request.evidenceUrls[index]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            request.evidenceUrls[index],
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 120,
                                height: 120,
                                color: Colors.grey[300],
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 120,
                                height: 120,
                                color: Colors.grey[300],
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error, color: Colors.grey),
                                    Text('Gagal memuat', style: TextStyle(fontSize: 10)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ✅ TOMBOL AKSI BERDASARKAN MODE
            if (isFinalization) ...[
              // TOMBOL FINALISASI
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showFinalRejectDialog(context, ref, request.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text(
                        'Tolak Final',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showFinalApproveDialog(context, ref, request.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text(
                        'Setujui Final',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // TOMBOL REVIEW
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(context, ref, request.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text(
                        'Tolak Retur',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showApproveDialog(context, ref, request.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text(
                        'Setujui Retur',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ✅ BUILD TRANSACTION INFO DENGAN ERROR HANDLING
// ✅ BUILD TRANSACTION INFO DENGAN ERROR HANDLING YANG LEBIH BAIK
  Widget _buildTransactionInfo(WidgetRef ref, String transactionId) {
    final transactionAsync = ref.watch(transactionByIdStreamProvider(transactionId));

    return transactionAsync.when(
      data: (transaction) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                const Text('Transaksi:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('ID ${transaction.id.substring(0, 8)}...'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.attach_money, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  'Total: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(transaction.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
      loading: () => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Text('Memuat info transaksi...'),
          ],
        ),
      ),
      error: (err, stack) {
        print('❌ [BuildTransactionInfo] Error: $err');

        // ✅ TAMPILAN ERROR YANG TIDAK MENGGANGGU - BUKAN KOTAK MERAH BESAR
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Info transaksi tidak tersedia',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'ID: ${transactionId.substring(0, 8)}...',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  // ✅ BUILD USER INFO DENGAN ERROR HANDLING
  Widget _buildUserInfo(WidgetRef ref, String buyerId, String sellerId) {
    final buyerNameAsync = ref.watch(userNameProvider(buyerId));
    final sellerNameAsync = ref.watch(userNameProvider(sellerId));

    return Row(
      children: [
        Expanded(
          child: buyerNameAsync.when(
            data: (name) => Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(child: Text('Pembeli: $name', overflow: TextOverflow.ellipsis)),
              ],
            ),
            loading: () => const Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1)),
                SizedBox(width: 4),
                Text('Memuat...'),
              ],
            ),
            error: (err, stack) => Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(child: Text('Pembeli: ${buyerId.substring(0, 8)}...', overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ),
        Expanded(
          child: sellerNameAsync.when(
            data: (name) => Row(
              children: [
                const Icon(Icons.store, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(child: Text('Jastiper: $name', overflow: TextOverflow.ellipsis)),
              ],
            ),
            loading: () => const Row(
              children: [
                Icon(Icons.store, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1)),
                SizedBox(width: 4),
                Text('Memuat...'),
              ],
            ),
            error: (err, stack) => Row(
              children: [
                const Icon(Icons.store, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(child: Text('Jastiper: ${sellerId.substring(0, 8)}...', overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Foto Bukti'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Flexible(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: Colors.red),
                        Text('Gagal memuat gambar'),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ DIALOG UNTUK REVIEW (INITIAL APPROVAL)
  void _showApproveDialog(BuildContext context, WidgetRef ref, String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Setujui Retur?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Retur akan diteruskan ke jastiper untuk direspons.'),
            SizedBox(height: 8),
            Text(
              '⏰ Jastiper akan mendapat notifikasi untuk merespons.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(returnRequestProvider.notifier).approveReturnRequest(requestId);
                _showSuccessDialog(context, 'Retur berhasil disetujui!\nDikirim ke jastiper untuk direspons.');
              } catch (e) {
                _showErrorDialog(context, 'Gagal menyetujui retur: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Ya, Setujui', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref, String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('Tolak Retur?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Retur akan ditolak dan transaksi kembali ke status diterima.'),
            SizedBox(height: 8),
            Text(
              '⚠️ Pembeli dapat menyelesaikan transaksi setelah penolakan.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(returnRequestProvider.notifier).rejectReturnRequest(requestId);
                _showSuccessDialog(context, 'Retur berhasil ditolak.\nTransaksi kembali ke status diterima.');
              } catch (e) {
                _showErrorDialog(context, 'Gagal menolak retur: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Tolak', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ✅ DIALOG UNTUK FINALISASI APPROVE - MENGGUNAKAN METHOD YANG BENAR
  void _showFinalApproveDialog(BuildContext context, WidgetRef ref, String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.gavel, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Finalisasi Retur?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Retur akan disetujui secara final.'),
            SizedBox(height: 8),
            Text(
              '💰 Dana akan dikembalikan ke pembeli dan transaksi berstatus refunded.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // ✅ MENGGUNAKAN METHOD YANG BENAR: finalizeReturn
                await ref.read(returnRequestProvider.notifier).finalizeReturn(requestId, true);
                _showSuccessDialog(context, 'Retur berhasil difinalisasi!\nDana dikembalikan ke pembeli.');
              } catch (e) {
                _showErrorDialog(context, 'Gagal memfinalisasi retur: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Ya, Setujui Final', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ✅ DIALOG UNTUK FINALISASI REJECT - MENGGUNAKAN METHOD YANG BENAR
  void _showFinalRejectDialog(BuildContext context, WidgetRef ref, String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.gavel, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('Tolak Final Retur?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Retur akan ditolak secara final.'),
            SizedBox(height: 8),
            Text(
              '⚠️ Transaksi kembali ke status diterima dan pembeli dapat menyelesaikan transaksi.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // ✅ MENGGUNAKAN METHOD YANG BENAR: finalizeReturn
                await ref.read(returnRequestProvider.notifier).finalizeReturn(requestId, false);
                _showSuccessDialog(context, 'Retur berhasil ditolak final.\nTransaksi kembali ke status diterima.');
              } catch (e) {
                _showErrorDialog(context, 'Gagal menolak final retur: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Tolak Final', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK')
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.error, color: Colors.red, size: 64),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK')
          ),
        ],
      ),
    );
  }
}
