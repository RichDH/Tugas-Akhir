import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:program/fitur/jualbeli/domain/entities/transaction_entity.dart';

class TransactionPdfGenerator {
  static Future<File> generateTransactionReport({
    required List<Transaction> transactions,
    required Map<String, String?> buyerNames,
    required Map<String, String?> sellerNames,
    required Map<String, bool> hasActiveReturns,
    String? filterTitle,
  }) async {
    final pdf = pw.Document();
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormatter = DateFormat('dd MMM yyyy, HH:mm');
    final now = DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now());

    // Load font untuk bahasa Indonesia
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    // Hitung total
    final totalAmount = transactions.fold<double>(
      0,
          (sum, tx) => sum + tx.amount,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            // Header
            pw.Container(
              alignment: pw.Alignment.center,
              child: pw.Column(
                children: [
                  pw.Text(
                    'LAPORAN TRANSAKSI',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Aplikasi Jastip',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
                  if (filterTitle != null) ...[
                    pw.SizedBox(height: 8),
                    pw.Text(
                      filterTitle,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 12,
                        color: PdfColors.blue,
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Digenerate pada: $now',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem(
                    'Total Transaksi',
                    transactions.length.toString(),
                    font,
                    fontBold,
                  ),
                  _buildSummaryItem(
                    'Total Nilai',
                    formatter.format(totalAmount),
                    font,
                    fontBold,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FixedColumnWidth(35),
                1: const pw.FixedColumnWidth(70),
                2: const pw.FixedColumnWidth(80),
                3: const pw.FixedColumnWidth(80),
                4: const pw.FixedColumnWidth(90),
                5: const pw.FixedColumnWidth(100),
                6: const pw.FixedColumnWidth(80),
                7: const pw.FlexColumnWidth(),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.blue,
                  ),
                  children: [
                    _buildTableHeader('No', font),
                    _buildTableHeader('ID', font),
                    _buildTableHeader('Pembeli', font),
                    _buildTableHeader('Jastiper', font),
                    _buildTableHeader('Total', font),
                    _buildTableHeader('Tanggal', font),
                    _buildTableHeader('Status', font),
                    _buildTableHeader('Alamat', font),
                  ],
                ),
                // Data rows
                ...transactions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final tx = entry.value;
                  final buyerName = buyerNames[tx.buyerId] ?? 'unknown';
                  final sellerName = sellerNames[tx.sellerId] ?? 'unknown';
                  final hasReturn = hasActiveReturns[tx.id] ?? false;
                  final statusText = _getStatusText(tx.status, hasReturn);

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: index % 2 == 0 ? PdfColors.white : PdfColors.grey100,
                    ),
                    children: [
                      _buildTableCell((index + 1).toString(), font),
                      _buildTableCell(tx.id.substring(0, 8), font),
                      _buildTableCell('@$buyerName', font),
                      _buildTableCell('@$sellerName', font),
                      _buildTableCell(formatter.format(tx.amount), font),
                      _buildTableCell(
                        dateFormatter.format(tx.createdAt.toDate()),
                        font,
                      ),
                      _buildTableCell(statusText, font),
                      _buildTableCell(
                        tx.buyerAddress?.isNotEmpty == true
                            ? tx.buyerAddress!
                            : '-',
                        font,
                        maxLines: 2,
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount}',
              style: pw.TextStyle(
                font: font,
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          );
        },
      ),
    );

    // Save PDF
    final output = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${output.path}/laporan_transaksi_$timestamp.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  static pw.Widget _buildSummaryItem(
      String label,
      String value,
      pw.Font font,
      pw.Font fontBold,
      ) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTableHeader(String text, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildTableCell(
      String text,
      pw.Font font, {
        int maxLines = 1,
      }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
        ),
        maxLines: maxLines,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  static String _getStatusText(TransactionStatus status, bool hasActiveReturn) {
    if (hasActiveReturn) return 'Dalam proses retur';
    switch (status) {
      case TransactionStatus.pending:
        return 'Diproses';
      case TransactionStatus.paid:
        return 'Dibayar';
      case TransactionStatus.shipped:
        return 'Dikirim';
      case TransactionStatus.delivered:
        return 'Diterima';
      case TransactionStatus.completed:
        return 'Selesai';
      case TransactionStatus.refunded:
        return 'Dibatalkan';
      default:
        return status.name;
    }
  }
}