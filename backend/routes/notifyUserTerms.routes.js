const express = require("express");
const router = express.Router();

const { notifyTermsUpdate } = require("../controllers/notifyUserTerms.controller");

/*
  POST /api/admin/notify-terms-update
  body: { audience: "both" | "careseekers" | "caretakers" }
*/
router.post("/notify-terms-update", notifyTermsUpdate);

module.exports = router;