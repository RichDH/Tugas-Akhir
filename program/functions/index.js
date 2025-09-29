require("dotenv").config();
const express = require("express");
const cors = require("cors");
const { SDK } = require("@100mslive/server-sdk");

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");
const axios = require("axios");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const app = express();
const port = 3000;

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
      token: fcmToken,
    };

    // 3. Kirim notifikasi menggunakan Firebase Admin SDK
    await admin.messaging().send(payload);
    console.log("Notifikasi berhasil dikirim ke:", fcmToken);
    res.status(200).json({ success: true, message: "Notifikasi terkirim." });

  } catch (error) {
    console.error("Gagal mengirim notifikasi:", error);
    res.status(500).json({ error: "Gagal mengirim notifikasi." });
  }
});

// 1. Endpoint untuk membuat invoice
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
        customer: {
          given_names: email.split('@')[0], // Nama diambil dari email
          email: email,
        },
        // Simpan userId di metadata untuk webhook nanti
        metadata: {
          userId: userId
        }
      },
      {
        auth: {
          username: xenditSecretKey,
          password: ''
        }
      }
    );

    res.json({ invoiceUrl: response.data.invoice_url, externalId: externalId });

  } catch (error) {
    console.error("Error creating Xendit invoice:", error.response?.data || error.message);
    res.status(500).json({ error: "Gagal membuat invoice." });
  }
});

// 2. Endpoint untuk menerima webhook dari Xendit
app.post("/xendit-webhook", async (req, res) => {
  const xenditCallbackToken = process.env.XENDIT_WEBHOOK_TOKEN;
  const receivedToken = req.headers['x-callback-token'];

  // Verifikasi token webhook
  if (receivedToken !== xenditCallbackToken) {
    return res.status(403).send("Forbidden: Invalid callback token");
  }

  const data = req.body;
  console.log("Received webhook:", JSON.stringify(data, null, 2));

  // Cek jika pembayaran berhasil ('PAID')
  if (data.status === 'PAID') {
    const userId = data.metadata?.userId;
    const amount = data.paid_amount;

    if (userId && amount) {
      try {
        const userRef = admin.firestore().collection('users').doc(userId);
        // Tambahkan saldo ke user menggunakan FieldValue.increment
        await userRef.update({
          saldo: admin.firestore.FieldValue.increment(amount)
        });
        console.log(`Saldo untuk user ${userId} berhasil ditambah sebesar ${amount}`);
      } catch (dbError) {
        console.error("Error updating user balance:", dbError);
        // Kirim status 500 agar Xendit mencoba lagi nanti
        return res.status(500).send("Error updating database");
      }
    }
  }

  res.status(200).send("Webhook received");
});

app.listen(port, () => {
  console.log(`Backend server berjalan di http://localhost:${port}`);
});
