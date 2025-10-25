// program/lib/fitur/search_explore/presentation/widgets/filter_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_provider.dart';
import '../../domain/entities/search_filter.dart';

class FilterDialog extends ConsumerStatefulWidget {
  const FilterDialog({super.key});

  @override
  ConsumerState<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends ConsumerState<FilterDialog> {
  late SearchFilter _tempFilter;
  final _brandController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  final _locationController = TextEditingController();

  String? _selectedCategory;
  bool? _isVerified;

  static const List<String> _categories = [
    'Elektronik',
    'Fashion Pria',
    'Fashion Wanita',
    'Fashion Anak',
    'Kecantikan & Perawatan',
    'Kesehatan',
    'Makanan & Minuman',
    'Rumah Tangga',
    'Olahraga & Outdoor',
    'Hobi & Koleksi',
    'Buku & Alat Tulis',
    'Otomotif',
    'Properti',
    'Jasa',
    'Lainnya'
  ];

  @override
  void initState() {
    super.initState();
    _tempFilter = ref.read(searchFilterProvider);

    // Initialize controllers with current filter values
    _brandController.text = _tempFilter.brand ?? '';
    _minPriceController.text = _tempFilter.minPrice?.toString() ?? '';
    _maxPriceController.text = _tempFilter.maxPrice?.toString() ?? '';
    _locationController.text = _tempFilter.location ?? '';
    _selectedCategory = _tempFilter.category;
    _isVerified = _tempFilter.isVerified;
  }

  @override
  void dispose() {
    _brandController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final newFilter = SearchFilter(
      isVerified: _isVerified,
      brand: _brandController.text.isEmpty ? null : _brandController.text,
      minPrice: _minPriceController.text.isEmpty
          ? null
          : double.tryParse(_minPriceController.text),
      maxPrice: _maxPriceController.text.isEmpty
          ? null
          : double.tryParse(_maxPriceController.text),
      category: _selectedCategory,
      location: _locationController.text.isEmpty ? null : _locationController.text,
    );

    ref.read(searchFilterProvider.notifier).state = newFilter;
    Navigator.of(context).pop();
  }

  void _clearAllFilters() {
    setState(() {
      _brandController.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
      _locationController.clear();
      _selectedCategory = null;
      _isVerified = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter Pencarian',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter untuk User
            const Text(
              'Filter Pengguna',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            // Verified Status
            Row(
              children: [
                const Text('Status Verifikasi: '),
                const Spacer(),
                DropdownButton<bool?>(
                  value: _isVerified,
                  hint: const Text('Semua'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Semua')),
                    DropdownMenuItem(value: true, child: Text('Terverifikasi')),
                    DropdownMenuItem(value: false, child: Text('Belum Verifikasi')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _isVerified = value;
                    });
                  },
                ),
              ],
            ),

            const Divider(height: 32),

            // Filter untuk Barang
            const Text(
              'Filter Barang',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            // Brand
            TextField(
              controller: _brandController,
              decoration: const InputDecoration(
                labelText: 'Merk/Brand',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Price Range
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga Min',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _maxPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga Max',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              hint: const Text('Pilih Kategori'),
              decoration: const InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Semua Kategori')),
                ..._categories.map((category) =>
                    DropdownMenuItem(value: category, child: Text(category))
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Location
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Lokasi',
                border: OutlineInputBorder(),
                helperText: 'Akan mencari dalam radius 50km',
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearAllFilters,
                    child: const Text('Hapus Semua'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applyFilter,
                    child: const Text('Terapkan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
