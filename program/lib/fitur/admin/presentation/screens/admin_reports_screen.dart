import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:program/fitur/admin/presentation/providers/admin_report_provider.dart';
import 'package:program/fitur/admin/presentation/widgets/admin_drawer.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final monthlyReport = ref.watch(adminMonthlyReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Laporan'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          // ✅ PERBAIKAN: Tombol kalender yang bisa diklik untuk filter bulan
          IconButton(
            onPressed: () async {
              await _showMonthPicker(context, ref, selectedMonth);
            },
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Pilih Bulan',
          ),
        ],
      ),
      drawer: const AdminDrawer(),
      body: monthlyReport.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Menganalisis data bulanan...'),
            ],
          ),
        ),
        error: (e, s) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $e', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(adminMonthlyReportProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header periode dengan bulan yang dipilih
              Card(
                color: Colors.deepPurple.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.deepPurple.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Laporan: ${DateFormat('MMMM yyyy', 'id_ID').format(selectedMonth)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade700,
                          ),
                        ),
                      ),
                      // ✅ INDIKATOR BAHWA BISA DIKLIK
                      Icon(Icons.edit, color: Colors.deepPurple.shade400, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ✅ METRICS GRID DENGAN DATA USER YANG BENAR
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  _buildGrowthMetricCard(
                    'User Baru',
                    data['newUsers'].toString(),
                    data['userGrowth'],
                    Icons.person_add,
                    Colors.blue,
                    subtitle: 'Total: ${data['totalUsersAccumulated']}',
                  ),
                  _buildGrowthMetricCard(
                    'Verified Baru',
                    data['newVerifiedUsers'].toString(),
                    data['verifiedGrowth'],
                    Icons.verified_user,
                    Colors.green,
                    subtitle: 'Total: ${data['totalVerifiedAccumulated']}',
                  ),
                  _buildGrowthMetricCard(
                    'Transaksi Baru',
                    data['totalTransactions'].toString(),
                    data['transactionGrowth'],
                    Icons.receipt_long,
                    Colors.orange,
                  ),
                  _buildGrowthMetricCard(
                    'Transaksi Selesai',
                    data['completedTransactions'].toString(),
                    data['completedGrowth'],
                    Icons.check_circle,
                    Colors.teal,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Revenue Card dengan growth
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.monetization_on, color: Colors.green.shade700, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Total Transaksi Selesai',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildGrowthChip(data['revenueGrowth']),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              NumberFormat.currency(
                                locale: 'id_ID',
                                symbol: 'Rp ',
                                decimalDigits: 0,
                              ).format(data['totalRevenue']),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Export PDF Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showPdfPreview(context, data),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Preview & Download PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ MONTH PICKER DIALOG
  Future<void> _showMonthPicker(BuildContext context, WidgetRef ref, DateTime currentMonth) async {
    final now = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Bulan'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = DateTime(now.year, index + 1, 1);
              final isSelected = month.month == currentMonth.month && month.year == currentMonth.year;

              return ElevatedButton(
                onPressed: () {
                  ref.read(selectedMonthProvider.notifier).state = month;
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.deepPurple : Colors.grey.shade200,
                  foregroundColor: isSelected ? Colors.white : Colors.black87,
                ),
                child: Text(
                  DateFormat('MMM').format(month),
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  // ✅ UPDATED METRIC CARD DENGAN SUBTITLE
  Widget _buildGrowthMetricCard(
      String title,
      String value,
      double growth,
      IconData icon,
      Color color, {
        String? subtitle,
      }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildGrowthChip(growth),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Growth chip tetap sama
  Widget _buildGrowthChip(double growth) {
    final isPositive = growth > 0;
    final isZero = growth == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isZero
            ? Colors.grey.shade200
            : (isPositive ? Colors.green.shade100 : Colors.red.shade100),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isZero
            ? '0%'
            : '${isPositive ? '+' : ''}${growth.toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isZero
              ? Colors.grey.shade600
              : (isPositive ? Colors.green.shade700 : Colors.red.shade700),
        ),
      ),
    );
  }

  // ✅ PDF PREVIEW DAN DOWNLOAD
  Future<void> _showPdfPreview(BuildContext context, Map<String, dynamic> data) async {
    try {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Preview Laporan PDF'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            child: PdfPreview(
              build: (format) => _generatePdf(data),
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final bytes = await _generatePdf(data);
                await _savePdf(bytes);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
              child: const Text('Download PDF', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error preview PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ✅ GENERATE PDF DENGAN DATA LENGKAP
  Future<Uint8List> _generatePdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final selectedMonth = data['selectedMonth'] as DateTime;
    final monthYear = DateFormat('MMMM yyyy', 'id_ID').format(selectedMonth);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Header(
              level: 0,
              child: pw.Text('Laporan Admin Dashboard', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Periode: $monthYear'),
            pw.SizedBox(height: 8),
            pw.Text('Dibuat pada: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}'),
            pw.SizedBox(height: 24),

            _pdfMetricRowWithGrowth('User Baru Bulan Ini', data['newUsers'].toString(), data['userGrowth']),
            _pdfMetricRowWithGrowth('User Verified Baru', data['newVerifiedUsers'].toString(), data['verifiedGrowth']),
            _pdfMetricRowWithGrowth('Total User (Akumulatif)', data['totalUsersAccumulated'].toString(), data['userAccumulatedGrowth']),
            _pdfMetricRowWithGrowth('Total Verified (Akumulatif)', data['totalVerifiedAccumulated'].toString(), data['verifiedAccumulatedGrowth']),
            pw.SizedBox(height: 12),
            _pdfMetricRowWithGrowth('Transaksi Bulan Ini', data['totalTransactions'].toString(), data['transactionGrowth']),
            _pdfMetricRowWithGrowth('Transaksi Selesai', data['completedTransactions'].toString(), data['completedGrowth']),
            _pdfMetricRowWithGrowth(
                'Total Transaksi Selesai',
                NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(data['totalRevenue']),
                data['revenueGrowth']
            ),

            pw.Spacer(),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text('Catatan:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('• Persentase pertumbuhan dibandingkan bulan sebelumnya', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('• User Baru: registrasi dalam bulan dipilih', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('• User Verified Baru: terverifikasi dalam bulan dipilih', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('• Data akumulatif: total hingga akhir bulan dipilih', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  // PDF metric row dengan growth (sama seperti sebelumnya)
  pw.Widget _pdfMetricRowWithGrowth(String title, String value, double growth) {
    final sign = growth > 0 ? '+' : '';
    final growthText = growth == 0 ? '0%' : '$sign${growth.toStringAsFixed(1)}%';

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Pertumbuhan: $growthText', style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  // ✅ SAVE PDF (lanjutkan yang terpotong sebelumnya)
  Future<void> _savePdf(Uint8List bytes) async {
    try {
      final now = DateTime.now();
      final selectedMonth = ref.read(selectedMonthProvider);
      final filename = 'Laporan_${DateFormat('yyyy-MM').format(selectedMonth)}_${DateFormat('dd-HHmm').format(now)}.pdf';

      if (Platform.isAndroid) {
        final directory = Directory('/storage/emulated/0/Download');
        if (await directory.exists()) {
          final file = File('${directory.path}/$filename');
          await file.writeAsBytes(bytes);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PDF disimpan ke Download/$filename'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'OK',
                  onPressed: () {},
                ),
              ),
            );
          }
        } else {
          // Fallback
          final dir = await getExternalStorageDirectory();
          final file = File('${dir!.path}/$filename');
          await file.writeAsBytes(bytes);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PDF disimpan ke ${file.path}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        // iOS atau platform lain
        await Printing.sharePdf(bytes: bytes, filename: filename);
      }
    } catch (e) {
      print('❌ Save PDF error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
