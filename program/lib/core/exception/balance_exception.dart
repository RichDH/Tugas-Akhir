// File: lib/core/exceptions/balance_exception.dart

class InsufficientBalanceException implements Exception {
  final double required;
  final double available;

  const InsufficientBalanceException({
    required this.required,
    required this.available,
  });

  double get shortage => required - available;

  @override
  String toString() {
    return 'Saldo tidak mencukupi';
  }
}
