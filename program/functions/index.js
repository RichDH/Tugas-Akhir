require("dotenv").config();
const express = require("express");
const cors = require("cors");
const { SDK } = require("@100mslive/server-sdk");

const app = express();
const port = 3000;

app.use(cors());
app.use(express.json());

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

app.listen(port, () => {
  console.log(`Backend server berjalan di http://localhost:${port}`);
});