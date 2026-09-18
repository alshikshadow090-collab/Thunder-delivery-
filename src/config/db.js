const { Pool } = require("pg");
const env = require("./env");
const pool = new Pool({ connectionString: env.databaseUrl, max: 20 });
pool.on("error", (err) => console.error("PG error:", err));
module.exports = pool;
