const express = require("express");
const router = express.Router();
router.use("/auth", require("./auth.routes"));
router.use("/orders", require("./orders.routes"));
router.use("/driver", require("./driver.routes"));
router.use("/wallet", require("./wallet.routes"));
router.use("/vendor", require("./vendor.routes"));
module.exports = router;
