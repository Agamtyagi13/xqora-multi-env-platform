/**
 * XQORA Multi-Environment Demo Application
 * ------------------------------------------
 * Satisfies the "Demo Application" requirement:
 *   - Basic frontend interface     -> /public/index.html (shows version + env live)
 *   - Backend/API service          -> /api/info
 *   - Health-check endpoint        -> /health
 *   - Version info on the app      -> displayed on homepage, /api/info, /health
 *
 * The SAME application/image is deployed to all three environments; only
 * configuration (env vars) differs between them - nothing in this file is
 * environment-specific.
 */

const express = require('express');
const os = require('os');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const APP_VERSION = process.env.APP_VERSION || '1.0.0';
const BUILD_NUMBER = process.env.BUILD_NUMBER || '0';
const ENVIRONMENT = process.env.ENVIRONMENT || 'development';
const LOG_LEVEL = process.env.LOG_LEVEL || 'info';
const START_TIME = Date.now();

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// ---- Health check (used by deploy.sh / rollback.sh / monitor.sh) ----
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'UP',
    version: APP_VERSION,
    build: BUILD_NUMBER,
    environment: ENVIRONMENT,
    uptime_seconds: Math.floor((Date.now() - START_TIME) / 1000),
    hostname: os.hostname(),
    timestamp: new Date().toISOString()
  });
});

// ---- Version + environment info (drives the "version displayed on the
// application" requirement, and is what promote.sh/dashboard.sh read
// live to cross-check against the version manifest) ----
app.get('/api/info', (req, res) => {
  res.json({
    app: 'xqora-multi-env-app',
    version: APP_VERSION,
    build: BUILD_NUMBER,
    environment: ENVIRONMENT,
    log_level: LOG_LEVEL,
    message: `Running version ${APP_VERSION} (build ${BUILD_NUMBER}) in ${ENVIRONMENT}`
  });
});

app.listen(PORT, () => {
  console.log(`[${ENVIRONMENT}] xqora-multi-env-app v${APP_VERSION} (build ${BUILD_NUMBER}) listening on port ${PORT}`);
});
