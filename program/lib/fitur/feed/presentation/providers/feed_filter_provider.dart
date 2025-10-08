import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/fitur/feed/domain/entities/feed_filter.dart';

class FeedFilterNotifier extends StateNotifier<FeedFilter> {
  FeedFilterNotifier() : super(FeedFilter.all);

  void setFilter(FeedFilter filter) {
    state = filter;
  }
}

final feedFilterProvider = StateNotifierProvider<FeedFilterNotifier, FeedFilter>((ref) {
  return FeedFilterNotifier();
});