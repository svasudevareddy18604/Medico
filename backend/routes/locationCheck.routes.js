const express = require("express");
const router = express.Router();

const controller = require("../controllers/locationCheck.controller");

router.post("/location/check", controller.checkLocation);

module.exports = router;