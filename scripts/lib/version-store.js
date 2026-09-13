#!/usr/bin/env node
/**
 * version-store.js
 * -----------------
 * Small dependency-free CLI backing the "Version Management System"
 * requirement. Reads/writes versions/versions.json, which is the single
 * source of truth for: application version, build number, deployment
 * date/time, environment deployed to, and deployment status - for every
 * deployment ever made, across all three environments.
 *
 * Usage:
 *   node version-store.js init
 *   node version-store.js record <environment> <version> <build> <status> [note]
 *   node version-store.js current <environment>          -> JSON of latest record
 *   node version-store.js previous-stable <environment>  -> JSON of most recent
 *                                                            "success" record that
 *                                                            is NOT the current one
 *   node version-store.js history <environment> [n]      -> JSON array, most recent n
 *   node version-store.js all                             -> JSON array, every record
 */

const fs = require('fs');
const path = require('path');

const VERSIONS_FILE = path.join(__dirname, '..', '..', 'versions', 'versions.json');

function load() {
  if (!fs.existsSync(VERSIONS_FILE)) {
    return { deployments: [] };
  }
  try {
    return JSON.parse(fs.readFileSync(VERSIONS_FILE, 'utf8'));
  } catch (err) {
    return { deployments: [] };
  }
}

function save(data) {
  fs.mkdirSync(path.dirname(VERSIONS_FILE), { recursive: true });
  fs.writeFileSync(VERSIONS_FILE, JSON.stringify(data, null, 2));
}

function envRecords(data, environment) {
  return data.deployments.filter((d) => d.environment === environment);
}

const [, , cmd, ...args] = process.argv;

switch (cmd) {
  case 'init': {
    if (!fs.existsSync(VERSIONS_FILE)) {
      save({ deployments: [] });
      console.log('Initialized empty version manifest at', VERSIONS_FILE);
    } else {
      console.log('Version manifest already exists at', VERSIONS_FILE);
    }
    break;
  }

  case 'record': {
    const [environment, version, build, status, note] = args;
    if (!environment || !version || !build || !status) {
      console.error('Usage: record <environment> <version> <build> <status> [note]');
      process.exit(1);
    }
    const data = load();
    data.deployments.push({
      environment,
      version,
      build: Number(build),
      status, // 'success' | 'failed' | 'rolled_back'
      timestamp: new Date().toISOString(),
      note: note || '',
    });
    save(data);
    console.log(JSON.stringify(data.deployments[data.deployments.length - 1], null, 2));
    break;
  }

  case 'current': {
    const [environment] = args;
    const data = load();
    const records = envRecords(data, environment);
    if (records.length === 0) {
      console.log('null');
      break;
    }
    console.log(JSON.stringify(records[records.length - 1], null, 2));
    break;
  }

  case 'previous-stable': {
    const [environment] = args;
    const data = load();
    const records = envRecords(data, environment);
    if (records.length < 1) {
      console.log('null');
      break;
    }
    // Exclude the very latest record (the one presumed to have failed),
    // then find the most recent successful deployment before it.
    const currentVersion = records[records.length - 1].version;
    const candidates = records
      .slice(0, -1)
      .filter((r) => r.status === 'success' || r.status === 'rolled_back')
      .filter((r) => r.version !== currentVersion);
    if (candidates.length === 0) {
      console.log('null');
      break;
    }
    console.log(JSON.stringify(candidates[candidates.length - 1], null, 2));
    break;
  }

  case 'history': {
    const [environment, n] = args;
    const data = load();
    const records = envRecords(data, environment);
    const limit = n ? Number(n) : 10;
    console.log(JSON.stringify(records.slice(-limit), null, 2));
    break;
  }

  case 'all': {
    const data = load();
    console.log(JSON.stringify(data.deployments, null, 2));
    break;
  }

  default:
    console.error('Unknown command. Usage: init | record | current | previous-stable | history | all');
    process.exit(1);
}
