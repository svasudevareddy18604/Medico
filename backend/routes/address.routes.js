const express = require("express");
const router = express.Router();
const controller = require("../controllers/address.controller");

router.post("/save", controller.saveAddress);
router.get("/:user_id", controller.getAddresses);
router.post("/getById", controller.getAddressById);
router.post("/set-default", controller.setDefaultAddress); // ✅ use POST
router.delete("/delete/:id", controller.deleteAddress);

module.exports = router;