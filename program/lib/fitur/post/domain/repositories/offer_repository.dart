import 'package:program/fitur/post/domain/entities/offer.dart';

abstract class OfferRepository {
  Future<void> createOffer(Offer offer);
  Future<void> acceptOffer(String offerId);
  Future<void> rejectOffer(String offerId, String reason);
  Stream<List<Offer>> getOffersByPost(String postId);
  Stream<List<Offer>> getOffersByOfferer(String offererId);
  Stream<List<Offer>> getOffersByPostOwner(String postOwnerId);
  Future<void> updatePostOfferCount(String postId, int newCount);
}
