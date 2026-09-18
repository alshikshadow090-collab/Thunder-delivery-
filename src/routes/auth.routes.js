const express = require("express");
const bcrypt = require("bcryptjs");
const pool = require("../config/db");
const { signToken } = require("../utils/jwt");
const { authLimiter } = require("../middleware/rateLimiter");
const auth = require("../middleware/auth");
const router = express.Router();

router.post("/register", authLimiter, async (req, res, next) => {
  const { full_name, phone, password, email } = req.body;
  if (!full_name || !phone || !password || password.length < 6)
    return res.status(400).json({ error: "بيانات ناقصة" });
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const hash = await bcrypt.hash(password, 12);
    const { rows } = await client.query(
      "INSERT INTO users(full_name,phone,email,password_hash) VALUES($1,$2,$3,$4) RETURNING user_id,full_name,phone,email",
      [full_name, phone, email || null, hash]
    );
    await client.query("INSERT INTO wallets(user_id) VALUES($1) ON CONFLICT DO NOTHING", [rows[0].user_id]);
    await client.query("INSERT INTO loyalty_accounts(user_id) VALUES($1) ON CONFLICT DO NOTHING", [rows[0].user_id]);
    await client.query("COMMIT");
    res.status(201).json({ user: rows[0], token: signToken(rows[0]) });
  } catch (e) {
    await client.query("ROLLBACK");
    if (e.code === "23505") return res.status(409).json({ error: "مستخدم موجود" });
    next(e);
  } finally { client.release(); }
});

router.post("/login", authLimiter, async (req, res, next) => {
  try {
    const { phone, password } = req.body;
    if (!phone || !password) return res.status(400).json({ error: "بيانات ناقصة" });
    const { rows } = await pool.query(
      "SELECT * FROM users WHERE phone=$1 AND deleted_at IS NULL AND is_active=true",
      [phone]
    );
    const u = rows[0];
    if (!u || !(await bcrypt.compare(password, u.password_hash)))
      return res.status(401).json({ error: "بيانات غير صحيحة" });
    res.json({
      user: { user_id: u.user_id, full_name: u.full_name, phone: u.phone, email: u.email },
      token: signToken(u),
    });
  } catch (e) { next(e); }
});

router.get("/me", auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      "SELECT user_id,full_name,phone,email,is_active,created_at FROM users WHERE user_id=$1",
      [req.auth.sub]
    );
    if (!rows[0]) return res.status(404).json({ error: "غير موجود" });
    res.json(rows[0]);
  } catch (e) { next(e); }
});

module.exports = router;
