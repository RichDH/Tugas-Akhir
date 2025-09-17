require("dotenv").config();
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const express = require("express");
const cors = require("cors");
const { SDK } = require("@100mslive/server-sdk");

admin.initializeApp(); // Inisialisasi Firebase Admin

// --- BAGIAN 1: API SERVER EXPRESS.JS ANDA (HAMPIR SAMA) ---
const app = express();
// const port = 3000; // Port tidak diperlukan saat deploy ke Firebase

app.use(cors({ origin: true })); // Gunakan cors({ origin: true }) untuk Firebase
app.use(express.json());

const accessKey = process.env.ONHUNDREDMS_ACCESS_KEY;
const appSecret = process.env.ONHUNDREDMS_APP_SECRET;

const hms = new SDK(accessKey, appSecret);

// Endpoint untuk membuat room (TETAP SAMA)
app.post("/create-room", async (req, res) => {
  try {
    const { name, description } = req.body;
    const roomOptions = {
      name: name || `Live Jastip - ${new Date().toISOString()}`,
      description: description || "Sesi live shopping baru",
    };
    const room = await hms.rooms.create(roomOptions);
    console.log("Room baru dibuat:", room.id);
    res.json({ roomId: room.id });
  } catch (error) {
    console.error("Error saat membuat room:", error.message);
    res.status(500).json({ error: "Gagal membuat room baru." });
  }
});

// Endpoint untuk mendapatkan token (TETAP SAMA)
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

// PENYESUAIAN PENTING:
// Ganti app.listen dengan exports.api agar Firebase bisa menjalankan server Express Anda
exports.api = functions.https.onRequest(app);

// --- BAGIAN 2: FUNGSI NOTIFIKASI FCM BARU (TAMBAHAN) ---
// Fungsi ini akan berjalan otomatis setiap ada pesan baru di Firestore
exports.sendChatNotification = functions.firestore
  .document("chats/{chatId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    const senderId = messageData.senderId;
    const text = messageData.text;

    const chatId = context.params.chatId;
    const userIds = chatId.split("_");
    const recipientId = userIds.find((id) => id !== senderId);

    if (!recipientId) {
      console.log("Penerima tidak ditemukan.");
      return null;
    }

    const recipientDoc = await admin.firestore().collection("users").doc(recipientId).get();
    const fcmToken = recipientDoc.data().fcmToken;

    if (!fcmToken) {
      console.log("FCM Token penerima tidak ditemukan.");
      return null;
    }

    const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
    const senderName = senderDoc.data().username || "Seseorang";

    const payload = {
      notification: {
        title: `Pesan baru dari ${senderName}`,
        body: text,
      },
      token: fcmToken,
    };

    try {
      await admin.messaging().send(payload);
      console.log("Notifikasi berhasil dikirim.");
    } catch (error) {
      console.log("Gagal mengirim notifikasi:", error);
    }

    return null;
  });