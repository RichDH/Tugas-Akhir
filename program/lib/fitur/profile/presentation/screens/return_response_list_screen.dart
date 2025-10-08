import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/jualbeli/domain/entities/return_request_entity.dart';
import 'package:program/fitur/jualbeli/presentation/providers/return_request_provider.dart';

class ReturnResponseListScreen extends ConsumerWidget {
  const ReturnResponseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
    final returnRequestsAsync = ref.watch(returnRequestsBySellerStreamProvider(currentUserId));

    return Scaffold(
      appBar: AppBar(title: const Text('Retur yang Perlu Diresponse')),
      body: returnRequestsAsync.when(
            data: (requests) {
          if (requests.isEmpty) {
            return const Center(child: Text('Tidak ada retur yang perlu direspon.'));
          }
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _ReturnResponseItem(request: request);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _ReturnResponseItem extends ConsumerWidget {
  final ReturnRequest request;

  const _ReturnResponseItem({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID Retur: ${request.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Dibuat: ${DateFormat('dd/MM/yyyy HH:mm').format(request.createdAt.toDate())}'),
            const Divider(),

            // Alasan Retur
            Text('Alasan: ${request.reason}', style: const TextStyle(fontStyle: FontStyle.italic)),

            // Evidence
            if (request.evidenceUrls.isNotEmpty)
              Image.network(request.evidenceUrls[0], height: 100, fit: BoxFit.cover),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: () {
                GoRouter.of(context).push('/return-response/${request.id}');
              },
              child: const Text('Respon Retur'),
            ),
          ],
        ),
      ),
    );
  }
}