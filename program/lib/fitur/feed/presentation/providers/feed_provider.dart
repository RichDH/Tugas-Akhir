import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../post/domain/entities/post.dart';
import '../../../post/presentation/providers/post_provider.dart';

// ✅ GUNAKAN POSTS PROVIDER YANG SUDAH ADA
final feedProvider = Provider<AsyncValue<List<Post>>>((ref) {
  return ref.watch(postsProvider);
});
