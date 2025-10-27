const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const fs = require('fs');
const path = require('path');
const admin = require("firebase-admin");

// Inisialisasi Firebase Admin (gunakan service account atau default credentials)
if (!admin.apps.length) {
  // Gunakan salah satu cara ini:

  // Cara 1: Dengan Service Account Key File (recommended untuk export)
  const serviceAccount = require('./serviceAccountKey.json');
  initializeApp({
    credential: cert(serviceAccount),
    projectId: 'ta-ngoper' // ganti dengan project ID Anda
  });

  // Atau Cara 2: Default credentials (jika sudah login firebase CLI)
  // initializeApp();
}

const db = getFirestore();

// Fungsi untuk export satu collection
async function exportCollection(collectionName) {
  try {
    console.log(`Starting export for collection: ${collectionName}`);

    const snapshot = await db.collection(collectionName).get();
    const data = [];

    snapshot.forEach(doc => {
      const docData = doc.data();

      // Konversi Timestamp ke ISO string untuk JSON compatibility
      const convertTimestamps = (obj) => {
        for (const key in obj) {
          if (obj[key] && typeof obj[key] === 'object') {
            if (obj[key].toDate && typeof obj[key].toDate === 'function') {
              obj[key] = obj[key].toDate().toISOString();
            } else if (Array.isArray(obj[key])) {
              obj[key] = obj[key].map(item =>
                typeof item === 'object' ? convertTimestamps(item) : item
              );
            } else {
              convertTimestamps(obj[key]);
            }
          }
        }
        return obj;
      };

      data.push({
        id: doc.id,
        ...convertTimestamps(docData)
      });
    });

    // Buat folder exports jika belum ada
    const exportsDir = path.join(__dirname, 'exports');
    if (!fs.existsSync(exportsDir)) {
      fs.mkdirSync(exportsDir);
    }

    // Simpan ke file JSON
    const filePath = path.join(exportsDir, `${collectionName}.json`);
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2));

    console.log(`✅ Exported ${data.length} documents from ${collectionName} to ${filePath}`);
    return { collection: collectionName, count: data.length, file: filePath };

  } catch (error) {
    console.error(`❌ Error exporting ${collectionName}:`, error);
    throw error;
  }
}

// Fungsi untuk export semua collections sekaligus
async function exportAllCollections() {
  // Daftar collections yang ada di aplikasi jastip Anda
  const collections = [
    'users',
    'stories', 'transactions', 'user_ads', 'return_requests', 'return_rejection_logs', 'reports', 'promos', 'refund_logs', 'promo_usage_logs', 'posts', 'payout_logs', 'orders', 'offers', 'live_sessions', 'chats', 'invoices', 'announcements', 'ads_transactions', 'ads_packages'
  ];

  const results = [];

  console.log('🚀 Starting Firestore export...');
  console.log(`📋 Collections to export: ${collections.join(', ')}`);

  for (const collection of collections) {
    try {
      const result = await exportCollection(collection);
      results.push(result);
    } catch (error) {
      console.error(`Failed to export ${collection}:`, error.message);
      results.push({ collection, error: error.message });
    }
  }

  // Buat summary report
  const summary = {
    exportDate: new Date().toISOString(),
    totalCollections: collections.length,
    successfulExports: results.filter(r => !r.error).length,
    failedExports: results.filter(r => r.error).length,
    details: results
  };

  // Simpan summary
  const summaryPath = path.join(__dirname, 'exports', 'export-summary.json');
  fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2));

  console.log('\n📊 Export Summary:');
  console.log(`✅ Successful: ${summary.successfulExports}/${summary.totalCollections}`);
  console.log(`❌ Failed: ${summary.failedExports}/${summary.totalCollections}`);
  console.log(`📁 Files saved to: ${path.join(__dirname, 'exports')}`);

  return summary;
}

// Export specific collections (untuk testing)
async function exportSpecific(collectionNames = ['posts']) {
  console.log(`🎯 Exporting specific collections: ${collectionNames.join(', ')}`);

  for (const collection of collectionNames) {
    await exportCollection(collection);
  }
}

module.exports = {
  exportCollection,
  exportAllCollections,
  exportSpecific
};

// Jika file dijalankan langsung
if (require.main === module) {
  exportAllCollections()
    .then(() => {
      console.log('🎉 Export completed successfully!');
      process.exit(0);
    })
    .catch((error) => {
      console.error('💥 Export failed:', error);
      process.exit(1);
    });
}
