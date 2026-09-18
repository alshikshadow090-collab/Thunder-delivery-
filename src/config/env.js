require("dotenv").config();

function required(name) {
  const v = process.env[name];
  if (!v) throw new Error("متغير البيئة مفقود: " + name);
  return v;
}

const env = {
  nodeEnv: process.env.NODE_ENV || "development",
  port: Number(process.env.PORT || 3000),
  databaseUrl: required("DATABASE_URL"),
  jwtSecret: required("JWT_SECRET"),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || "7d",
  corsOrigin: process.env.CORS_ORIGIN || "*",
  logLevel: process.env.LOG_LEVEL || "info",
  pricing: {
    baseFare: Number(process.env.BASE_FARE || 500),
    perKmRate: Number(process.env.PER_KM_RATE || 250),
    perMinuteRate: Number(process.env.PER_MINUTE_RATE || 50),
    minFare: Number(process.env.MIN_FARE || 1000),
    surgeMultiplier: Number(process.env.SURGE_MULTIPLIER || 1.0),
  },
};

if (env.jwtSecret.length < 32) {
  throw new Error("JWT_SECRET يجب أن يكون 32 حرفاً على الأقل");
}

module.exports = env;