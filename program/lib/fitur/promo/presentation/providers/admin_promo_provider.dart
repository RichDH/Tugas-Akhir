import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/promo/data/repositories/promo_repository.dart';
import 'package:program/fitur/promo/domain/entities/promo.dart';

// Repository provider
final promoRepositoryProvider = Provider<PromoRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return PromoRepository(firestore);
});

// Stream semua promo untuk admin
final allPromosProvider = StreamProvider<List<Promo>>((ref) {
  final repository = ref.watch(promoRepositoryProvider);
  return repository.getAllPromos();
});

// Stream promo aktif untuk user
final activePromosProvider = StreamProvider<List<Promo>>((ref) {
  final repository = ref.watch(promoRepositoryProvider);
  return repository.getActivePromos();
});

// State untuk create/update promo
class PromoFormState {
  final bool isLoading;
  final String? error;
  final bool success;

  const PromoFormState({
    this.isLoading = false,
    this.error,
    this.success = false,
  });

  PromoFormState copyWith({
    bool? isLoading,
    String? error,
    bool? success,
  }) {
    return PromoFormState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      success: success ?? this.success,
    );
  }
}

// Notifier untuk manage promo actions
class AdminPromoNotifier extends StateNotifier<PromoFormState> {
  final PromoRepository _repository;
  final Ref _ref;

  AdminPromoNotifier(this._repository, this._ref) : super(const PromoFormState());

  Future<void> createPromo(Promo promo) async {
    state = state.copyWith(isLoading: true, error: null, success: false);
    try {
      await _repository.createPromo(promo);
      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updatePromo(Promo promo) async {
    state = state.copyWith(isLoading: true, error: null, success: false);
    try {
      await _repository.updatePromo(promo);
      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> togglePromoStatus(String promoId, bool isActive) async {
    try {
      await _repository.togglePromoStatus(promoId, isActive);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deletePromo(String promoId) async {
    try {
      await _repository.deletePromo(promoId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearState() {
    state = const PromoFormState();
  }
}

final adminPromoProvider = StateNotifierProvider<AdminPromoNotifier, PromoFormState>((ref) {
  final repository = ref.watch(promoRepositoryProvider);
  return AdminPromoNotifier(repository, ref);
});
