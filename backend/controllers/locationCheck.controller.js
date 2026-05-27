const db = require("../config/db");

/* ================= LOCATION CHECK ================= */

exports.checkLocation = async (req, res) => {
  try {
    const { pincode, area, state } = req.body;

    if (!pincode && !area && !state) {
      return res.status(400).json({
        allowed: false,
        message: "Location data required"
      });
    }

    // get active config
    const [rows] = await db.query(
      "SELECT * FROM admin_location_settings WHERE is_active=1 LIMIT 1"
    );

    if (rows.length === 0) {
      return res.json({ allowed: true }); // no restriction
    }

    const config = rows[0];

    const mode = config.mode;
    const states = safeParse(config.states);
    const areas = safeParse(config.areas);
    const pincodes = safeParse(config.pincodes);

    /* ================= LOGIC ================= */

    // ✅ ALL INDIA
    if (mode === "ALL_INDIA") {
      return res.json({ allowed: true });
    }

    // ✅ STATE
    if (mode === "STATE") {
      if (states.includes(state)) {
        return res.json({ allowed: true });
      } else {
        return res.json({
          allowed: false,
          message: `Service not available in ${state}`
        });
      }
    }

    // ✅ CUSTOM
    if (mode === "CUSTOM") {

      if (states.length && !states.includes(state)) {
        return res.json({
          allowed: false,
          message: `Service not available in ${state}`
        });
      }

      if (areas.includes(area) || pincodes.includes(pincode)) {
        return res.json({ allowed: true });
      }

      return res.json({
        allowed: false,
        message: "Service not available in your area"
      });
    }

    res.json({ allowed: true });

  } catch (err) {
    console.log(err);
    res.status(500).json({ message: "Server error" });
  }
};

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