// File: lib/fitur/post/presentation/providers/offer_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/post/data/repositories/offer_repository_impl.dart';
import 'package:program/fitur/post/domain/repositories/offer_repository.dart';
import 'package:program/fitur/post/domain/entities/offer.dart';
import 'package:program/fitur/jualbeli/presentation/providers/transaction_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/exception/balance_exception.dart';
import '../../../jualbeli/domain/entities/transaction_entity.dart' as domain;

final offerRepositoryProvider = Provider<OfferRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return OfferRepositoryImpl(firestore);
});

class OfferNotifier extends StateNotifier<AsyncValue<void>> {
  final OfferRepository _repository;
  final Ref _ref;

  OfferNotifier(this._repository, this._ref) : super(const AsyncData(null));

  Future<void> createOffer({
    required String postId,
    required String postTitle,
    required String offererId,
    required String offererUsername,
    required String postOwnerId,
    required double offerPrice,
  }) async {
    state = const AsyncLoading();
    try {
      final offer = Offer(
        id: '',
        postId: postId,
        postTitle: postTitle,
        offererId: offererId,
        offererUsername: offererUsername,
        postOwnerId: postOwnerId,
        offerPrice: offerPrice,
        createdAt: Timestamp.now(),
      );

      await _repository.createOffer(offer);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }


  Future<void> acceptOfferAndCreateTransaction({
    required String offerId,
    required Offer offer,
    required int quantity,
  }) async {
    state = const AsyncLoading();
    try {
      final firestore = _ref.read(firebaseFirestoreProvider);

      final buyerId = offer.postOwnerId;
      final sellerId = offer.offererId;
      final totalAmount = offer.offerPrice * quantity;

      // 1) ✅ AMBIL DATA POST LENGKAP (UNTUK ITEMS)
      final postDoc = await firestore.collection('posts').doc(offer.postId).get();
      if (!postDoc.exists) {
        throw Exception('Data post tidak ditemukan');
      }
      final postData = postDoc.data() as Map<String, dynamic>;
      final imageUrls = List<String>.from(postData['imageUrls'] ?? []);

      // 2) ✅ AMBIL DATA BUYER LENGKAP (SALDO & ALAMAT)
      final buyerDoc = await firestore.collection('users').doc(buyerId).get();
      if (!buyerDoc.exists) {
        throw Exception('Data pembeli tidak ditemukan');
      }
      final buyerData = buyerDoc.data() as Map<String, dynamic>;
      final buyerBalance = (buyerData['saldo'] as num?)?.toDouble() ?? 0.0;

      final alamat = buyerData['alamat'] as String?;
      final buyerAddress = (alamat != null && alamat.trim().isNotEmpty)
          ? alamat.trim()
          : 'Alamat tidak tersedia';


      // 3) ✅ CEK SALDO
      if (buyerBalance < totalAmount) {
        throw InsufficientBalanceException(
          required: totalAmount,
          available: buyerBalance,
        );
      }

      // 4) ✅ POTONG SALDO
      await firestore.collection('users').doc(buyerId).update({
        'saldo': FieldValue.increment(-totalAmount),
      });

      try {
        // 5) ✅ BUAT TRANSAKSI DENGAN STRUKTUR SAMA SEPERTI "BELI LANGSUNG"
        await firestore.collection('transactions').add({
          'postId': offer.postId,
          'buyerId': buyerId,
          'sellerId': sellerId,
          'amount': totalAmount,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(), // ✅ GUNAKAN serverTimestamp
          'buyerAddress': buyerAddress,
          'items': [
            {
              'postId': offer.postId,
              'title': offer.postTitle,
              'price': offer.offerPrice, // ✅ HARGA SESUAI OFFER, BUKAN POST
              'quantity': quantity,
              'imageUrl': imageUrls.isNotEmpty ? imageUrls[0] : '', // ✅ AMBIL GAMBAR DARI POST
            }
          ],
          'isEscrow': true,
          'escrowAmount': totalAmount,
          'isAcceptedBySeller': false,
          'type': 'offer_accept', // ✅ PENANDA DARI OFFER
        });

        // 6) ✅ BARU SEKARANG ACCEPT OFFER (SETELAH TRANSAKSI BERHASIL)
        await _repository.acceptOffer(offerId);

        state = const AsyncData(null);
      } catch (e) {
        // 7) ✅ ROLLBACK SALDO JIKA TRANSAKSI GAGAL
        await firestore.collection('users').doc(buyerId).update({
          'saldo': FieldValue.increment(totalAmount),
        });
        rethrow;
      }
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }



  Future<void> rejectOffer(String offerId, String reason) async {
    state = const AsyncLoading();
    try {
      await _repository.rejectOffer(offerId, reason);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }
}

final offerProvider = StateNotifierProvider<OfferNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(offerRepositoryProvider);
  return OfferNotifier(repository, ref);
});

// ✅ PERBAIKAN STREAM PROVIDERS - GUNAKAN AUTOAUTODIPOSE
final offersByPostProvider = StreamProvider.autoDispose.family<List<Offer>, String>((ref, postId) {
  final repository = ref.watch(offerRepositoryProvider);
  return repository.getOffersByPost(postId);
});

final offersByOffererProvider = StreamProvider.autoDispose.family<List<Offer>, String>((ref, offererId) {
  final repository = ref.watch(offerRepositoryProvider);
  return repository.getOffersByOfferer(offererId);
});

final offersByPostOwnerProvider = StreamProvider.autoDispose.family<List<Offer>, String>((ref, postOwnerId) {
  final repository = ref.watch(offerRepositoryProvider);
  return repository.getOffersByPostOwner(postOwnerId);
});
