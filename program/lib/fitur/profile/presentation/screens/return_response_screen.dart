// File: return_response_screen.dart - PERBAIKAN LENGKAP DENGAN SAFE LOADING
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/jualbeli/domain/entities/return_request_entity.dart';
import 'package:program/fitur/jualbeli/presentation/providers/return_request_provider.dart';
import 'package:program/fitur/jualbeli/presentation/providers/transaction_provider.dart';

// ✅ SAFE PROVIDER UNTUK RETURN REQUEST BY ID - DENGAN AUTH CHECK
final safeReturnRequestByIdProvider = StreamProvider.family<ReturnRequest?, String>((ref, requestId) {
  final authState = ref.watch(authStateChangesProvider);
  final firestore = ref.watch(firebaseFirestoreProvider);

  return authState.when(
    loading: () => Stream.value(null),
    error: (error, _) => Stream.error('Auth error: $error'),
    data: (user) {
      if (user == null) {
        return Stream.error('User not authenticated');
      }

      print('🔍 [SafeReturnRequestById] User: ${user.uid}, RequestId: $requestId');

      try {
        return firestore
            .collection('return_requests')
            .doc(requestId)
            .snapshots()
            .map((doc) {
          if (!doc.exists) {
            print('❌ [SafeReturnRequestById] Document $requestId not found');
            return null;
          }

          try {
            final request = ReturnRequest.fromFirestore(doc);
            print('🔍 [SafeReturnRequestById] Got request: ${request.id}, status: ${request.status}');

            // Verifikasi akses: hanya seller yang bisa akses return request mereka
            if (request.sellerId != user.uid) {
              throw Exception('Access denied: User ${user.uid} cannot access return for seller ${request.sellerId}');
            }

            return request;
          } catch (e) {
            print('❌ [SafeReturnRequestById] Error parsing doc $requestId: $e');
            throw Exception('Error parsing return request: $e');
          }
        }).handleError((error, stackTrace) {
          print('❌ [SafeReturnRequestById] Stream error: $error');
          throw error;
        });
      } catch (e) {
        print('❌ [SafeReturnRequestById] Exception setting up stream: $e');
        return Stream.error('Setup error: $e');
      }
    },
  );
});

class ReturnResponseScreen extends ConsumerWidget {
  final String requestId;

  const ReturnResponseScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print('🔍 [ReturnResponseScreen] Building screen for requestId: $requestId');

    final authState = ref.watch(authStateChangesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Respon Retur'),
        backgroundColor: Colors.red.shade50,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/return-response-list');
            }
          },
        ),
      ),
      body: authState.when(
        loading: () {
          print('🔍 [ReturnResponseScreen] Auth loading...');
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
          print('❌ [ReturnResponseScreen] Auth error: $error');
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
          print('🔍 [ReturnResponseScreen] User authenticated: ${user?.uid}');

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
    print('🔍 [ReturnResponseScreen] Building content for user: $userId');

    final requestAsync = ref.watch(safeReturnRequestByIdProvider(requestId));

    return requestAsync.when(
      data: (request) {
        print('🔍 [ReturnResponseScreen] Got return request data');

        if (request == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Retur tidak ditemukan',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'ID Retur mungkin tidak valid atau sudah dihapus.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Kembali'),
                ),
              ],
            ),
          );
        }

        if (request.status != ReturnStatus.awaitingSellerResponse) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.block,
                  size: 64,
                  color: Colors.orange[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Retur tidak bisa direspon',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Status: ${_getStatusText(request.status)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Text(
                    request.status == ReturnStatus.sellerResponded
                        ? 'Anda sudah memberikan respons untuk retur ini.'
                        : request.status == ReturnStatus.pending
                        ? 'Retur masih menunggu persetujuan admin.'
                        : 'Retur sudah diproses dan tidak bisa diubah.',
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Kembali'),
                ),
              ],
            ),
          );
        }

        return _ReturnResponseForm(request: request);
      },
      loading: () {
        print('🔍 [ReturnResponseScreen] Loading return request...');
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
        print('❌ [ReturnResponseScreen] Return request error: $err');
        print('❌ [ReturnResponseScreen] Stack: $stack');

        // Handle permission denied khusus
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
                    'Sesi login bermasalah atau Anda tidak memiliki akses ke retur ini.',
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
                              '2. Pastikan Anda adalah penjual untuk transaksi ini\n'
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
                          ref.invalidate(authStateChangesProvider);
                          ref.invalidate(safeReturnRequestByIdProvider);
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
                  ref.invalidate(safeReturnRequestByIdProvider);
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

  String _getStatusText(ReturnStatus status) {
    switch (status) {
      case ReturnStatus.pending:
        return 'Menunggu Review Admin';
      case ReturnStatus.approved:
        return 'Disetujui Admin';
      case ReturnStatus.rejected:
        return 'Ditolak Admin';
      case ReturnStatus.awaitingSellerResponse:
        return 'Menunggu Respons Jastiper';
      case ReturnStatus.sellerResponded:
        return 'Sudah Direspon Jastiper';
      case ReturnStatus.finalRejected:
        return 'Ditolak Final';
      case ReturnStatus.finalApproved:
        return 'Disetujui Final';
      default:
        return status.name;
    }
  }
}

// ✅ FORM COMPONENT YANG SUDAH DIPERBAIKI
class _ReturnResponseForm extends ConsumerStatefulWidget {
  final ReturnRequest request;

  const _ReturnResponseForm({required this.request});

  @override
  ConsumerState<_ReturnResponseForm> createState() => _ReturnResponseFormState();
}

class _ReturnResponseFormState extends ConsumerState<_ReturnResponseForm> {
  final TextEditingController _responseController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionAsync = ref.watch(transactionByIdStreamProvider(widget.request.transactionId));
    final buyerNameAsync = ref.watch(userNameProvider(widget.request.buyerId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ HEADER CARD
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.assignment_return, color: Colors.red, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ID Retur: ${widget.request.id.substring(0, 8)}...',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ✅ TRANSACTION INFO DENGAN LOADING
                  transactionAsync.when(
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
                              Text('Transaksi: ${transaction.id.substring(0, 8)}...'),
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
                    error: (err, stack) => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, size: 16, color: Colors.red),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Error memuat transaksi',
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ✅ BUYER INFO DENGAN LOADING
                  buyerNameAsync.when(
                    data: (buyerName) => Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('Pembeli: ${buyerName ?? 'Unknown'}'),
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
                        Text('Pembeli: ${widget.request.buyerId.substring(0, 8)}...'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Diajukan: ${DateFormat('dd MMM yyyy, HH:mm').format(widget.request.createdAt.toDate())}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ✅ ALASAN RETUR
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Alasan Retur dari Pembeli:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Text(
                      widget.request.reason,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ✅ EVIDENCE IMAGES
          if (widget.request.evidenceUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.photo_library, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Bukti Foto dari Pembeli:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.request.evidenceUrls.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => _showImageDialog(context, widget.request.evidenceUrls[index]),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  widget.request.evidenceUrls[index],
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
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ✅ RESPONSE FORM
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.reply, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Berikan Respons Anda:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Berikan respons yang jelas dan sopan. Admin akan meninjau respons Anda untuk keputusan final.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: _responseController,
                    decoration: const InputDecoration(
                      hintText: 'Jelaskan respons Anda terhadap retur ini...',
                      border: OutlineInputBorder(),
                      labelText: 'Respons Retur',
                      prefixIcon: Icon(Icons.message),
                      helperText: 'Minimum 10 karakter',
                    ),
                    maxLines: 4,
                    enabled: !_isSubmitting,
                  ),

                  const SizedBox(height: 20),

                  // ✅ SUBMIT BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitResponse,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Icon(Icons.send, size: 18),
                      label: Text(
                        _isSubmitting ? 'Mengirim Respons...' : 'Kirim Respons',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ✅ CANCEL BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Kembali'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ✅ WARNING INFO
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Penting untuk Diketahui:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '• Respons Anda akan dikirim ke admin untuk ditinjau\n'
                      '• Admin akan membuat keputusan final berdasarkan bukti dan respons\n'
                      '• Berikan respons yang jujur dan dapat dipertanggungjawabkan',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
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

  void _submitResponse() async {
    final response = _responseController.text.trim();

    if (response.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Respons tidak boleh kosong'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (response.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Respons minimal 10 karakter'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref.read(returnRequestProvider.notifier).respondToReturnRequest(
          widget.request.id,
          response
      );

      if (mounted) {
        Navigator.pop(context);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Respons retur berhasil dikirim ke admin!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ [ReturnResponseScreen] Error submitting response: $e');

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim respons: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
