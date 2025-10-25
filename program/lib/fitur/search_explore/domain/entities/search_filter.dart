// program/lib/fitur/search_explore/domain/entities/search_filter.dart
import 'package:equatable/equatable.dart';

class SearchFilter extends Equatable {
  final bool? isVerified; // untuk filter user
  final String? brand; // untuk filter barang
  final double? minPrice; // untuk filter barang
  final double? maxPrice; // untuk filter barang
  final String? category; // untuk filter barang
  final String? location; // untuk filter barang dan user
  final double? locationLat; // koordinat untuk radius search
  final double? locationLng; // koordinat untuk radius search

  const SearchFilter({
    this.isVerified,
    this.brand,
    this.minPrice,
    this.maxPrice,
    this.category,
    this.location,
    this.locationLat,
    this.locationLng,
  });

  bool get isEmpty =>
      isVerified == null &&
          (brand?.isEmpty ?? true) &&
          minPrice == null &&
          maxPrice == null &&
          (category?.isEmpty ?? true) &&
          (location?.isEmpty ?? true);

  SearchFilter copyWith({
    bool? isVerified,
    String? brand,
    double? minPrice,
    double? maxPrice,
    String? category,
    String? location,
    double? locationLat,
    double? locationLng,
  }) {
    return SearchFilter(
      isVerified: isVerified ?? this.isVerified,
      brand: brand ?? this.brand,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      category: category ?? this.category,
      location: location ?? this.location,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
    );
  }

  SearchFilter clearField({
    bool clearIsVerified = false,
    bool clearBrand = false,
    bool clearPriceRange = false,
    bool clearCategory = false,
    bool clearLocation = false,
  }) {
    return SearchFilter(
      isVerified: clearIsVerified ? null : isVerified,
      brand: clearBrand ? null : brand,
      minPrice: clearPriceRange ? null : minPrice,
      maxPrice: clearPriceRange ? null : maxPrice,
      category: clearCategory ? null : category,
      location: clearLocation ? null : location,
      locationLat: clearLocation ? null : locationLat,
      locationLng: clearLocation ? null : locationLng,
    );
  }

  @override
  List<Object?> get props => [
    isVerified, brand, minPrice, maxPrice, category, location, locationLat, locationLng
  ];
}
