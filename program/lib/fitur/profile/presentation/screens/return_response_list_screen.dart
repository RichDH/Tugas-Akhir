// File: lib/fitur/profile/presentation/screens/return_response_list_screen.dart - FIX PERMISSION DENIED
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/jualbeli/domain/entities/return_request_entity.dart';
import 'package:program/fitur/jualbeli/presentation/providers/return_request_provider.dart';

// ✅ SAFE PROVIDER UNTUK RETURN REQUESTS - DENGAN AUTH CHECK YANG BENAR
final safeReturnRequestsBySellerProvider = StreamProvider.family<List<ReturnRequest>, String>((ref, sellerId) {
  final authState = ref.watch(authStateChangesProvider);
  final firestore = ref.watch(firebaseFirestoreProvider);

  return authState.when(
    loading: () => Stream.value([]),
    error: (error, _) => Stream.error('Auth error: $error'),
    data: (user) {
      if (user == null) {
        return Stream.error('User not authenticated');
      }

      if (user.uid != sellerId) {
        return Stream.error('User ID mismatch: ${user.uid} != $sellerId');
      }

      print('🔍 [SafeReturnProvider] Fetching returns for seller: $sellerId');

      try {
        return firestore
            .collection('return_requests')
            .where('sellerId', isEqualTo: sellerId)
            .where('status', isEqualTo: 'awaiting_seller_response') // ✅ HANYA YANG PERLU DIRESPON
            .orderBy('createdAt', descending: true)
            .snapshots()
            .map((snapshot) {
          print('🔍 [SafeReturnProvider] Got ${snapshot.docs.length} return requests');
          
          final requests = snapshot.docs.map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              print('🔍 [SafeReturnProvider] Processing doc ${doc.id}: status=${data['status']}');
              return ReturnRequest.fromFirestore(doc);
            } catch (e) {
              print('❌ [SafeReturnProvider] Error parsing doc ${doc.id}: $e');
              rethrow;
            }
          }).toList();
          
          print('🔍 [SafeReturnProvider] Parsed ${requests.length} requests successfully');
          return requests;
        }).handleError((error, stackTrace) {
          print('❌ [SafeReturnProvider] Stream error: $error');
          print('❌ [SafeReturnProvider] Stack: $stackTrace');
          throw error;
        });
      } catch (e) {
        print('❌ [SafeReturnProvider] Exception setting up stream: $e');
        return Stream.error('Setup error: $e');
      }
    },
  );
});

class ReturnResponseListScreen extends ConsumerWidget {
  const ReturnResponseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print('🔍 [ReturnResponseList] Building screen...');
    
    final authState = ref.watch(authStateChangesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Retur yang Perlu Diresponse'),
        backgroundColor: Colors.red.shade50,
      ),
      body: authState.when(
        loading: () {
          print('🔍 [ReturnResponseList] Auth loading...');
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
          print('❌ [ReturnResponseList] Auth error: $error');
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
          print('🔍 [ReturnResponseList] User authenticated: ${user?.uid}');
          
          if (user == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Silakan login terlebih dahulu'),
                ],
              ),
            );
          }

          return _buildAuthenticatedContent(context, ref, user.uid);
        },
      ),
    );
  }

  Widget _buildAuthenticatedContent(BuildContext context, WidgetRef ref, String userId) {
    print('🔍 [ReturnResponseList] Building content for user: $userId');
    
    final returnRequestsAsync = ref.watch(safeReturnRequestsBySellerProvider(userId));

    return returnRequestsAsync.when(
      data: (requests) {
        print('🔍 [ReturnResponseList] Got ${requests.length} return requests');
        
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_return_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Tidak ada retur yang perlu direspon.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Retur akan muncul di sini setelah admin menyetujui pengajuan retur dari pembeli.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // ✅ TAMBAHAN: DEBUG BUTTON
                ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(safeReturnRequestsBySellerProvider);
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
      loading: () {
        print('🔍 [ReturnResponseList] Loading return requests...');
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Memuat data retur...'),
            ],
          ),
        );
      },
      error: (err, stack) {
        print('❌ [ReturnResponseList] Return requests error: $err');
        print('❌ [ReturnResponseList] Stack: $stack');
        
        // ✅ HANDLE PERMISSION DENIED KHUSUS
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
                    'Sesi login bermasalah atau Firestore rules perlu diperbaiki.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: const Column(
                      children: [
                        Text(
                          'Solusi:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '1. Logout dan login ulang\n'
                          '2. Pastikan Firestore rules mengizinkan akses\n'
                          '3. Coba refresh setelah beberapa detik',
                          style: TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          // ✅ FORCE REFRESH AUTH AND PROVIDER
                          ref.invalidate(authStateChangesProvider);
                          ref.invalidate(safeReturnRequestsBySellerProvider);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Kembali'),
                      ),
                    ],
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
              const Text('Terjadi kesalahan:',
                  style: TextStyle(fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 8),
              Text(
                err.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(safeReturnRequestsBySellerProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReturnResponseItem extends ConsumerWidget {
  final ReturnRequest request;

  const _ReturnResponseItem({required this.request});

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
            // ✅ HEADER ROW
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ID Retur: ${request.id.substring(0, 8)}...',
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                      Icon(Icons.access_time, size: 14, color: Colors.orange),
                      SizedBox(width: 4),
                      Text(
                        'Menunggu Respon',
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

            const SizedBox(height: 8),

            Text(
              'Dibuat: ${DateFormat('dd/MM/yyyy HH:mm').format(request.createdAt.toDate())}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),

            // ✅ ALASAN RETUR
            const Text(
              'Alasan Retur:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                request.reason,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ),

            // ✅ EVIDENCE IMAGES
            if (request.evidenceUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Foto Bukti:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: request.evidenceUrls.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _showImageDialog(context, request.evidenceUrls[index]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            request.evidenceUrls[index],
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey[300],
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey[300],
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error, color: Colors.grey, size: 20),
                                    Text('Gagal', style: TextStyle(fontSize: 8)),
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

            const SizedBox(height: 16),

            // ✅ WARNING MESSAGE
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: const Row(
                children: [
                  Icon(Icons.access_time, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Harap respon dalam 15 menit setelah menerima notifikasi ini',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ✅ ACTION BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  print('🔍 [ReturnResponseList] Navigating to return-response/${request.id}');
                  GoRouter.of(context).push('/return-response/${request.id}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.reply, size: 18),
                label: const Text(
                  'Respon Retur',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
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
}