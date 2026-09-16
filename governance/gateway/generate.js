#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

const VALID_METHODS = new Set([
  'get',
  'put',
  'post',
  'delete',
  'patch',
  'head',
  'options',
  'trace',
]);

function loadContract(contractPath) {
  const raw = fs.readFileSync(contractPath, 'utf8');
  return yaml.load(raw);
}

function loadBaseConfig(basePath) {
  const raw = fs.readFileSync(basePath, 'utf8');
  return JSON.parse(raw);
}

function buildEndpoints(contract, backendHost) {
  const endpoints = [];
  const paths = (contract && contract.paths) || {};
  for (const [pathKey, pathItem] of Object.entries(paths)) {
    for (const [method, operation] of Object.entries(pathItem || {})) {
      if (!VALID_METHODS.has(method)) continue;
      if (!operation || typeof operation !== 'object') continue;
      endpoints.push({
        endpoint: pathKey,
        method: method.toUpperCase(),
        output_encoding: 'no-op',
        backend: [
          {
            url_pattern: pathKey,
            method: method.toUpperCase(),
            host: [backendHost],
            encoding: 'no-op',
          },
        ],
      });
    }
  }
  return endpoints;
}

function generate(contractPath, basePath, backendHost) {
  const contract = loadContract(contractPath);
  const base = loadBaseConfig(basePath);
  const endpoints = buildEndpoints(contract, backendHost);
  if (endpoints.length === 0) {
    throw new Error(
      'No operations found in contract — refusing to generate an empty gateway config'
    );
  }
  return { ...base, endpoints };
}

function main() {
  const [, , contractPath, outputPath, backendHostArg] = process.argv;
  if (!contractPath || !outputPath) {
    console.error('Usage: node generate.js <contract.yaml> <output.json> [backendHost]');
    process.exit(1);
  }
  const backendHost = backendHostArg || 'http://sample-backend:8081';
  const basePath = path.join(__dirname, 'krakend-base.json');
  const config = generate(contractPath, basePath, backendHost);
  fs.writeFileSync(outputPath, JSON.stringify(config, null, 2));
  console.log(`Wrote ${outputPath} with ${config.endpoints.length} endpoint(s).`);
}

if (require.main === module) {
  main();
}

module.exports = { buildEndpoints, generate };
