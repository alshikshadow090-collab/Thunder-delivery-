#!/bin/bash
cd /public/thunder-delivery

echo "Creating config/db.js..."
cat > src/config/db.js << 'EOF'
const { Pool } = require("pg");
const env = require("./env");

const pool = new Pool({
  connectionString: env.databaseUrl,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pool.on("error", (err) => console.error("Unexpected PG error", err));

module.exports = pool;
EOF

echo "Creating utils/jwt.js..."
cat > src/utils/jwt.js << 'EOF'
const jwt = require("jsonwebtoken");
const env = require("../config/env");

function signToken(user) {
  return jwt.sign(
    { sub: String(user.user_id), role: "customer", phone: user.phone },
    env.jwtSecret,
    { expiresIn: env.jwtExpiresIn }
  );
}

function verifyToken(token) {
  return jwt.verify(token, env.jwtSecret);
}

module.exports = { signToken, verifyToken };
EOF

echo "Creating utils/pricing.js..."
cat > src/utils/pricing.js << 'EOF'
const env = require("../config/env");

function calculatePrice({ distanceKm, durationMin = 0, currency = "SDG", surge }) {
  const { baseFare, perKmRate, perMinuteRate, minFare, surgeMultiplier } = env.pricing;
  const s = surge || surgeMultiplier;
  const raw = baseFare + perKmRate * Number(distanceKm) + perMinuteRate * Number(durationMin);
  const total = Math.max(raw * s, minFare);
  return { amount: Math.round(total), currency };
}

function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat/2)**2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng/2)**2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

module.exports = { calculatePrice, haversineKm };
EOF

echo "Creating middleware/auth.js..."
cat > src/middleware/auth.js << 'EOF'
const { verifyToken } = require("../utils/jwt");
const pool = require("../config/db");

async function auth(req, res, next) {
  try {
    const header = req.headers.authorization || "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : null;
    if (!token) return res.status(401).json({ error: "تسجيل الدخول مطلوب" });

    let payload;
    try {
      payload = verifyToken(token);
    } catch {
      return res.status(401).json({ error: "رمز الدخول غير صالح أو منتهي" });
    }

    const { rows } = await pool.query(
      "SELECT user_id, is_active, deleted_at FROM users WHERE user_id=$1",
      [payload.sub]
    );
    const user = rows[0];
    if (!user || user.deleted_at || !user.is_active) {
      return res.status(403).json({ error: "الحساب غير مفعل" });
    }

    req.auth = payload;
    next();
  } catch (e) {
    next(e);
  }
}

module.exports = auth;
EOF

echo "Creating middleware/rateLimiter.js..."
cat > src/middleware/rateLimiter.js << 'EOF'
const rateLimit = require("express-rate-limit");

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { error: "محاولات كثيرة جداً" },
});

const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 120,
  message: { error: "تجاوزت الحد المسموح" },
});

const sosLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,
  max: 5,
  message: { error: "عدد تنبيهات SOS كبير" },
});

module.exports = { authLimiter, apiLimiter, sosLimiter };
EOF

echo "Creating middleware/errorHandler.js..."
cat > src/middleware/errorHandler.js << 'EOF'
function notFound(_req, res) {
  res.status(404).json({ error: "المسار غير موجود" });
}

function errorHandler(err, _req, res, _next) {
  const status = err.status || 500;
  const isProd = process.env.NODE_ENV === "production";
  console.error("[ERROR]", err.message);
  res.status(status).json({
    error: isProd && status >= 500 ? "خطأ داخلي" : (err.message || "خطأ غير معروف"),
  });
}

module.exports = { notFound, errorHandler };
EOF

echo ""
echo "✅ تم إنشاء 6 ملفات بنجاح!"
ls -la src/config/ src/utils/ src/middleware/
