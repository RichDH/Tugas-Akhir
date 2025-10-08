import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/fitur/jualbeli/domain/entities/transaction_history_filter.dart';

class TransactionHistoryFilterNotifier extends StateNotifier<TransactionHistoryFilter> {
  TransactionHistoryFilterNotifier() : super(TransactionHistoryFilter.all);

  void setFilter(TransactionHistoryFilter filter) {
    state = filter;
  }
}

final transactionHistoryFilterProvider = StateNotifierProvider<TransactionHistoryFilterNotifier, TransactionHistoryFilter>((ref) {
  return TransactionHistoryFilterNotifier();
});