require("dotenv").config();
const express = require("express");
const cors = require("cors");
const { SDK } = require("@100mslive/server-sdk");

const admin = require("firebase-admin");
//const serviceAccount = require("./serviceAccountKey.json");
const axios = require("axios");
const cron = require('node-cron');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
    databaseURL: `https://${process.env.FIREBASE_PROJECT_ID}.firebaseio.com`
  });
}
//admin.initializeApp({
//  credential: admin.credential.cert(serviceAccount),
//});

const app = express();
//const port = 3000;

app.use(cors());
app.use(express.json());

// --- Inisialisasi 100ms ---
const accessKey = process.env.ONHUNDREDMS_ACCESS_KEY;
const appSecret = process.env.ONHUNDREDMS_APP_SECRET;

const hms = new SDK(accessKey, appSecret);

// ENDPOINT BARU: Untuk membuat room secara otomatis
app.post("/create-room", async (req, res) => {
  try {
    const { name, description } = req.body;
    const roomOptions = {
      name: name || `Live Jastip - ${new Date().toISOString()}`,
      description: description || "Sesi live shopping baru",
      // Anda bisa menambahkan template ID jika Anda membuatnya di dashboard 100ms
      // template_id: "ID_TEMPLATE_ANDA"
    };

    const room = await hms.rooms.create(roomOptions);
    console.log("Room baru dibuat:", room.id);
    res.json({ roomId: room.id });

  } catch (error) {
    console.error("Error saat membuat room:", error.message);
    res.status(500).json({ error: "Gagal membuat room baru." });
  }
});

// ✅ CRON JOB LENGKAP: Auto-complete dengan pencairan dana
cron.schedule('*/2 * * * *', async () => {
  console.log('[CRON] Menjalankan auto-complete transaksi lengkap...');
  try {
    const now = admin.firestore.Timestamp.now();
    const thresholdTime = new admin.firestore.Timestamp(now.seconds - 60, now.nanoseconds);

    const toSeconds = (val) => {
      if (!val) return null;
      if (val.seconds) return val.seconds;
      if (val.toDate) return Math.floor(val.toDate() / 1000);
      if (val instanceof Date) return Math.floor(val.getTime() / 1000);
      if (typeof val === 'number') return Math.floor(val / 1000);
      return null;
    };

    const snap = await admin.firestore()
      .collection('transactions')
      .where('status', '==', 'delivered')
      .limit(200)
      .get();

    console.log(`[CRON] delivered count: ${snap.size}`);

    let count = 0;
    let skippedCount = 0;
    let errorCount = 0;

    for (const doc of snap.docs) {
      const data = doc.data();
      const transactionId = doc.id;

      const deliveredSec = toSeconds(data.deliveredAt);
      const completedMissing = data.completedAt === null || data.completedAt === undefined;

      if (deliveredSec !== null && completedMissing && deliveredSec <= thresholdTime.seconds) {
        try {
          // 1. Cek return request aktif
          const activeReturns = await admin.firestore()
            .collection('return_requests')
            .where('transactionId', '==', transactionId)
            .where('status', 'in', ['pending', 'awaitingSellerResponse', 'approved', 'sellerResponded'])
            .get();

          if (!activeReturns.empty) {
            skippedCount++;
            console.log(`[CRON] Skip ${transactionId} - ada retur aktif`);
            continue;
          }

          // 2. PROSES AUTO-COMPLETE LENGKAP (seperti completeTransaction)
          const sellerId = data.sellerId;
          const escrowAmount = data.escrowAmount ? parseFloat(data.escrowAmount) : 0;
          const isEscrow = data.isEscrow === true; // boolean check

          console.log(`[CRON] Processing ${transactionId}: sellerId=${sellerId}, escrowAmount=${escrowAmount}, isEscrow=${isEscrow}`);

          // 3. Update transaction dengan semua field yang diperlukan
          const transactionUpdateData = {
            status: 'completed',
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
            rating: null, // Auto-complete = no rating
            releaseToSellerAt: admin.firestore.FieldValue.serverTimestamp(),
            autoCompleted: true, // Flag untuk tracking
            autoCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          // 4. Batch operation untuk atomicity
          const batch = admin.firestore().batch();

          // Update transaction
          batch.update(doc.ref, transactionUpdateData);

          // 5. PENCAIRAN DANA KE SELLER (jika isEscrow = true)
          if (isEscrow && sellerId && escrowAmount > 0) {
            const sellerRef = admin.firestore().collection('users').doc(sellerId);
            batch.update(sellerRef, {
              saldo: admin.firestore.FieldValue.increment(escrowAmount)
            });
            console.log(`[CRON] Mencairkan ${escrowAmount} ke seller ${sellerId}`);
          } else {
            console.log(`[CRON] Skip pencairan: isEscrow=${isEscrow}, escrowAmount=${escrowAmount}`);
          }

          // 6. Commit batch operation
          await batch.commit();
          count++;

          console.log(`[CRON] ✅ Auto-completed: ${transactionId}`);

        } catch (error) {
          errorCount++;
          console.error(`[CRON] ❌ Error processing ${transactionId}:`, error.message);
          // Continue dengan transaksi lainnya
        }
      }
    }

    // 7. Summary log
    console.log(`[CRON] SUMMARY: ${count} completed, ${skippedCount} skipped (retur), ${errorCount} errors`);

  } catch (error) {
    console.error('[CRON ERROR] Gagal menjalankan auto-complete:', error);
  }
});

cron.schedule('*/2 * * * *', async () => {
  console.log('[CRON] Memeriksa retur yang belum direspon...');
  try {
    const now = admin.firestore.Timestamp.now();
    const fifteenMinutesAgo = new admin.firestore.Timestamp(now.seconds - 70, now.nanoseconds);

    // Ambil retur yang menunggu respons seller dan sudah lewat 15 menit
    const returnRequests = await admin.firestore()
      .collection('return_requests')
      .where('status', '==', 'awaitingSellerResponse')
      .where('createdAt', '<=', fifteenMinutesAgo)
      .limit(200)
      .get();

    if (returnRequests.empty) {
      console.log('[CRON] Tidak ada retur yang perlu diproses.');
      return;
    }

    let done = 0;
    let skipped = 0;
    let errors = 0;

    for (const rrDoc of returnRequests.docs) {
      const rr = rrDoc.data();
      const requestId = rrDoc.id;
      const transactionId = rr.transactionId;
      const sellerId = rr.sellerId;
      const buyerReason = rr.reason || '';
      const sellerResponse = rr.responseReason || '';

      try {
        // Ambil transaksi terkait
        const txRef = admin.firestore().collection('transactions').doc(transactionId);
        const txSnap = await txRef.get();
        if (!txSnap.exists) {
          console.warn(`[CRON][RET] Skip ${requestId} - transaksi ${transactionId} tidak ditemukan`);
          skipped++;
          continue;
        }

        const tx = txSnap.data();
        const buyerId = tx.buyerId;
        // Gunakan amount sebagai total pengembalian; jika ada escrowAmount dan ingin berbeda, sesuaikan
        const amount = typeof tx.amount === 'number' ? tx.amount : parseFloat(tx.amount || 0);
        const escrowAmount = typeof tx.escrowAmount === 'number' ? tx.escrowAmount : parseFloat(tx.escrowAmount || amount || 0);

        // Idempoten: jika sudah refunded / return finalApproved, jangan proses ulang
        const alreadyRefunded = tx.status === 'refunded' || tx.refundedAt;
        const rrAlreadyFinal = rr.status === 'finalApproved' || rr.status === 'finalRejected';
        if (alreadyRefunded || rrAlreadyFinal) {
          console.log(`[CRON][RET] Skip ${requestId} - sudah final/refunded`);
          skipped++;
          continue;
        }

        // Batch untuk atomicity
        const batch = admin.firestore().batch();

        // 1) Update return_request -> finalApproved
        batch.update(rrDoc.ref, {
          status: 'finalApproved',
          respondedAt: admin.firestore.FieldValue.serverTimestamp(),
          responseReason: 'Jastiper tidak merespon dalam 15 menit',
        });

        // 2) Update transaksi -> refunded + completedAt
        batch.update(txRef, {
          status: 'refunded',
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          rating: null,
          refundedAt: admin.firestore.FieldValue.serverTimestamp(),
          refundAmount: amount,
          refundReason: 'Jastiper tidak merespon dalam 15 menit (auto-approved)',
        });

        // 3) Refund saldo ke buyer
        if (buyerId && amount > 0) {
          const buyerRef = admin.firestore().collection('users').doc(buyerId);
          batch.update(buyerRef, {
            saldo: admin.firestore.FieldValue.increment(amount),
          });
        }

        // 4) Tambah refund_logs untuk audit trail
        const refundLogRef = admin.firestore().collection('refund_logs').doc();
        batch.set(refundLogRef, {
          transactionId,
          returnRequestId: requestId,
          buyerId,
          sellerId,
          refundAmount: amount,
          originalAmount: amount,
          escrowAmount: escrowAmount || amount,
          reason: 'Final approved return by system (seller no response)',
          buyerReason: buyerReason,
          sellerResponse: sellerResponse,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          processedBy: 'cron',
          type: 'return_refund',
        });

        await batch.commit();
        done++;
        console.log(`[CRON][RET] ✅ Auto-approved & refunded ${transactionId} (request ${requestId})`);

      } catch (e) {
        errors++;
        console.error(`[CRON][RET] ❌ Gagal proses request ${requestId}:`, e.message);
        // Opsional: log error ke collection
        await admin.firestore().collection('auto_return_errors').add({
          requestId,
          transactionId,
          error: e.message,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          retryable: true,
        });
      }
    }

    console.log(`[CRON][RET] SUMMARY: ${done} approved+refunded, ${skipped} skipped, ${errors} errors`);

  } catch (error) {
    console.error('[CRON ERROR] Gagal proses retur otomatis:', error);
  }
});


// --- ENDPOINT BARU: Auto-remove expired cart items ---
app.get("/cleanup-expired-cart-items", async (req, res) => {
  try {
    const now = admin.firestore.Timestamp.now();
    const usersRef = admin.firestore().collection("users");
    const usersSnapshot = await usersRef.get();

    let totalDeleted = 0;

    for (const userDoc of usersSnapshot.docs) {
      const cartRef = usersRef.doc(userDoc.id).collection("cart");
      const cartSnapshot = await cartRef.get();

      const batch = admin.firestore().batch();
      let deletedCount = 0;

      for (const itemDoc of cartSnapshot.docs) {
        const item = itemDoc.data();
        if (item.deadline && item.deadline.toDate() < now.toDate()) {
          batch.delete(itemDoc.ref);
          deletedCount++;
          totalDeleted++;
        }
      }

      if (deletedCount > 0) {
        await batch.commit();
      }
    }

    res.json({ success: true, deletedCount: totalDeleted });
  } catch (error) {
    console.error("Cleanup error:", error);
    res.status(500).json({ error: "Gagal membersihkan keranjang" });
  }
});


// ENDPOINT LAMA (DIMODIFIKASI)
app.post("/get100msToken", async (req, res) => {
  try {
    const { roomId, userId, role } = req.body;

    if (!roomId || !userId || !role) {
      return res.status(400).json({ error: "Parameter wajib tidak ada." });
    }

    const options = {
      userId: userId,
      roomId: roomId,
      role: role,
    };

    const token = await hms.auth.getAuthToken(options);
    res.json({ token: token });

  } catch (error) {
    console.error("Error:", error.message);
    res.status(500).json({ error: "Gagal membuat token." });
  }
});

// ===== NOTIFIKASI PENGUMUMAN BROADCAST =====
app.post("/send-announcement", async (req, res) => {
  try {
    const { title, body, imageUrl, senderId } = req.body;

    if (!title || !body || !senderId) {
      return res.status(400).json({ error: "Parameter tidak lengkap." });
    }

    // Ambil semua FCM token dari semua user
    const usersSnapshot = await admin.firestore().collection('users').get();
    const tokens = [];
    const userNotifications = [];

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;

      if (fcmToken && userDoc.id !== senderId) { // Jangan kirim ke sender sendiri
        tokens.push(fcmToken);

        // Siapkan data untuk disimpan ke notifications collection setiap user
        userNotifications.push({
          userId: userDoc.id,
          notificationData: {
            title: title,
            body: body,
            imageUrl: imageUrl || null,
            type: 'announcement',
            senderId: senderId,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            isRead: false,
          }
        });
      }
    }

    if (tokens.length === 0) {
      return res.status(404).json({ error: "Tidak ada penerima ditemukan." });
    }

    // Kirim notifikasi push ke semua device (batch)
    const messages = tokens.map(token => ({
      notification: {
        title: title,
        body: body,
        ...(imageUrl && { image: imageUrl }), // Tambahkan gambar jika ada
      },
      android: {
        notification: {
          ...(imageUrl && { image: imageUrl }),
          priority: 'high',
          defaultSound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
        ...(imageUrl && {
          fcm_options: {
            image: imageUrl,
          },
        }),
      },
      data: {
        type: 'announcement',
        title: title,
        body: body,
        ...(imageUrl && { imageUrl: imageUrl }),
        senderId: senderId,
      },
      token: token,
    }));

    // Kirim notifikasi push menggunakan sendEach untuk batch processing
    const response = await admin.messaging().sendEach(messages);

    console.log(`[ANNOUNCEMENT] Berhasil kirim ke ${response.successCount}/${messages.length} device`);

    // Simpan ke notifications collection setiap user (batch write)
    const batch = admin.firestore().batch();

    for (const userNotif of userNotifications) {
      const notifRef = admin.firestore()
        .collection('users')
        .doc(userNotif.userId)
        .collection('notifications')
        .doc(); // Auto-generate ID

      batch.set(notifRef, userNotif.notificationData);
    }

    await batch.commit();

    console.log(`[ANNOUNCEMENT] Tersimpan ke ${userNotifications.length} user notifications`);

    res.status(200).json({
      success: true,
      message: "Pengumuman berhasil dikirim",
      sentTo: response.successCount,
      totalRecipients: messages.length,
      failedCount: response.failureCount,
    });

  } catch (error) {
    console.error("Gagal mengirim pengumuman:", error);
    res.status(500).json({ error: "Gagal mengirim pengumuman." });
  }
});

app.post("/sendNotification", async (req, res) => {
  try {
    const { recipientId, senderName, messageText } = req.body;

    if (!recipientId || !senderName || !messageText) {
      return res.status(400).json({ error: "Parameter tidak lengkap." });
    }

    // 1. Ambil FCM Token dari profil penerima di Firestore
    const recipientDoc = await admin.firestore().collection('users').doc(recipientId).get();
    if (!recipientDoc.exists) {
        return res.status(404).json({ error: "Penerima tidak ditemukan." });
    }
    const fcmToken = recipientDoc.data().fcmToken;

    if (!fcmToken) {
      return res.status(404).json({ error: "Token FCM penerima tidak ditemukan." });
    }

    // 2. Buat payload notifikasi
    const payload = {
      notification: {
        title: `Pesan baru dari ${senderName}`,
        body: messageText,
      },
      data: {
        type: 'chat',
        senderName: senderName,
        messageText: messageText,
      },
      token: fcmToken,
    };

    // 3. Kirim notifikasi push
    await admin.messaging().send(payload);

    // 4. ✅ BARU: Simpan ke notifications collection penerima
    await admin.firestore()
      .collection('users')
      .doc(recipientId)
      .collection('notifications')
      .add({
        title: `Pesan baru dari ${senderName}`,
        body: messageText,
        type: 'chat',
        senderName: senderName,
        data: {
          messageText: messageText,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
      });

    console.log("Chat notification berhasil dikirim dan disimpan ke:", recipientId);
    res.status(200).json({ success: true, message: "Notifikasi terkirim dan tersimpan." });

  } catch (error) {
    console.error("Gagal mengirim notifikasi:", error);
    res.status(500).json({ error: "Gagal mengirim notifikasi." });
  }
});



// 1. Endpoint untuk membuat invoice Xendit
app.post("/create-invoice", async (req, res) => {
  try {
    const { amount, userId, email } = req.body;
    if (!amount || !userId || !email) {
      return res.status(400).json({ error: "Parameter tidak lengkap." });
    }

    const xenditSecretKey = process.env.XENDIT_SECRET_KEY;
    const externalId = `topup-${userId}-${Date.now()}`;

    const response = await axios.post(
      "https://api.xendit.co/v2/invoices",
      {
        external_id: externalId,
        amount: amount,
        payer_email: email,
        description: `Top-up saldo untuk user ${userId}`,
        success_redirect_url: `https://ngoper.app/topup/success`,
      },
      {
        auth: {
          username: xenditSecretKey,
          password: ''
        }
      }
    );

    // Simpan data invoice ke Firestore untuk referensi
    await admin.firestore().collection('invoices').doc(externalId).set({
      userId: userId,
      amount: amount,
      status: 'PENDING',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      xenditInvoiceId: response.data.id
    });

    res.json({
      invoiceUrl: response.data.invoice_url,
      externalId: externalId
    });

  } catch (error) {
    console.error("Error creating Xendit invoice:", error.response?.data || error.message);
    res.status(500).json({ error: "Gagal membuat invoice." });
  }
});

// 2. Endpoint BARU untuk mengecek status invoice
app.get("/check-invoice/:externalId", async (req, res) => {
  try {
    const { externalId } = req.params;

    // Cek dari Firestore dulu
    const invoiceDoc = await admin.firestore().collection('invoices').doc(externalId).get();

    if (!invoiceDoc.exists) {
      return res.status(404).json({ error: "Invoice tidak ditemukan" });
    }

    const invoiceData = invoiceDoc.data();

    // Jika sudah PAID di Firestore, langsung return
    if (invoiceData.status === 'PAID') {
      return res.json({ status: 'PAID' });
    }

    // Jika belum, cek ke Xendit API
    const xenditSecretKey = process.env.XENDIT_SECRET_KEY;
    const xenditInvoiceId = invoiceData.xenditInvoiceId;

    const response = await axios.get(
      `https://api.xendit.co/v2/invoices/${xenditInvoiceId}`,
      {
        auth: {
          username: xenditSecretKey,
          password: ''
        }
      }
    );

    const status = response.data.status;

    // Update status di Firestore
    await admin.firestore().collection('invoices').doc(externalId).update({
      status: status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Jika PAID, update saldo user juga (backup jika webhook belum sampai)
    if (status === 'PAID' && invoiceData.status !== 'PAID') {
      const parts = externalId.split('-');
      const userId = parts[1];

      await admin.firestore().collection('users').doc(userId).update({
        saldo: admin.firestore.FieldValue.increment(invoiceData.amount)
      });

      console.log(`[CHECK-INVOICE] Saldo user ${userId} ditambah ${invoiceData.amount}`);
    }

    res.json({ status: status });

  } catch (error) {
    console.error("Error checking invoice:", error.response?.data || error.message);
    res.status(500).json({ error: "Gagal memeriksa status invoice." });
  }
});

// 3. Endpoint untuk menerima webhook dari Xendit
app.post("/xendit-webhook", async (req, res) => {
  const xenditCallbackToken = process.env.XENDIT_WEBHOOK_TOKEN;
  const receivedToken = req.headers['x-callback-token'];

  // Verifikasi token webhook (PENTING untuk keamanan)
  if (xenditCallbackToken && receivedToken !== xenditCallbackToken) {
    console.log("Invalid webhook token received");
    return res.status(403).send("Forbidden: Invalid callback token");
  }

  const data = req.body;
  console.log("=== WEBHOOK RECEIVED ===");
  console.log(JSON.stringify(data, null, 2));

  if (data.status === 'PAID') {
    const externalId = data.external_id;
    const amount = data.paid_amount || data.amount;

    if (externalId && externalId.startsWith('topup-')) {
      const parts = externalId.split('-');
      const userId = parts[1];

      if (userId && amount) {
        try {
          // Update status invoice di Firestore
          await admin.firestore().collection('invoices').doc(externalId).update({
            status: 'PAID',
            paidAt: admin.firestore.FieldValue.serverTimestamp(),
            paidAmount: amount
          });

          // Update saldo user
          const userRef = admin.firestore().collection('users').doc(userId);
          await userRef.update({
            saldo: admin.firestore.FieldValue.increment(amount)
          });

          console.log(`[WEBHOOK] Saldo user ${userId} berhasil ditambah sebesar ${amount}`);
        } catch (dbError) {
          console.error("Error updating database:", dbError);
          return res.status(500).send("Error updating database");
        }
      }
    }
  }

  res.status(200).send("Webhook received");
});


//app.listen(port, () => {
//  console.log(`Backend server berjalan di http://localhost:${port}`);
//});
module.exports = app;