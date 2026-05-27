const db = require("../config/db");

/* =========================
   SAVE ADDRESS (FINAL FIXED)
========================= */
exports.saveAddress = async (req, res) => {
  try {
    console.log("📥 Incoming Address Body:", req.body);

    let {
      user_id,
      name,
      mobile,
      address_line,
      area,
      landmark,
      pincode,
      state,
      latitude,
      longitude
    } = req.body;

    // 🔴 Strict validation
    if (!user_id || !address_line || latitude == null || longitude == null) {
      return res.status(400).json({
        message: "user_id, address_line, latitude and longitude required"
      });
    }

    // ✅ Convert types safely
    latitude = parseFloat(latitude);
    longitude = parseFloat(longitude);

    if (isNaN(latitude) || isNaN(longitude)) {
      return res.status(400).json({
        message: "Invalid latitude/longitude"
      });
    }

    // ✅ Default empty values (avoid SQL null issues)
    name = name || "";
    mobile = mobile || "";
    area = area || "";
    landmark = landmark || "";
    pincode = pincode || "";
    state = state || "";

    // check existing default
    const [existingDefault] = await db.query(
      "SELECT id FROM addresses WHERE user_id=? AND is_default=1",
      [user_id]
    );

    const isDefault = existingDefault.length === 0 ? 1 : 0;

    const [result] = await db.query(
      `INSERT INTO addresses
      (user_id,name,mobile,address_line,area,landmark,pincode,state,latitude,longitude,is_default)
      VALUES (?,?,?,?,?,?,?,?,?,?,?)`,
      [
        user_id,
        name,
        mobile,
        address_line,
        area,
        landmark,
        pincode,
        state,
        latitude,
        longitude,
        isDefault
      ]
    );

    console.log("✅ Address inserted ID:", result.insertId);

    res.status(201).json({
      message: "Address saved successfully",
      address_id: result.insertId
    });

  } catch (err) {
    console.error("❌ SAVE ADDRESS ERROR:", err); // 🔥 FULL ERROR

    res.status(500).json({
      message: "Database error",
      error: err.message   // 🔥 show real error (for now)
    });
  }
};

/* =========================
   GET ALL
========================= */
exports.getAddresses = async (req, res) => {
  try {
    const user_id = req.params.user_id;

    const [rows] = await db.query(
      "SELECT * FROM addresses WHERE user_id=? ORDER BY is_default DESC, id DESC",
      [user_id]
    );

    res.json(rows);
  } catch (err) {
    console.error("GET ERROR:", err);
    res.status(500).json({ message: "DB error", error: err.message });
  }
};

/* =========================
   GET BY ID
========================= */
exports.getAddressById = async (req, res) => {
  try {
    const { address_id } = req.body;

    const [rows] = await db.query(
      "SELECT * FROM addresses WHERE id=?",
      [address_id]
    );

    if (!rows.length) {
      return res.status(404).json({ message: "Not found" });
    }

    res.json(rows[0]);
  } catch (err) {
    console.error("GET BY ID ERROR:", err);
    res.status(500).json({ message: "DB error", error: err.message });
  }
};

/* =========================
   SET DEFAULT
========================= */
exports.setDefaultAddress = async (req, res) => {
  try {
    const { user_id, address_id } = req.body;

    await db.query(
      "UPDATE addresses SET is_default=0 WHERE user_id=?",
      [user_id]
    );

    await db.query(
      "UPDATE addresses SET is_default=1 WHERE id=?",
      [address_id]
    );

    res.json({ message: "Default updated" });

  } catch (err) {
    console.error("SET DEFAULT ERROR:", err);
    res.status(500).json({ message: "DB error", error: err.message });
  }
};

/* =========================
   DELETE
========================= */
exports.deleteAddress = async (req, res) => {
  try {
    const id = req.params.id;

    const [rows] = await db.query(
      "SELECT user_id,is_default FROM addresses WHERE id=?",
      [id]
    );

    if (!rows.length) {
      return res.status(404).json({ message: "Not found" });
    }

    const userId = rows[0].user_id;
    const wasDefault = rows[0].is_default;

    await db.query("DELETE FROM addresses WHERE id=?", [id]);

    if (wasDefault === 1) {
      const [newDefault] = await db.query(
        "SELECT id FROM addresses WHERE user_id=? LIMIT 1",
        [userId]
      );

      if (newDefault.length > 0) {
        await db.query(
          "UPDATE addresses SET is_default=1 WHERE id=?",
          [newDefault[0].id]
        );
      }
    }

    res.json({ message: "Deleted" });

  } catch (err) {
    console.error("DELETE ERROR:", err);
    res.status(500).json({ message: "DB error", error: err.message });
  }
};