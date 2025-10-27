require("dotenv").config();
const express = require("express");
const cors = require("cors");
const { SDK } = require("@100mslive/server-sdk");
const admin = require("firebase-admin");
const axios = require("axios");

// Initialize Firebase Admin
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

const app = express();
app.use(cors());
app.use(express.json());

// Initialize 100ms
const accessKey = process.env.ONHUNDREDMS_ACCESS_KEY;
const appSecret = process.env.ONHUNDREDMS_APP_SECRET;
const hms = new SDK(accessKey, appSecret);

// ✅ FUNGSI CRON JOB 1: AUTO-COMPLETE TRANSACTIONS
async function runAutoCompleteTransactions() {
  console.log('[CRON] Menjalankan auto-complete transaksi...');
  try {
    const now = admin.firestore.Timestamp.now();
    const thresholdTime = new admin.firestore.Timestamp(now.seconds - 60, now.nanoseconds);

    const toSeconds = (val) => {
      if (!val) return null;
      if (val.seconds) return val.seconds;
      if (val.toDate) return Math.floor(val.toDate().getTime() / 1000);
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

          const sellerId = data.sellerId;
          const escrowAmount = data.escrowAmount ? parseFloat(data.escrowAmount) : 0;
          const isEscrow = data.isEscrow === true;

          const transactionUpdateData = {
            status: 'completed',
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
            rating: null,
            releaseToSellerAt: admin.firestore.FieldValue.serverTimestamp(),
            autoCompleted: true,
            autoCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          const batch = admin.firestore().batch();
          batch.update(doc.ref, transactionUpdateData);

          if (isEscrow && sellerId && escrowAmount > 0) {
            const sellerRef = admin.firestore().collection('users').doc(sellerId);
            batch.update(sellerRef, {
              saldo: admin.firestore.FieldValue.increment(escrowAmount)
            });
            console.log(`[CRON] Mencairkan ${escrowAmount} ke seller ${sellerId}`);
          }

          await batch.commit();
          count++;
          console.log(`[CRON] ✅ Auto-completed: ${transactionId}`);

        } catch (error) {
          errorCount++;
          console.error(`[CRON] ❌ Error processing ${transactionId}:`, error.message);
        }
      }
    }

    console.log(`[CRON] SUMMARY: ${count} completed, ${skippedCount} skipped, ${errorCount} errors`);
    return { completed: count, skipped: skippedCount, errors: errorCount };

  } catch (error) {
    console.error('[CRON ERROR] Gagal menjalankan auto-complete:', error);
    throw error;
  }
}

// ✅ FUNGSI CRON JOB 2: AUTO-APPROVE RETURNS
async function runAutoApproveReturns() {
  console.log('[CRON] Memeriksa retur yang belum direspon...');
  try {
    const now = admin.firestore.Timestamp.now();
    const fifteenMinutesAgo = new admin.firestore.Timestamp(now.seconds - 150, now.nanoseconds);

    const returnRequests = await admin.firestore()
      .collection('return_requests')
      .where('status', '==', 'awaitingSellerResponse')
      .where('createdAt', '<=', fifteenMinutesAgo)
      .limit(200)
      .get();

    if (returnRequests.empty) {
      console.log('[CRON] Tidak ada retur yang perlu diproses.');
      return { approved: 0, skipped: 0, errors: 0 };
    }

    let done = 0;
    let skipped = 0;
    let errors = 0;

    for (const rrDoc of returnRequests.docs) {
      const rr = rrDoc.data();
      const requestId = rrDoc.id;
      const transactionId = rr.transactionId;

      try {
        const txRef = admin.firestore().collection('transactions').doc(transactionId);
        const txSnap = await txRef.get();
        if (!txSnap.exists) {
          skipped++;
          continue;
        }

        const tx = txSnap.data();
        const buyerId = tx.buyerId;
        const amount = typeof tx.amount === 'number' ? tx.amount : parseFloat(tx.amount || 0);

        const alreadyRefunded = tx.status === 'refunded' || tx.refundedAt;
        const rrAlreadyFinal = rr.status === 'finalApproved' || rr.status === 'finalRejected';
        if (alreadyRefunded || rrAlreadyFinal) {
          skipped++;
          continue;
        }

        const batch = admin.firestore().batch();

        batch.update(rrDoc.ref, {
          status: 'finalApproved',
          respondedAt: admin.firestore.FieldValue.serverTimestamp(),
          responseReason: 'Jastiper tidak merespon dalam 15 menit',
        });

        batch.update(txRef, {
          status: 'refunded',
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          rating: null,
          refundedAt: admin.firestore.FieldValue.serverTimestamp(),
          refundAmount: amount,
          refundReason: 'Jastiper tidak merespon dalam 15 menit (auto-approved)',
        });

        if (buyerId && amount > 0) {
          const buyerRef = admin.firestore().collection('users').doc(buyerId);
          batch.update(buyerRef, {
            saldo: admin.firestore.FieldValue.increment(amount),
          });
        }

        await batch.commit();
        done++;
        console.log(`[CRON] ✅ Auto-approved & refunded ${transactionId}`);

      } catch (e) {
        errors++;
        console.error(`[CRON] ❌ Gagal proses request ${requestId}:`, e.message);
      }
    }

    console.log(`[CRON] SUMMARY: ${done} approved, ${skipped} skipped, ${errors} errors`);
    return { approved: done, skipped, errors };

  } catch (error) {
    console.error('[CRON ERROR] Gagal proses retur otomatis:', error);
    throw error;
  }
}

// ✅ FUNGSI CRON JOB 3: CART CLEANUP
async function runCartCleanup() {
  console.log('[CRON] Membersihkan cart dari postingan yang dihapus...');
  try {
    let totalCartItemsRemoved = 0;
    let totalUsersProcessed = 0;

    const usersSnapshot = await admin.firestore().collection('users').get();

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;

      try {
        const cartRef = admin.firestore()
          .collection('users')
          .doc(userId)
          .collection('cart');

        const cartSnapshot = await cartRef.get();
        if (cartSnapshot.empty) continue;

        const batch = admin.firestore().batch();
        let userCartItemsRemoved = 0;

        for (const cartItemDoc of cartSnapshot.docs) {
          const cartItem = cartItemDoc.data();
          const postId = cartItem.postId;

          if (!postId) continue;

          const postRef = admin.firestore().collection('posts').doc(postId);
          const postDoc = await postRef.get();

          if (!postDoc.exists) {
            batch.delete(cartItemDoc.ref);
            userCartItemsRemoved++;
          } else {
            const postData = postDoc.data();
            if (postData.deleted === true) {
              batch.delete(cartItemDoc.ref);
              userCartItemsRemoved++;
            }
          }
        }

        if (userCartItemsRemoved > 0) {
          await batch.commit();
          totalCartItemsRemoved += userCartItemsRemoved;
          console.log(`[CART-CLEANUP] User ${userId}: removed ${userCartItemsRemoved} items`);
        }

        totalUsersProcessed++;

      } catch (userError) {
        console.error(`[CART-CLEANUP] Error processing user ${userId}:`, userError.message);
      }
    }

    console.log(`[CART-CLEANUP] SUMMARY: ${totalCartItemsRemoved} items removed from ${totalUsersProcessed} users`);
    return { removedItems: totalCartItemsRemoved, processedUsers: totalUsersProcessed };

  } catch (error) {
    console.error('[CART-CLEANUP ERROR]:', error);
    throw error;
  }
}

// ✅ FUNGSI CRON JOB 4: STORY CLEANUP (expire setelah 2 menit)
async function runStoryCleanup() {
  console.log('[CRON] Membersihkan story yang sudah expired...');
  try {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const snap = await db
      .collection('stories')
      .where('isActive', '==', true)
      .where('expiresAt', '<=', now)
      .limit(500)
      .get();

    if (snap.empty) {
      console.log('[STORY-CLEANUP] Tidak ada story expired.');
      return { updated: 0 };
    }

    const batch = db.batch();
    let updated = 0;

    snap.forEach(doc => {
      batch.update(doc.ref, {
        isActive: false,
        deletedAt: now,
      });
      updated++;
    });

    await batch.commit();
    console.log(`[STORY-CLEANUP] ✅ Nonaktifkan ${updated} story expired`);
    return { updated };
  } catch (error) {
    console.error('[STORY-CLEANUP ERROR]:', error.message);
    throw error;
  }
}


// ✅ ENDPOINT CRON UNTUK VERCEL
app.get('/cron/auto-complete-transactions', async (req, res) => {
  try {
    const result = await runAutoCompleteTransactions();
    res.json({ success: true, ...result });
  } catch (error) {
    console.error('Cron auto-complete error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/cron/auto-approve-returns', async (req, res) => {
  try {
    const result = await runAutoApproveReturns();
    res.json({ success: true, ...result });
  } catch (error) {
    console.error('Cron auto-approve error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/cron/cart-cleanup', async (req, res) => {
  try {
    const result = await runCartCleanup();
    res.json({ success: true, ...result });
  } catch (error) {
    console.error('Cron cart cleanup error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/cron/story-cleanup', async (req, res) => {
  try {
    const result = await runStoryCleanup();
    res.json({ success: true, ...result });
  } catch (error) {
    console.error('Cron story cleanup error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});


// ✅ JALANKAN NODE-CRON HANYA SAAT DEVELOPMENT (TIDAK DI VERCEL)
const isVercel = !!process.env.VERCEL;
if (!isVercel) {
  const cron = require('node-cron');
  console.log('Starting local cron jobs...');
  cron.schedule('*/2 * * * *', runAutoCompleteTransactions);
  cron.schedule('*/2 * * * *', runAutoApproveReturns);
  cron.schedule('*/1 * * * *', runCartCleanup);
  cron.schedule('*/2 * * * *', runStoryCleanup);
}

// ✅ ENDPOINT LAINNYA (TETAP SAMA)
app.post("/create-room", async (req, res) => {
  try {
    const { name, description } = req.body;
    const roomOptions = {
      name: name || `Live Jastip - ${new Date().toISOString()}`,
      description: description || "Sesi live shopping baru",
    };
    const room = await hms.rooms.create(roomOptions);
    res.json({ roomId: room.id });
  } catch (error) {
    console.error("Error saat membuat room:", error.message);
    res.status(500).json({ error: "Gagal membuat room baru." });
  }
});

app.post("/get100msToken", async (req, res) => {
  try {
    const { roomId, userId, role } = req.body;
    if (!roomId || !userId || !role) {
      return res.status(400).json({ error: "Parameter wajib tidak ada." });
    }
    const options = { userId, roomId, role };
    const token = await hms.auth.getAuthToken(options);
    res.json({ token });
  } catch (error) {
    console.error("Error:", error.message);
    res.status(500).json({ error: "Gagal membuat token." });
  }
});

app.post("/send-announcement", async (req, res) => {
  try {
    const { title, body, imageUrl, senderId } = req.body;
    if (!title || !body || !senderId) {
      return res.status(400).json({ error: "Parameter tidak lengkap." });
    }

    const usersSnapshot = await admin.firestore().collection('users').get();
    const tokens = [];
    const userNotifications = [];

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;
      if (fcmToken && userDoc.id !== senderId) {
        tokens.push(fcmToken);
        userNotifications.push({
          userId: userDoc.id,
          notificationData: {
            title, body, imageUrl: imageUrl || null, type: 'announcement',
            senderId, createdAt: admin.firestore.FieldValue.serverTimestamp(), isRead: false,
          }
        });
      }
    }

    if (tokens.length === 0) {
      return res.status(404).json({ error: "Tidak ada penerima ditemukan." });
    }

    const messages = tokens.map(token => ({
      notification: { title, body, ...(imageUrl && { image: imageUrl }) },
      data: { type: 'announcement', title, body, ...(imageUrl && { imageUrl }), senderId },
      token,
    }));

    const response = await admin.messaging().sendEach(messages);
    const batch = admin.firestore().batch();

    for (const userNotif of userNotifications) {
      const notifRef = admin.firestore()
        .collection('users').doc(userNotif.userId).collection('notifications').doc();
      batch.set(notifRef, userNotif.notificationData);
    }
    await batch.commit();

    res.status(200).json({
      success: true, message: "Pengumuman berhasil dikirim",
      sentTo: response.successCount, totalRecipients: messages.length,
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

    const recipientDoc = await admin.firestore().collection('users').doc(recipientId).get();
    if (!recipientDoc.exists) {
      return res.status(404).json({ error: "Penerima tidak ditemukan." });
    }

    const fcmToken = recipientDoc.data().fcmToken;
    if (!fcmToken) {
      return res.status(404).json({ error: "Token FCM penerima tidak ditemukan." });
    }

    const payload = {
      notification: { title: `Pesan baru dari ${senderName}`, body: messageText },
      data: { type: 'chat', senderName, messageText },
      token: fcmToken,
    };

    await admin.messaging().send(payload);
    await admin.firestore().collection('users').doc(recipientId).collection('notifications').add({
      title: `Pesan baru dari ${senderName}`, body: messageText, type: 'chat', senderName,
      data: { messageText }, createdAt: admin.firestore.FieldValue.serverTimestamp(), isRead: false,
    });

    res.status(200).json({ success: true, message: "Notifikasi terkirim dan tersimpan." });
  } catch (error) {
    console.error("Gagal mengirim notifikasi:", error);
    res.status(500).json({ error: "Gagal mengirim notifikasi." });
  }
});

app.post("/create-invoice", async (req, res) => {
  try {
    const { amount, userId, email } = req.body;
    if (!amount || !userId || !email) {
      return res.status(400).json({ error: "Parameter tidak lengkap." });
    }

    const xenditSecretKey = process.env.XENDIT_SECRET_KEY;
    const externalId = `topup-${userId}-${Date.now()}`;

    const response = await axios.post("https://api.xendit.co/v2/invoices", {
      external_id: externalId, amount, payer_email: email,
      description: `Top-up saldo untuk user ${userId}`,
      success_redirect_url: `https://ngoper.app/topup/success`,
    }, {
      auth: { username: xenditSecretKey, password: '' }
    });

    await admin.firestore().collection('invoices').doc(externalId).set({
      userId, amount, status: 'PENDING', createdAt: admin.firestore.FieldValue.serverTimestamp(),
      xenditInvoiceId: response.data.id
    });

    res.json({ invoiceUrl: response.data.invoice_url, externalId });
  } catch (error) {
    console.error("Error creating Xendit invoice:", error.response?.data || error.message);
    res.status(500).json({ error: "Gagal membuat invoice." });
  }
});

app.get("/check-invoice/:externalId", async (req, res) => {
  try {
    const { externalId } = req.params;
    const invoiceDoc = await admin.firestore().collection('invoices').doc(externalId).get();

    if (!invoiceDoc.exists) {
      return res.status(404).json({ error: "Invoice tidak ditemukan" });
    }

    const invoiceData = invoiceDoc.data();
    if (invoiceData.status === 'PAID') {
      return res.json({ status: 'PAID' });
    }

    const xenditSecretKey = process.env.XENDIT_SECRET_KEY;
    const response = await axios.get(`https://api.xendit.co/v2/invoices/${invoiceData.xenditInvoiceId}`, {
      auth: { username: xenditSecretKey, password: '' }
    });

    const status = response.data.status;
    await admin.firestore().collection('invoices').doc(externalId).update({
      status, updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    if (status === 'PAID' && invoiceData.status !== 'PAID') {
      const parts = externalId.split('-');
      const userId = parts[1];
      await admin.firestore().collection('users').doc(userId).update({
        saldo: admin.firestore.FieldValue.increment(invoiceData.amount)
      });
    }

    res.json({ status });
  } catch (error) {
    console.error("Error checking invoice:", error.response?.data || error.message);
    res.status(500).json({ error: "Gagal memeriksa status invoice." });
  }
});

app.post("/xendit-webhook", async (req, res) => {
  const xenditCallbackToken = process.env.XENDIT_WEBHOOK_TOKEN;
  const receivedToken = req.headers['x-callback-token'];

  if (xenditCallbackToken && receivedToken !== xenditCallbackToken) {
    return res.status(403).send("Forbidden");
  }

  const data = req.body;
  if (data.status === 'PAID') {
    const externalId = data.external_id;
    const amount = data.paid_amount || data.amount;

    if (externalId && externalId.startsWith('topup-')) {
      const parts = externalId.split('-');
      const userId = parts[1];

      if (userId && amount) {
        try {
          await admin.firestore().collection('invoices').doc(externalId).update({
            status: 'PAID', paidAt: admin.firestore.FieldValue.serverTimestamp(), paidAmount: amount
          });
          await admin.firestore().collection('users').doc(userId).update({
            saldo: admin.firestore.FieldValue.increment(amount)
          });
        } catch (dbError) {
          console.error("Error updating database:", dbError);
          return res.status(500).send("Error updating database");
        }
      }
    }
  }
  res.status(200).send("Webhook received");
});

module.exports = app;
