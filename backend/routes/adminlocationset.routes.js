const express = require("express");
const router = express.Router();
const db = require("../config/db");

/* ================= STATES ================= */

const statesList = [
  "Andhra Pradesh","Karnataka","Telangana","Tamil Nadu","Maharashtra",
  "Kerala","Delhi","Uttar Pradesh","West Bengal","Gujarat", "Goa", "Punjab"
];

/* ================= SAFE PARSE ================= */

function safeParse(value) {
  try {
    if (!value) return [];
    if (typeof value === "string") return JSON.parse(value);
    return value;
  } catch {
    return [];
  }
}

/* ================= GET CURRENT ACTIVE ================= */

router.get("/admin/location", async (req, res) => {
  try {
    const [rows] = await db.query(
      "SELECT * FROM admin_location_settings WHERE is_active = 1 LIMIT 1"
    );

    let config = {
      mode: "ALL_INDIA",
      states: [],
      areas: [],
      pincodes: []
    };

    if (rows.length > 0) {
      const d = rows[0];
      config = {
        mode: d.mode,
        states: safeParse(d.states),
        areas: safeParse(d.areas),
        pincodes: safeParse(d.pincodes)
      };
    }

    res.json({
      ...config,
      statesList
    });

  } catch (e) {
    res.status(500).json({ message: "Server error" });
  }
});

/* ================= GET ALL SAVED ================= */

router.get("/admin/location/all", async (req, res) => {
  try {
    const [rows] = await db.query(
      "SELECT * FROM admin_location_settings ORDER BY id DESC"
    );

    const data = rows.map(r => ({
      id: r.id,
      mode: r.mode,
      states: safeParse(r.states),
      areas: safeParse(r.areas),
      pincodes: safeParse(r.pincodes),
      is_active: r.is_active
    }));

    res.json(data);

  } catch (e) {
    res.status(500).json({ message: "Server error" });
  }
});

/* ================= CREATE / SAVE ================= */

router.post("/admin/location", async (req, res) => {
  try {
    const { mode, states, areas, pincodes } = req.body;

    if (!mode) {
      return res.status(400).json({ message: "Mode required" });
    }

    if (mode === "STATE" && (!states || states.length === 0)) {
      return res.status(400).json({ message: "Select at least 1 state" });
    }

    if (mode === "CUSTOM" && (!states || states.length === 0)) {
      return res.status(400).json({ message: "State required" });
    }

    await db.query("UPDATE admin_location_settings SET is_active = 0");

    await db.query(
      `INSERT INTO admin_location_settings 
      (mode, states, areas, pincodes, is_active) 
      VALUES (?, ?, ?, ?, 1)`,
      [
        mode,
        JSON.stringify(states || []),
        JSON.stringify(areas || []),
        JSON.stringify(pincodes || [])
      ]
    );

    res.json({ message: "Saved successfully" });

  } catch (e) {
    res.status(500).json({ message: "Server error" });
  }
});

/* ================= UPDATE ================= */

router.put("/admin/location/:id", async (req, res) => {
  try {
    const id = req.params.id;
    const { mode, states, areas, pincodes } = req.body;

    await db.query(
      `UPDATE admin_location_settings 
       SET mode=?, states=?, areas=?, pincodes=? 
       WHERE id=?`,
      [
        mode,
        JSON.stringify(states || []),
        JSON.stringify(areas || []),
        JSON.stringify(pincodes || []),
        id
      ]
    );

    res.json({ message: "Updated successfully" });

  } catch (e) {
    res.status(500).json({ message: "Server error" });
  }
});

/* ================= DELETE ================= */

router.delete("/admin/location/:id", async (req, res) => {
  try {
    const id = req.params.id;

    await db.query(
      "DELETE FROM admin_location_settings WHERE id=?",
      [id]
    );

    res.json({ message: "Deleted successfully" });

  } catch (e) {
    res.status(500).json({ message: "Server error" });
  }
});

/* ================= ACTIVATE ================= */

router.put("/admin/location/activate/:id", async (req, res) => {
  try {
    const id = req.params.id;

    await db.query("UPDATE admin_location_settings SET is_active = 0");

    await db.query(
      "UPDATE admin_location_settings SET is_active = 1 WHERE id=?",
      [id]
    );

    res.json({ message: "Activated" });

  } catch (e) {
    res.status(500).json({ message: "Server error" });
  }
});

module.exports = router;