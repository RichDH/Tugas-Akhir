// File: lib/fitur/jualbeli/presentation/screens/create_return_request_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/jualbeli/presentation/providers/return_request_provider.dart';
import 'package:program/fitur/jualbeli/presentation/providers/transaction_provider.dart';
import 'package:program/fitur/jualbeli/domain/entities/transaction_entity.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:io';

class CreateReturnRequestScreen extends ConsumerStatefulWidget {
  final String transactionId;
  const CreateReturnRequestScreen({super.key, required this.transactionId});

  @override
  ConsumerState<CreateReturnRequestScreen> createState() => _CreateReturnRequestScreenState();
}

class _CreateReturnRequestScreenState extends ConsumerState<CreateReturnRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final List<File> _evidenceImages = [];
  bool _isSubmitting = false;

  late CloudinaryPublic cloudinary;
  final String _cloudinaryCloudName = "ds656gqe2";
  final String _cloudinaryUploadPreset = "ngoper_unsigned_upload";

  @override
  void initState() {
    super.initState();
    // ✅ INISIALISASI CLOUDINARY
    cloudinary = CloudinaryPublic(
        _cloudinaryCloudName, _cloudinaryUploadPreset, cache: false);
  }

    final List<String> _returnReasons = [
    'Barang tidak sesuai deskripsi',
    'Barang rusak/cacat saat diterima',
    'Barang tidak lengkap/kurang',
    'Salah barang yang dikirim',
    'Kualitas barang tidak sesuai ekspektasi',
    'Lainnya (jelaskan di keterangan)',
  ];

  String? _selectedReason;

  @override
  Widget build(BuildContext context) {
    if (widget.transactionId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('ID Transaksi tidak valid'),
            ],
          ),
        ),
      );
    }

    final transactionAsync = ref.watch(transactionByIdStreamProvider(widget.transactionId));
    final authState = ref.watch(authStateChangesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajukan Retur'),
        backgroundColor: Colors.red.shade50,
        elevation: 0,
      ),
      body: authState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          // Debug error
          print('Auth error: $error');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Auth Error: $error'),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kembali'),
                ),
              ],
            ),
          );
        },
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User tidak terautentikasi'));
          }

          return transactionAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) {
              // Debug transaction error
              print('Transaction error: $error');
              print('Transaction ID: ${widget.transactionId}');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('Gagal memuat transaksi'),
                    const SizedBox(height: 8),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Kembali'),
                    ),
                  ],
                ),
              );
            },
            data: (transaction) {
              // Debug transaction data
              print('Transaction loaded: ${transaction.id}');
              print('Transaction status: ${transaction.status}');

              // Validasi status transaksi
              if (transaction.status != TransactionStatus.delivered) {
                return _buildInvalidStatusView();
              }

              // Validasi kepemilikan transaksi
              if (transaction.buyerId != user.uid) {
                return const Center(child: Text('Anda tidak memiliki akses ke transaksi ini'));
              }

              return _buildCreateReturnForm(transaction);
            },
          );
        },
      ),
    );
  }

  Widget _buildInvalidStatusView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            const Text(
              'Retur Tidak Dapat Diajukan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Retur hanya dapat diajukan untuk transaksi yang berstatus "Diterima" (delivered)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Kembali'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateReturnForm(Transaction transaction) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTransactionInfo(transaction),
            const SizedBox(height: 24),
            _buildReturnPolicy(),
            const SizedBox(height: 24),
            _buildReasonSelection(),
            const SizedBox(height: 24),
            _buildDetailReason(),
            const SizedBox(height: 24),
            _buildEvidenceSection(),
            const SizedBox(height: 32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionInfo(Transaction transaction) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Informasi Transaksi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.receipt, 'ID Transaksi', transaction.id.substring(0, 12) + '...'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.attach_money, 'Total Pembayaran', 'Rp ${transaction.amount.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.check_circle, 'Status', 'Barang Telah Diterima'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.black87))),
      ],
    );
  }

  Widget _buildReturnPolicy() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.policy, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              Text(
                'Kebijakan Retur',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '• Retur hanya dapat diajukan dalam 7 hari setelah barang diterima\n'
                '• Barang harus dalam kondisi yang sama seperti saat diterima\n'
                '• Sertakan foto bukti yang jelas untuk mempercepat proses\n'
                '• Admin akan meninjau pengajuan retur Anda dalam 1x24 jam',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih Alasan Retur *',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: _returnReasons.map((reason) {
              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _returnReasons.indexOf(reason) == _returnReasons.length - 1
                          ? Colors.transparent
                          : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: RadioListTile<String>(
                  title: Text(reason, style: const TextStyle(fontSize: 14)),
                  value: reason,
                  groupValue: _selectedReason,
                  onChanged: (value) {
                    setState(() {
                      _selectedReason = value;
                    });
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailReason() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Keterangan Detail *',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _reasonController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Jelaskan secara detail masalah yang Anda alami dengan barang ini...\n\nContoh: Warna tidak sesuai foto, ukuran terlalu kecil, ada bagian yang rusak, dll.',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Keterangan detail wajib diisi';
            }
            if (value.trim().length < 20) {
              return 'Keterangan terlalu singkat (minimal 20 karakter)';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildEvidenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto Bukti',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          'Tambahkan foto untuk memperkuat pengajuan retur (maksimal 5 foto)',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 12),

        if (_evidenceImages.isNotEmpty) ...[
          Container(
            height: 120,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _evidenceImages.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _evidenceImages[index],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _evidenceImages.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],

        if (_evidenceImages.length < 5) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Dari Galeri'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Dari Kamera'),
                ),
              ),
            ],
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Maksimal 5 foto telah tercapai',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitReturnRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
        icon: _isSubmitting
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : const Icon(Icons.assignment_return),
        label: Text(
          _isSubmitting ? 'Mengirim...' : 'Ajukan Retur',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1080,
    );

    if (image != null) {
      setState(() {
        _evidenceImages.add(File(image.path));
      });
    }
  }

  Future<List<String>> _uploadEvidenceImages(String userId) async {
    List<String> uploadedUrls = [];
    final folderPath = "return_evidence/$userId";

    for (int i = 0; i < _evidenceImages.length; i++) {
      File file = _evidenceImages[i];

      try {
        print('Uploading evidence image ${i + 1}/${_evidenceImages.length}');

        CloudinaryResponse response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            file.path,
            folder: folderPath,
            resourceType: CloudinaryResourceType.Image,
          ),
        );

        if (response.secureUrl.isNotEmpty) {
          uploadedUrls.add(response.secureUrl);
          print('Evidence image uploaded: ${response.secureUrl}');
        } else {
          throw Exception('Upload gagal: URL kosong');
        }
      } catch (e) {
        print('Error uploading evidence image ${i + 1}: $e');
        // Tetap lanjutkan upload image lainnya
        // throw Exception('Gagal upload foto bukti ke-${i + 1}: $e');
      }
    }

    return uploadedUrls;
  }

  Future<void> _submitReturnRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih alasan retur'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = ref.read(authStateChangesProvider).value;
      if (user == null) throw Exception('User tidak terautentikasi');

      final transaction = await ref.read(transactionByIdStreamProvider(widget.transactionId).future);

      // ✅ UPLOAD EVIDENCE IMAGES KE CLOUDINARY
      List<String> evidenceUrls = [];
      if (_evidenceImages.isNotEmpty) {
        try {
          evidenceUrls = await _uploadEvidenceImages(user.uid);
          print('Successfully uploaded ${evidenceUrls.length} evidence images');
        } catch (e) {
          print('Warning: Some evidence images failed to upload: $e');
          // Lanjutkan proses meski ada gambar yang gagal upload
        }
      }

      // Gabungkan alasan yang dipilih dengan detail keterangan
      final fullReason = '$_selectedReason\n\nDetail: ${_reasonController.text.trim()}';

      // ✅ CREATE RETURN REQUEST DENGAN EVIDENCE URLS
      await ref.read(returnRequestProvider.notifier).createReturnRequest(
        transactionId: widget.transactionId,
        buyerId: user.uid,
        sellerId: transaction.sellerId,
        reason: fullReason,
        evidenceUrls: evidenceUrls, // ✅ PASS UPLOADED URLs
      );

      if (mounted) {
        // Tampilkan dialog sukses
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
            title: const Text('Retur Berhasil Diajukan'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pengajuan retur Anda telah dikirim dan akan ditinjau oleh admin dalam 1x24 jam.',
                ),
                if (evidenceUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${evidenceUrls.length} foto bukti berhasil diupload.',
                    style: TextStyle(color: Colors.green[700], fontSize: 12),
                  ),
                ],
                if (evidenceUrls.length < _evidenceImages.length) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Beberapa foto bukti gagal diupload, namun pengajuan retur tetap terkirim.',
                    style: TextStyle(color: Colors.orange[700], fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  context.pop(); // Return to previous screen
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim retur: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Tutup',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}
