// file: feed_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/fitur/post/domain/entities/post.dart';
import 'package:program/fitur/post/domain/repositories/post_repository.dart';
import 'package:program/fitur/post/data/repositories/post_repository_impl.dart';
import 'package:program/app/providers/firebase_providers.dart';

import '../../../post/presentation/providers/post_provider.dart';

// Provider untuk stream daftar post
final postsStreamProvider = StreamProvider<List<Post>>((ref) {
  final postRepository = ref.watch(postRepositoryProvider);
  return postRepository.getPosts(); // Pastikan ini mengembalikan Stream<List<Post>>
});