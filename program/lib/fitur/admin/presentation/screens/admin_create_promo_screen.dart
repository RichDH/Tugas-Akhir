import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:program/fitur/admin/presentation/widgets/admin_drawer.dart';
import 'package:program/fitur/promo/presentation/providers/admin_promo_provider.dart';
import 'package:program/fitur/promo/domain/entities/promo.dart';
import 'package:program/app/providers/firebase_providers.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

class AdminCreatePromoScreen extends ConsumerStatefulWidget {
  final String? promoId; // null untuk create, ada value untuk edit

  const AdminCreatePromoScreen({super.key, this.promoId});

  @override
  ConsumerState<AdminCreatePromoScreen> createState() => _AdminCreatePromoScreenState();
}

class _AdminCreatePromoScreenState extends ConsumerState<AdminCreatePromoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _discountController = TextEditingController();
  final _minTransactionController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isActive = true;
  bool _isLoading = false;

  bool get isEdit => widget.promoId != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _loadPromoData();
    } else {
      // Set default dates
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(days: 7));
    }
  }

  Future<void> _loadPromoData() async {
    // Load existing promo data for editing
    final repository = ref.read(promoRepositoryProvider);
    final promo = await repository.getPromoById(widget.promoId!);
    if (promo != null && mounted) {
      setState(() {
        _nameController.text = promo.name;
        _discountController.text = promo.discountAmount.toStringAsFixed(0);
        _minTransactionController.text = promo.minimumTransaction.toStringAsFixed(0);
        _startDate = promo.startDate;
        _endDate = promo.endDate;
        _isActive = promo.isActive;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _discountController.dispose();
    _minTransactionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Hanya admin yang dapat mengakses halaman ini')),
      );
    }

    ref.listen<PromoFormState>(adminPromoProvider, (prev, next) {
      if (next.success && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Promo berhasil ${isEdit ? "diupdate" : "dibuat"}')),
        );
        context.go('/admin/promos');
      } else if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
      }
    });

    final state = ref.watch(adminPromoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin • ${isEdit ? "Edit" : "Buat"} Promo'),
      ),
      drawer: const AdminDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nama Promo
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Promo',
                  border: OutlineInputBorder(),
                  helperText: 'Contoh: Diskon Akhir Tahun',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama promo tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Potongan Harga
              TextFormField(
                controller: _discountController,
                decoration: const InputDecoration(
                  labelText: 'Potongan Harga (Rp)',
                  border: OutlineInputBorder(),
                  helperText: 'Nominal potongan dalam Rupiah',
                  prefixText: 'Rp ',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Potongan harga tidak boleh kosong';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Potongan harga harus lebih dari 0';
                  }
                  if (amount > 1000000) {
                    return 'Potongan maksimal Rp 1.000.000';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Minimum Transaksi
              TextFormField(
                controller: _minTransactionController,
                decoration: const InputDecoration(
                  labelText: 'Minimum Transaksi (Rp)',
                  border: OutlineInputBorder(),
                  helperText: 'Syarat minimum untuk mendapat promo',
                  prefixText: 'Rp ',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Minimum transaksi tidak boleh kosong';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Minimum transaksi harus lebih dari 0';
                  }
                  final discount = double.tryParse(_discountController.text) ?? 0;
                  if (amount <= discount) {
                    return 'Minimum transaksi harus lebih besar dari potongan';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Tanggal Mulai
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tanggal Mulai'),
                subtitle: Text(_startDate?.toString().split(' ')[0] ?? 'Pilih tanggal'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _startDate = date);
                  }
                },
              ),
              const Divider(),

              // Tanggal Berakhir
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tanggal Berakhir'),
                subtitle: Text(_endDate?.toString().split(' ')[0] ?? 'Pilih tanggal'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now().add(const Duration(days: 7)),
                    firstDate: _startDate ?? DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _endDate = date);
                  }
                },
              ),
              const Divider(),

              // Status Aktif
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Promo Aktif'),
                subtitle: Text(_isActive ? 'Promo akan langsung aktif' : 'Promo nonaktif'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : _submitForm,
                  child: state.isLoading
                      ? const CircularProgressIndicator()
                      : Text(isEdit ? 'Update Promo' : 'Buat Promo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal mulai dan berakhir')),
      );
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanggal berakhir harus setelah tanggal mulai')),
      );
      return;
    }

    final currentUser = ref.read(firebaseAuthProvider).currentUser;
    if (currentUser == null) return;

    final promo = Promo(
      id: widget.promoId ?? '',
      name: _nameController.text.trim(),
      discountAmount: double.parse(_discountController.text),
      minimumTransaction: double.parse(_minTransactionController.text),
      startDate: _startDate!,
      endDate: _endDate!,
      isActive: _isActive,
      createdAt: DateTime.now(),
      createdBy: currentUser.uid,
    );

    if (isEdit) {
      await ref.read(adminPromoProvider.notifier).updatePromo(promo);
    } else {
      await ref.read(adminPromoProvider.notifier).createPromo(promo);
    }
  }
}
