require("dotenv").config();
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const pool = require("./config/db");
const routes = require("./routes");
const { notFound, errorHandler } = require("./middleware/errorHandler");

const app = express();
const port = Number(process.env.PORT || 3000);

app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors({ origin: process.env.CORS_ORIGIN || "*" }));
app.use(express.json({ limit: "1mb" }));
app.use(express.static("public"));

app.get("/", (_req, res) => res.redirect("/enter.html"));

app.get("/api/health", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ ok: true, database: "connected", version: "3.0" });
  } catch (e) {
    res.status(503).json({ ok: false, database: "unavailable", error: e.message });
  }
});

app.get("/api/order-types", async (_req, res, next) => {
  try {
    const { rows } = await pool.query("SELECT type_id,type_name FROM order_types ORDER BY type_id");
    res.json(rows);
  } catch (e) { next(e); }
});

app.use("/api", routes);

app.use(notFound);
app.use(errorHandler);

app.listen(port, "0.0.0.0", () => console.log("Thunder API running on http://localhost:" + port));
