const rateLimit = require("express-rate-limit");
const authLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 10 });
const apiLimiter = rateLimit({ windowMs: 60 * 1000, max: 120 });
const sosLimiter = rateLimit({ windowMs: 5 * 60 * 1000, max: 5 });
module.exports = { authLimiter, apiLimiter, sosLimiter };
