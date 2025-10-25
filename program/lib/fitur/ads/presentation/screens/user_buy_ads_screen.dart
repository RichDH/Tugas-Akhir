import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/ads/domain/entities/ads_package.dart';
import 'package:program/fitur/ads/presentation/providers/ads_package_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserBuyAdsScreen extends ConsumerStatefulWidget {
  const UserBuyAdsScreen({super.key});

  @override
  ConsumerState<UserBuyAdsScreen> createState() => _UserBuyAdsScreenState();
}

class _UserBuyAdsScreenState extends ConsumerState<UserBuyAdsScreen> {
  String? selectedPostId;
  AdsPackage? selectedPackage;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Beli Ads')),
        body: const Center(child: Text('Silakan login terlebih dahulu')),
      );
    }

    final eligiblePosts = ref.watch(userEligiblePostsForAdsProvider(user.uid));
    final activePackages = ref.watch(activeAdsPackagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beli Ads'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Header
            Card(
              color: Colors.purple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.rocket_launch, color: Colors.purple.shade700, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Promosikan Postingan Anda',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Buat postingan Anda muncul di urutan teratas feed dan section "Suggested"',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Step 1: Pilih Post
            Text(
              '1. Pilih Postingan',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih postingan yang ingin dipromosikan (tidak termasuk Request)',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),

            eligiblePosts.when(
              data: (posts) {
                if (posts.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.post_add, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          const Text('Tidak ada postingan yang dapat dipromosikan'),
                          const SizedBox(height: 4),
                          Text(
                            'Buat postingan Jastip atau Short terlebih dahulu',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: posts.map((post) {
                    final isSelected = selectedPostId == post['id'];
                    return GestureDetector(
                      onTap: () => setState(() => selectedPostId = post['id']),
                      child: Card(
                        color: isSelected ? Colors.purple.shade50 : null,
                        elevation: isSelected ? 3 : 1,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Thumbnail
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _buildPostThumbnail(post),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Post Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post['title'] ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      post['type'] == 'jastip' ? 'Jastip' : 'Short',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    if (post['price'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(post['price']),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Selection indicator
                              Radio<String?>(
                                value: post['id'],
                                groupValue: selectedPostId,
                                onChanged: (val) => setState(() => selectedPostId = val),
                                activeColor: Colors.purple,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, s) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: $e'),
                ),
              ),
            ),

            if (selectedPostId != null) ...[
              const SizedBox(height: 32),

              // Step 2: Pilih Paket
              Text(
                '2. Pilih Paket Ads',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              activePackages.when(
                data: (packages) {
                  if (packages.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Tidak ada paket ads yang tersedia'),
                      ),
                    );
                  }

                  return Column(
                    children: packages.map((package) {
                      final isSelected = selectedPackage?.id == package.id;
                      return GestureDetector(
                        onTap: () => setState(() => selectedPackage = package),
                        child: _buildPackageCard(package, isSelected),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (e, s) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error loading packages: $e'),
                  ),
                ),
              ),
            ],

            if (selectedPostId != null && selectedPackage != null) ...[
              const SizedBox(height: 32),

              // Step 3: Checkout
              Text(
                '3. Checkout',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              _buildCheckoutSection(user),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPostThumbnail(Map<String, dynamic> post) {
    final imageUrls = post['imageUrls'] as List<String>?;
    final videoUrl = post['videoUrl'] as String?;

    if (imageUrls != null && imageUrls.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrls.first,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => const Icon(Icons.image),
      );
    } else if (videoUrl != null && videoUrl.isNotEmpty) {
      return Stack(
        alignment: Alignment.center,
        children: [
          CachedNetworkImage(
            imageUrl: videoUrl, // Cloudinary bisa generate thumbnail dari video
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => Container(
              color: Colors.grey.shade300,
              child: const Icon(Icons.video_library),
            ),
          ),
          const Icon(Icons.play_circle_fill, color: Colors.white, size: 24),
        ],
      );
    } else {
      return Container(
        color: Colors.grey.shade300,
        child: const Icon(Icons.image),
      );
    }
  }

  Widget _buildPackageCard(AdsPackage package, bool isSelected) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    Color cardColor;
    Color accentColor;
    IconData packageIcon;

    switch (package.type) {
      case AdsPackageType.premium:
        cardColor = Colors.amber.shade50;
        accentColor = Colors.amber.shade600;
        packageIcon = Icons.star;
        break;
      case AdsPackageType.vip:
        cardColor = Colors.purple.shade50;
        accentColor = Colors.purple.shade600;
        packageIcon = Icons.diamond;
        break;
    }

    return Card(
      color: isSelected ? cardColor : Colors.grey.shade50,
      elevation: isSelected ? 3 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(packageIcon, color: accentColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Level ${package.level} • ${package.durationDays} hari'),
                  const SizedBox(height: 4),
                  Text(
                    formatter.format(package.price),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            Radio<AdsPackage?>(
              value: package,
              groupValue: selectedPackage,
              onChanged: (val) => setState(() => selectedPackage = val),
              activeColor: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutSection(User user) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ringkasan Pembelian',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Paket:'),
                Text(selectedPackage!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Durasi:'),
                Text('${selectedPackage!.durationDays} hari'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Level Prioritas:'),
                Text('Level ${selectedPackage!.level}'),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Bayar:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  formatter.format(selectedPackage!.price),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // User balance check
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (context, snapshot) {
                final userData = snapshot.data?.data() as Map<String, dynamic>?;
                final userBalance = (userData?['saldo'] as num?)?.toDouble() ?? 0.0;
                final canAfford = userBalance >= selectedPackage!.price;

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: canAfford ? Colors.green.shade100 : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: canAfford ? Colors.green : Colors.red),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            canAfford ? Icons.account_balance_wallet : Icons.warning,
                            color: canAfford ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Saldo Anda: ${formatter.format(userBalance)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: canAfford ? Colors.green.shade700 : Colors.red.shade700,
                                  ),
                                ),
                                if (!canAfford) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Kurang: ${formatter.format(selectedPackage!.price - userBalance)}',
                                    style: TextStyle(fontSize: 12, color: Colors.red.shade600),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: canAfford ? () => _purchaseAds(user) : null,
                        icon: canAfford ? const Icon(Icons.payment) : const Icon(Icons.account_balance_wallet),
                        label: Text(canAfford ? 'Beli Ads Sekarang' : 'Top Up Saldo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canAfford ? Colors.purple : Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

                    if (!canAfford) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.push('/top-up'),
                        child: const Text('Pergi ke Top Up'),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchaseAds(User user) async {
    if (selectedPostId == null || selectedPackage == null) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Memproses pembelian ads...'),
            ],
          ),
        ),
      );

      final batch = FirebaseFirestore.instance.batch();
      final now = DateTime.now();
      final endDate = now.add(Duration(days: selectedPackage!.durationDays));

      // 1. Kurangi saldo user
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      batch.update(userRef, {
        'saldo': FieldValue.increment(-selectedPackage!.price),
      });

      // 2. Tambahkan saldo admin
      final adminQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: 'admin@gmail.com')
          .limit(1)
          .get();

      if (adminQuery.docs.isNotEmpty) {
        final adminRef = adminQuery.docs.first.reference;
        batch.update(adminRef, {
          'saldo': FieldValue.increment(selectedPackage!.price),
        });
      }

      // 3. Update post dengan ads data
      final postRef = FirebaseFirestore.instance.collection('posts').doc(selectedPostId!);
      batch.update(postRef, {
        'adsLevel': selectedPackage!.level,
        'adsPackageType': selectedPackage!.type.name,
        'adsStartDate': Timestamp.fromDate(now),
        'adsExpiredAt': Timestamp.fromDate(endDate),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 4. Buat record user_ads
      final userAdsRef = FirebaseFirestore.instance.collection('user_ads').doc();
      batch.set(userAdsRef, {
        'userId': user.uid,
        'postId': selectedPostId!,
        'packageType': selectedPackage!.type.name,
        'packageName': selectedPackage!.name,
        'adsLevel': selectedPackage!.level,
        'paidAmount': selectedPackage!.price,
        'startDate': Timestamp.fromDate(now),
        'endDate': Timestamp.fromDate(endDate),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 5. Log transaksi ads
      final adsTransactionRef = FirebaseFirestore.instance.collection('ads_transactions').doc();
      batch.set(adsTransactionRef, {
        'userId': user.uid,
        'postId': selectedPostId!,
        'packageType': selectedPackage!.type.name,
        'amount': selectedPackage!.price,
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success dialog
      await _showSuccessDialog();

    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membeli ads: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ads Berhasil Dibeli!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green.shade600),
            const SizedBox(height: 16),
            Text('Postingan Anda akan muncul di urutan teratas feed selama ${selectedPackage!.durationDays} hari'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '🚀 Ads akan aktif dalam beberapa menit',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/profile'); // Kembali ke profile
            },
            child: const Text('Lihat Profil'),
          ),
        ],
      ),
    );
  }
}
