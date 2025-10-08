import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../jualbeli/domain/entities/return_request_entity.dart';
import '../../../jualbeli/presentation/providers/return_request_provider.dart';

class ReturnResponseScreen extends ConsumerWidget {
  final String requestId;
  const ReturnResponseScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestAsync = ref.watch(returnRequestByIdStreamProvider(requestId));

    return Scaffold(
      appBar: AppBar(title: const Text('Respon Retur')),
      body: requestAsync.when(
            data: (request) {
              if (request.status != ReturnStatus.awaitingSellerResponse) {
                return const Center(child: Text('Retur tidak valid atau sudah direspon.'));
              }

          return _ReturnResponseForm(request: request);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _ReturnResponseForm extends ConsumerWidget {
  final ReturnRequest request;
  const _ReturnResponseForm({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Alasan Retur: ${request.reason}'),
          if (request.evidenceUrls.isNotEmpty)
            Image.network(request.evidenceUrls[0], height: 200, fit: BoxFit.cover),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Respon Anda terhadap retur ini...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final response = controller.text.trim();
              if (response.isEmpty) return;

              ref.read(returnRequestProvider.notifier).respondToReturnRequest(request.id, response);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Respon retur berhasil dikirim.')));
            },
            child: const Text('Kirim Respon'),
          ),
        ],
      ),
    );
  }
}