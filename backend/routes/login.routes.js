const express = require("express");
const router = express.Router();

const auth = require("../controllers/auth.controller");

/* =========================
   LOGIN (USER / ADMIN)
========================= */

router.post("/login", async (req, res, next) => {

  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({
      message: "Email and password required"
    });
  }

  try {

    // continue to controller
    next();

  } catch (error) {

    return res.status(500).json({
      message: "Login validation error"
    });

  }

}, auth.login);


/* =========================
   EXPORT ROUTER
========================= */

module.exports = router;