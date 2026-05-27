const express = require("express");
const router = express.Router();
const db = require("../config/db");

/* =========================
   HELPER (CLEAN DATA)
========================= */

const formatService = (s) => {
  return {
    id: s.id,
    name: s.name || "",
    category: s.category || "",
    service_type: s.service_type || "",
    price: s.price || 0,
    price_type: s.price_type || "",
    description: s.description || "",

    duration: s.duration || "",

    /* 🔥 FIXED FIELDS */
    includes: s.includes || "",
    excludes: s.excludes || "",
    requirements: s.requirements || "",

    image: s.image || "",

    recommended: s.recommended == 1,
    active: s.active == 1,
  };
};

/* =========================
   GET ALL SERVICES (USER)
========================= */

router.get("/", async (req, res) => {
  try {

    const [rows] = await db.query(`
      SELECT *
      FROM services
      WHERE active = 1
      ORDER BY id DESC
    `);

    const data = rows.map(formatService);

    res.json({
      success: true,
      count: data.length,
      services: data
    });

  } catch (err) {
    console.error("Services Fetch Error:", err);

    res.status(500).json({
      success: false,
      message: "Failed to fetch services"
    });
  }
});

/* =========================
   GET RECOMMENDED SERVICES
========================= */

router.get("/recommended", async (req, res) => {
  try {

    const [rows] = await db.query(`
      SELECT *
      FROM services
      WHERE recommended = 1 AND active = 1
      ORDER BY id DESC
      LIMIT 5
    `);

    const data = rows.map(formatService);

    res.json({
      success: true,
      count: data.length,
      services: data
    });

  } catch (err) {
    console.error("Recommended Services Error:", err);

    res.status(500).json({
      success: false,
      message: "Failed to fetch recommended services"
    });
  }
});

/* =========================
   GET SINGLE SERVICE
========================= */

router.get("/:id", async (req, res) => {
  try {

    const [rows] = await db.query(
      "SELECT * FROM services WHERE id = ? AND active = 1",
      [req.params.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Service not found"
      });
    }

    res.json({
      success: true,
      service: formatService(rows[0])
    });

  } catch (err) {
    console.error("Single Service Error:", err);

    res.status(500).json({
      success: false,
      message: "Failed to fetch service"
    });
  }
});

module.exports = router;