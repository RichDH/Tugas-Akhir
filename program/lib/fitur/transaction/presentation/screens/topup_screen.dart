import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:program/fitur/transaction/presentation/providers/transaction_provider.dart';

class TopUpScreen extends ConsumerStatefulWidget {
  const TopUpScreen({super.key});

  @override
  ConsumerState<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends ConsumerState<TopUpScreen> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submitTopUp() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal top up minimal Rp 10.000')),
      );
      return;
    }

    // 1. Panggil createInvoice
    final invoiceData = await ref.read(transactionProvider.notifier).createInvoice(amount);

    if (invoiceData != null && mounted) {
      // 2. Navigasi ke WebView dan TUNGGU hingga halaman itu ditutup
      final resultFromWebView = await context.push<bool>('/webview', extra: invoiceData['invoiceUrl']);

      // 3. Setelah kembali dari WebView
      if (resultFromWebView == true && mounted) {
        // User menyelesaikan pembayaran di Xendit
        // Tampilkan loading saat memeriksa status
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Memverifikasi pembayaran...'),
                  ],
                ),
              ),
            ),
          ),
        );

        // Tunggu beberapa detik untuk webhook Xendit memproses
        await Future.delayed(const Duration(seconds: 3));

        // Cek status invoice
        final status = await ref.read(transactionProvider.notifier).checkInvoiceStatus(invoiceData['externalId']!);

        if (mounted) {
          Navigator.of(context).pop(); // Tutup dialog loading
        }

        if (status == 'PAID' && mounted) {
          // 4. Jika statusnya PAID, navigasi ke halaman sukses
          context.go('/top-up-success');
        } else if (status == 'PENDING' && mounted) {
          // Masih pending, mungkin webhook belum sampai
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Pembayaran Sedang Diproses'),
              content: const Text('Pembayaran Anda sedang diverifikasi. Saldo akan otomatis bertambah dalam beberapa menit.'),
              actions: [
                TextButton(
                  onPressed: () {
                    context.go('/profile');
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memverifikasi pembayaran. Silakan cek saldo Anda nanti.')),
          );
        }
      } else if (resultFromWebView == false && mounted) {
        // User membatalkan pembayaran
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pembayaran dibatalkan')),
        );
      }
    } else if (mounted) {
      final error = ref.read(transactionProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Terjadi kesalahan saat membuat invoice.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Top Up Saldo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nominal Top Up',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'Masukkan nominal' : null,
              ),
              const SizedBox(height: 24),
              state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _submitTopUp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Lanjutkan Pembayaran'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}