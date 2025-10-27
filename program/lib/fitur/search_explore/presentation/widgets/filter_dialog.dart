// program/lib/fitur/search_explore/presentation/widgets/filter_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_provider.dart';
import '../../domain/entities/search_filter.dart';
import '../../../../core/location/locationService.dart';
import '../../../../core/location/locationSuggestion.dart';

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

  // ✅ Location suggestions
  List<LocationSuggestion> _locationSuggestions = [];
  LocationSuggestion? _selectedLocation;

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

  // ✅ Search locations seperti di create post
  Future<void> _searchLocations(String query) async {
    if (query.length <= 2) {
      setState(() => _locationSuggestions = []);
      return;
    }
    try {
      final suggestions = await LocationService.searchLocations(query);
      setState(() => _locationSuggestions = suggestions);
    } catch (e) {
      print('Error searching locations: $e');
      setState(() => _locationSuggestions = []);
    }
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
      location: _selectedLocation?.displayName ?? (_locationController.text.isEmpty ? null : _locationController.text),
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
      _selectedLocation = null;
      _locationSuggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
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

              // ✅ Location dengan suggestions seperti create post
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Lokasi',
                  border: OutlineInputBorder(),
                  helperText: 'Ketik minimal 3 karakter untuk mencari lokasi',
                ),
                onChanged: (v) => _searchLocations(v),
              ),

              // ✅ Location suggestions
              if (_locationSuggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _locationSuggestions.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (_, i) {
                      final loc = _locationSuggestions[i];
                      return ListTile(
                        dense: true,
                        title: Text(loc.displayName, style: const TextStyle(fontSize: 14)),
                        subtitle: Text(loc.country, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        trailing: Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                        onTap: () {
                          setState(() {
                            _locationController.text = loc.displayName;
                            _selectedLocation = loc;
                            _locationSuggestions = [];
                          });
                        },
                      );
                    },
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
      ),
    );
  }
}
