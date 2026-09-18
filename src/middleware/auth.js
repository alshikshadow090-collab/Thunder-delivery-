const { verifyToken } = require("../utils/jwt");
const pool = require("../config/db");
async function auth(req, res, next) {
  try {
    const header = req.headers.authorization || "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : null;
    if (!token) return res.status(401).json({ error: "تسجيل الدخول مطلوب" });
    let payload;
    try { payload = verifyToken(token); }
    catch { return res.status(401).json({ error: "رمز غير صالح" }); }
    const { rows } = await pool.query("SELECT user_id, is_active, deleted_at FROM users WHERE user_id=$1", [payload.sub]);
    const user = rows[0];
    if (!user || user.deleted_at || !user.is_active) return res.status(403).json({ error: "الحساب غير مفعل" });
    req.auth = payload;
    next();
  } catch (e) { next(e); }
}
module.exports = auth;
