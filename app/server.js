const express = require("express");
const { v4: uuidv4 } = require("uuid");

const app = express();
const PORT = process.env.PORT || 3000;

function log(level, message, fields = {}) {
  const entry = {
    timestamp: new Date().toISOString(),
    level,
    message,
    ...fields,
  };
  process.stdout.write(JSON.stringify(entry) + "\n");
}

app.use((req, res, next) => {
  req.requestId = req.headers["x-request-id"] || uuidv4();
  res.setHeader("x-request-id", req.requestId);

  const amznTraceId = req.headers["x-amzn-trace-id"] || "";
  const rootMatch = amznTraceId.match(/Root=([^;]+)/);
  req.awsRootTraceId = rootMatch ? rootMatch[1] : null;

  const start = Date.now();

  res.on("finish", () => {
    log("info", "request completed", {
      requestId: req.requestId,
      awsRootTraceId: req.awsRootTraceId,
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      durationMs: Date.now() - start,
      userAgent: req.headers["user-agent"],
      ip: req.headers["x-forwarded-for"] || req.socket.remoteAddress,
    });
  });

  next();
});

app.use(express.json());

app.get("/health", (req, res) => {
  log("debug", "health check", { requestId: req.requestId });
  res.json({ status: "healthy", requestId: req.requestId });
});

app.get("/", (req, res) => {
  log("info", "root endpoint hit", { requestId: req.requestId });
  res.json({
    service: "observe-demo-app",
    version: "1.0.0",
    requestId: req.requestId,
  });
});

app.get("/api/items", (req, res) => {
  const items = [
    { id: 1, name: "Widget A" },
    { id: 2, name: "Widget B" },
    { id: 3, name: "Widget C" },
  ];
  log("info", "items fetched", { requestId: req.requestId, count: items.length });
  res.json({ items, requestId: req.requestId });
});

app.post("/api/items", (req, res) => {
  const { name } = req.body || {};
  if (!name) {
    log("warn", "missing item name", { requestId: req.requestId });
    return res.status(400).json({ error: "name is required", requestId: req.requestId });
  }
  log("info", "item created", { requestId: req.requestId, name });
  res.status(201).json({ id: 4, name, requestId: req.requestId });
});

app.get("/api/slow", (req, res) => {
  const delayMs = parseInt(req.query.delay, 10) || 2000;
  log("info", "slow endpoint called", { requestId: req.requestId, delayMs });
  setTimeout(() => {
    res.json({ message: "slow response", delayMs, requestId: req.requestId });
  }, delayMs);
});

app.get("/api/error", (req, res) => {
  const rate = parseInt(req.query.rate, 10) || 50;
  if (Math.random() * 100 < rate) {
    log("error", "simulated error", { requestId: req.requestId, rate });
    return res.status(500).json({ error: "simulated failure", requestId: req.requestId });
  }
  log("info", "error endpoint succeeded", { requestId: req.requestId, rate });
  res.json({ message: "success", requestId: req.requestId });
});

app.use((req, res) => {
  log("warn", "not found", { requestId: req.requestId, path: req.path });
  res.status(404).json({ error: "not found", requestId: req.requestId });
});

app.listen(PORT, () => {
  log("info", `server started on port ${PORT}`);
});
