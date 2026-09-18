const express = require("express");
const pool = require("../config/db");
const auth = require("../middleware/auth");
const { calculatePrice, haversineKm } = require("../utils/pricing");
const router = express.Router();

router.get("/", auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      "SELECT o.order_id,o.status,ot.type_name,o.pickup_address_text,o.dropoff_address_text,o.distance_km,o.estimated_price,o.currency,o.created_at FROM orders o JOIN order_types ot ON ot.type_id=o.type_id WHERE o.user_id=$1 ORDER BY o.created_at DESC",
      [req.auth.sub]
    );
    res.json(rows);
  } catch (e) { next(e); }
});

router.post("/", auth, async (req, res, next) => {
  const b = req.body;
  const req_fields = ["type_id","pickup_lat","pickup_lng","dropoff_lat","dropoff_lng"];
  if (req_fields.some((k) => b[k] === undefined || b[k] === null))
    return res.status(400).json({ error: "بيانات ناقصة" });
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const distance_km = haversineKm(b.pickup_lat, b.pickup_lng, b.dropoff_lat, b.dropoff_lng);
    const { amount: estimated_price, currency } = calculatePrice({ distanceKm: distance_km, currency: b.currency || "SDG" });
    const { rows } = await client.query(
      "INSERT INTO orders(user_id,type_id,pickup_lat,pickup_lng,pickup_address_text,dropoff_lat,dropoff_lng,dropoff_address_text,notes,distance_km,estimated_price,currency,status) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,'pending') RETURNING *",
      [req.auth.sub, b.type_id, b.pickup_lat, b.pickup_lng, b.pickup_address_text || null, b.dropoff_lat, b.dropoff_lng, b.dropoff_address_text || null, b.notes || null, Number(distance_km.toFixed(2)), estimated_price, currency]
    );
    await client.query(
      "INSERT INTO order_status_log(order_id,status,changed_by,changed_by_id,notes) VALUES($1,'pending','customer',$2,'إنشاء الطلب')",
      [rows[0].order_id, req.auth.sub]
    );
    await client.query("COMMIT");
    res.status(201).json(rows[0]);
  } catch (e) {
    await client.query("ROLLBACK");
    next(e);
  } finally { client.release(); }
});

router.get("/:id", auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      "SELECT o.*,ot.type_name FROM orders o JOIN order_types ot ON ot.type_id=o.type_id WHERE o.order_id=$1 AND o.user_id=$2",
      [req.params.id, req.auth.sub]
    );
    if (!rows[0]) return res.status(404).json({ error: "غير موجود" });
    const log = await pool.query("SELECT status,changed_by,notes,changed_at FROM order_status_log WHERE order_id=$1 ORDER BY changed_at ASC", [req.params.id]);
    res.json({ order: rows[0], status_log: log.rows });
  } catch (e) { next(e); }
});

router.post("/:id/cancel", auth, async (req, res, next) => {
  try {
    const q = await pool.query(
      "UPDATE orders SET status='cancelled' WHERE order_id=$1 AND user_id=$2 AND status IN ('pending','accepted') RETURNING order_id,status",
      [req.params.id, req.auth.sub]
    );
    if (!q.rowCount) return res.status(400).json({ error: "لا يمكن الإلغاء" });
    res.json(q.rows[0]);
  } catch (e) { next(e); }
});

module.exports = router;
