enum TransactionHistoryFilter {
  all('Semua'),
  processing('Diproses'),
  shipped('Dikirim'),
  delivered('Selesai'),
  refunded('Dibatalkan');

  final String label;
  const TransactionHistoryFilter(this.label);
}