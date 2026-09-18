function notFound(_req, res) { res.status(404).json({ error: "not found" }); }
function errorHandler(err, _req, res, _next) {
  const status = err.status || 500;
  console.error("[ERROR]", err.message);
  res.status(status).json({ error: err.message || "error" });
}
module.exports = { notFound, errorHandler };
