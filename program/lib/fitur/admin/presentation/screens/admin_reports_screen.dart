import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:program/fitur/admin/presentation/providers/admin_report_provider.dart';
import 'package:program/fitur/admin/presentation/widgets/admin_drawer.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final defaultRange = DateTimeRange(
      start: now.subtract(const Duration(days: 7)),
      end: now,
    );

    // Set initial date range
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reportDateRangeProvider.notifier).state = defaultRange;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateRange = ref.watch(reportDateRangeProvider);
    final totalUsers = ref.watch(adminTotalUsersProvider);
    final verifiedUsers = ref.watch(adminVerifiedUsersProvider);
    final totalTransactions = ref.watch(adminTotalTransactionsProvider);
    final completedTransactions = ref.watch(adminCompletedTransactionsProvider);
    final totalRevenue = ref.watch(adminTotalRevenueProvider);

    final df = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Laporan'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2023, 1, 1),
                lastDate: DateTime.now(),
                initialDateRange: dateRange,
              );
              if (picked != null) {
                ref.read(reportDateRangeProvider.notifier).state = picked;
              }
            },
            icon: const Icon(Icons.date_range),
          ),
        ],
      ),
      drawer: const AdminDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header periode
            Card(
              color: Colors.indigo.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.indigo.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dateRange != null
                            ? 'Periode: ${df.format(dateRange.start)} - ${df.format(dateRange.end)}'
                            : 'Pilih periode untuk melihat laporan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Metrics Grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _buildMetricCard(
                    'Total Pengguna',
                    totalUsers,
                    Icons.people,
                    Colors.blue,
                  ),
                  _buildMetricCard(
                    'Pengguna Terverifikasi',
                    verifiedUsers,
                    Icons.verified_user,
                    Colors.green,
                  ),
                  _buildMetricCard(
                    'Total Transaksi',
                    totalTransactions,
                    Icons.receipt_long,
                    Colors.orange,
                  ),
                  _buildMetricCard(
                    'Transaksi Selesai',
                    completedTransactions,
                    Icons.check_circle,
                    Colors.teal,
                  ),
                ],
              ),
            ),

            // Revenue Card (full width)
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: totalRevenue.when(
                  data: (revenue) => Row(
                    children: [
                      Icon(Icons.monetization_on, color: Colors.green.shade700, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Revenue (Selesai)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.green.shade700,
                              ),
                            ),
                            Text(
                              NumberFormat.currency(
                                locale: 'id_ID',
                                symbol: 'Rp ',
                                decimalDigits: 0,
                              ).format(revenue),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  loading: () => const Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 12),
                      Text('Menghitung revenue...'),
                    ],
                  ),
                  error: (e, s) => Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 12),
                      Text('Error: ${e.toString().substring(0, 30)}...'),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Export PDF Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _exportPdf(context, ref),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
      String title,
      AsyncValue<int> valueAsync,
      IconData icon,
      Color color,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            valueAsync.when(
              data: (value) => Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, s) => Text(
                'Error',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf(BuildContext context, WidgetRef ref) async {
    try {
      // Ambil data saat ini dari provider
      final users = ref.read(adminTotalUsersProvider).value ?? 0;
      final verifiedUsers = ref.read(adminVerifiedUsersProvider).value ?? 0;
      final transactions = ref.read(adminTotalTransactionsProvider).value ?? 0;
      final completedTx = ref.read(adminCompletedTransactionsProvider).value ?? 0;
      final revenue = ref.read(adminTotalRevenueProvider).value ?? 0.0;
      final dateRange = ref.read(reportDateRangeProvider);

      final pdf = pw.Document();
      final df = DateFormat('dd MMM yyyy');

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Laporan Admin Dashboard',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                dateRange != null
                    ? 'Periode: ${df.format(dateRange.start)} - ${df.format(dateRange.end)}'
                    : 'Laporan Real-time',
              ),
              pw.SizedBox(height: 24),

              _pdfMetricRow('Total Pengguna', users.toString()),
              _pdfMetricRow('Pengguna Terverifikasi', verifiedUsers.toString()),
              _pdfMetricRow('Total Transaksi', transactions.toString()),
              _pdfMetricRow('Transaksi Selesai', completedTx.toString()),
              _pdfMetricRow('Total Revenue', NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(revenue)),

              pw.Spacer(),
              pw.Divider(),
              pw.Text(
                'Dibuat pada: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF berhasil dibuat'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print('❌ PDF export error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  pw.Widget _pdfMetricRow(String title, String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
