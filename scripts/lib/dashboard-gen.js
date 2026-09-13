#!/usr/bin/env node
/**
 * dashboard-gen.js
 * -----------------
 * Reads versions.json and prints a text table (stdout, for the terminal
 * report) matching the spec's example format:
 *   Environment | Version | Status | Last Deployment
 * Also emits an HTML version to stdout when called with --html, used by
 * dashboard.sh to write a browsable dashboard.html.
 */

const fs = require('fs');
const path = require('path');

const VERSIONS_FILE = path.join(__dirname, '..', '..', 'versions', 'versions.json');
const ENVIRONMENTS = ['development', 'staging', 'production'];

function load() {
  if (!fs.existsSync(VERSIONS_FILE)) return { deployments: [] };
  try {
    return JSON.parse(fs.readFileSync(VERSIONS_FILE, 'utf8'));
  } catch (e) {
    return { deployments: [] };
  }
}

function latestFor(data, env) {
  const records = data.deployments.filter((d) => d.environment === env);
  return records.length ? records[records.length - 1] : null;
}

function statusLabel(record) {
  if (!record) return 'Not deployed';
  const map = { success: 'Running Latest', failed: 'Deployment Failed', rolled_back: 'Rolled Back' };
  return map[record.status] || record.status;
}

const data = load();
const rows = ENVIRONMENTS.map((env) => {
  const rec = latestFor(data, env);
  return {
    environment: env.charAt(0).toUpperCase() + env.slice(1),
    version: rec ? rec.version : '-',
    build: rec ? rec.build : '-',
    status: statusLabel(rec),
    lastDeployment: rec ? rec.timestamp : '-',
  };
});

const asHtml = process.argv.includes('--html');

if (asHtml) {
  const rowsHtml = rows
    .map(
      (r) => `      <tr>
        <td>${r.environment}</td>
        <td>${r.version}</td>
        <td>${r.build}</td>
        <td class="status-${r.status.replace(/\s+/g, '-').toLowerCase()}">${r.status}</td>
        <td>${r.lastDeployment}</td>
      </tr>`
    )
    .join('\n');
  console.log(`<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<title>XQORA Deployment Dashboard</title>
<style>
  body { font-family: -apple-system, Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 0 20px; color: #222; }
  h1 { color: #1a4d8f; font-size: 22px; }
  table { border-collapse: collapse; width: 100%; margin-top: 16px; }
  th, td { border: 1px solid #ddd; padding: 10px 12px; text-align: left; font-size: 14px; }
  th { background: #1a4d8f; color: white; }
  .status-running-latest { color: #1a7f37; font-weight: bold; }
  .status-deployment-failed { color: #cf222e; font-weight: bold; }
  .status-rolled-back { color: #d99a00; font-weight: bold; }
  .status-not-deployed { color: #6c757d; }
  .generated { color: #777; font-size: 12px; margin-top: 12px; }
</style>
</head>
<body>
  <h1>XQORA Multi-Environment Deployment Dashboard</h1>
  <table>
    <thead>
      <tr><th>Environment</th><th>Version</th><th>Build</th><th>Status</th><th>Last Deployment</th></tr>
    </thead>
    <tbody>
${rowsHtml}
    </tbody>
  </table>
  <p class="generated">Generated ${new Date().toISOString()}</p>
</body>
</html>`);
} else {
  const pad = (s, n) => String(s).padEnd(n);
  console.log(pad('Environment', 13) + pad('Version', 10) + pad('Build', 7) + pad('Status', 18) + 'Last Deployment');
  console.log('-'.repeat(13) + '-'.repeat(10) + '-'.repeat(7) + '-'.repeat(18) + '-'.repeat(24));
  rows.forEach((r) => {
    console.log(pad(r.environment, 13) + pad(r.version, 10) + pad(r.build, 7) + pad(r.status, 18) + r.lastDeployment);
  });
}
