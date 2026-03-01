#!/usr/bin/env node

// Launches real Chrome, navigates to a realtor.ca search URL, and intercepts
// the PropertySearch_Post API responses via CDP Network domain. Paginates
// through all result pages by clicking the "next page" button.
//
// Incapsula validates cookies AND TLS fingerprint — extracting cookies and
// replaying them with curl/Req/Mint fails because those HTTP clients have a
// different TLS fingerprint than Chrome. The only reliable approach is to let
// Chrome make the request itself and intercept the response.
//
// Usage: node scripts/get_listings.mjs '<URL-encoded form body>' [output-file]
// Outputs: JSON written to output-file (or stdout if not specified).
//          Diagnostics always go to stderr.

import { execSync, spawn } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import http from "node:http";

const FORM_BODY = process.argv[2];
const OUTPUT_FILE = process.argv[3]; // optional: write JSON here instead of stdout
if (!FORM_BODY) {
  process.stderr.write("Usage: node get_listings.mjs '<form body>' [output-file]\n");
  process.exit(1);
}

const CDP_PORT = 9333;
const PROFILE_DIR = "/tmp/chrome-realtor";
const TIMEOUT_MS = 120_000;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function findChrome() {
  if (process.env.CHROME_BIN) return process.env.CHROME_BIN;
  const candidates = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/usr/bin/google-chrome-stable",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium-browser",
    "/usr/bin/chromium",
  ];
  for (const p of candidates) {
    try {
      execSync(`test -x "${p}"`, { stdio: "ignore" });
      return p;
    } catch {
      continue;
    }
  }
  throw new Error("Chrome not found. Install Google Chrome or set CHROME_BIN.");
}

function isContainer() {
  try {
    execSync("test -f /.dockerenv", { stdio: "ignore" });
    return true;
  } catch {
    return !process.env.DISPLAY && !process.env.WAYLAND_DISPLAY;
  }
}

function ensureDisplay() {
  if (process.env.DISPLAY) return () => {};
  if (!isContainer()) return () => {};

  const display = `:${99 + Math.floor(Math.random() * 100)}`;
  const xvfb = spawn("Xvfb", [display, "-screen", "0", "1280x720x24", "-ac"], {
    stdio: "ignore",
    detached: true,
  });
  xvfb.unref();
  execSync("sleep 0.5");
  process.env.DISPLAY = display;
  process.stderr.write(`Xvfb started on ${display}\n`);
  return () => {
    try {
      xvfb.kill("SIGTERM");
    } catch {}
  };
}

function cdpFetch(path) {
  return new Promise((resolve, reject) => {
    http
      .get(`http://127.0.0.1:${CDP_PORT}${path}`, { timeout: 5000 }, (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          try {
            resolve(JSON.parse(data));
          } catch {
            reject(new Error(`Bad JSON from CDP: ${data.slice(0, 200)}`));
          }
        });
      })
      .on("error", reject);
  });
}

async function waitForCDP(retries = 20) {
  for (let i = 0; i < retries; i++) {
    try {
      await cdpFetch("/json/version");
      return;
    } catch {
      await new Promise((r) => setTimeout(r, 500));
    }
  }
  throw new Error("CDP not ready after timeout");
}

// ---------------------------------------------------------------------------
// CDP session with event listener support
// ---------------------------------------------------------------------------

class CDPSession {
  constructor(wsUrl) {
    this._ws = new WebSocket(wsUrl);
    this._id = 0;
    this._pending = new Map();
    this._listeners = [];
    this._ready = new Promise((r) => {
      this._ws.onopen = r;
    });

    this._ws.onmessage = (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id !== undefined && this._pending.has(msg.id)) {
        const { resolve, reject } = this._pending.get(msg.id);
        this._pending.delete(msg.id);
        if (msg.error) reject(new Error(msg.error.message));
        else resolve(msg.result);
      }
      if (msg.method) {
        for (const fn of this._listeners) fn(msg.method, msg.params);
      }
    };
  }

  async send(method, params = {}) {
    await this._ready;
    const id = ++this._id;
    return new Promise((resolve, reject) => {
      this._pending.set(id, { resolve, reject });
      this._ws.send(JSON.stringify({ id, method, params }));
      setTimeout(() => {
        if (this._pending.has(id)) {
          this._pending.delete(id);
          reject(new Error(`CDP timeout: ${method}`));
        }
      }, 30_000);
    });
  }

  on(fn) {
    this._listeners.push(fn);
  }

  close() {
    this._ws.close();
  }
}

// ---------------------------------------------------------------------------
// Build realtor.ca search URL from form body params
// ---------------------------------------------------------------------------

function buildSearchUrl(formBody) {
  const params = new URLSearchParams(formBody);

  const latMin = parseFloat(params.get("LatitudeMin") || "47.50");
  const latMax = parseFloat(params.get("LatitudeMax") || "47.60");
  const lonMin = parseFloat(params.get("LongitudeMin") || "-52.80");
  const lonMax = parseFloat(params.get("LongitudeMax") || "-52.65");

  // The SPA reads hash params to configure the map and fire the API call.
  const parts = [
    `ZoomLevel=${params.get("ZoomLevel") || "12"}`,
    `Center=${((latMin + latMax) / 2).toFixed(6)}%2C${((lonMin + lonMax) / 2).toFixed(6)}`,
    `LatitudeMax=${params.get("LatitudeMax") || latMax}`,
    `LongitudeMax=${params.get("LongitudeMax") || lonMax}`,
    `LatitudeMin=${params.get("LatitudeMin") || latMin}`,
    `LongitudeMin=${params.get("LongitudeMin") || lonMin}`,
    `Sort=${params.get("Sort") || "6-D"}`,
  ];

  for (const key of [
    "PropertyTypeGroupID",
    "TransactionTypeId",
    "PropertySearchTypeId",
    "PriceMin",
    "PriceMax",
    "Currency",
  ]) {
    if (params.get(key)) parts.push(`${key}=${params.get(key)}`);
  }

  return `https://www.realtor.ca/map#${parts.join("&")}`;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  mkdirSync(PROFILE_DIR, { recursive: true });

  const chromePath = findChrome();
  const cleanupDisplay = ensureDisplay();

  const searchUrl = buildSearchUrl(FORM_BODY);
  process.stderr.write(`Search URL: ${searchUrl}\n`);

  const flags = [
    `--remote-debugging-port=${CDP_PORT}`,
    `--user-data-dir=${PROFILE_DIR}`,
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-sync",
    "--disable-extensions",
    "--window-size=1280,720",
  ];

  if (isContainer()) {
    flags.push(
      "--no-sandbox",
      "--disable-setuid-sandbox",
      "--disable-dev-shm-usage",
      "--disable-gpu"
    );
  }

  flags.push(searchUrl);

  // detached: true so we get a process group we can kill cleanly.
  // stdio: "ignore" so Chrome's output doesn't hold our pipes open.
  const chrome = spawn(chromePath, flags, { stdio: "ignore", detached: true });
  chrome.unref();

  const cleanup = () => {
    try {
      // Kill the entire process group (Chrome + renderer children) so nothing
      // lingers and holds pipes open, which would cause System.cmd to hang.
      process.kill(-chrome.pid, "SIGKILL");
    } catch {}
    cleanupDisplay();
  };

  const timer = setTimeout(() => {
    process.stderr.write("Timeout waiting for API response\n");
    cleanup();
    process.exit(1);
  }, TIMEOUT_MS);

  try {
    await waitForCDP();

    const targets = await cdpFetch("/json");
    const tab = targets.find((t) => t.type === "page");
    if (!tab) throw new Error("No page tab found");

    const page = new CDPSession(tab.webSocketDebuggerUrl);
    await page.send("Network.enable");

    // Collect parsed API responses (one per page)
    const collectedPages = [];
    let currentApiRequestId = null;

    page.on((method, params) => {
      if (
        method === "Network.requestWillBeSent" &&
        params.request.url.includes("PropertySearch_Post")
      ) {
        currentApiRequestId = params.requestId;
        process.stderr.write(`API request (page ${collectedPages.length + 1})\n`);
      }

      if (
        method === "Network.loadingFinished" &&
        params.requestId === currentApiRequestId
      ) {
        page
          .send("Network.getResponseBody", { requestId: params.requestId })
          .then((result) => {
            const body = result.base64Encoded
              ? Buffer.from(result.body, "base64").toString("utf-8")
              : result.body;
            try {
              const json = JSON.parse(body);
              if (json.Paging) {
                collectedPages.push(json);
                process.stderr.write(
                  `Page ${json.Paging.CurrentPage}/${json.Paging.TotalPages}: ` +
                    `${json.Results?.length || 0} results\n`
                );
              }
            } catch {
              process.stderr.write(
                `Non-JSON response (${body.length} chars): ${body.substring(0, 200)}\n`
              );
            }
          })
          .catch((err) => {
            process.stderr.write(`Failed to read body: ${err.message}\n`);
          });
      }

      if (
        method === "Network.loadingFailed" &&
        params.requestId === currentApiRequestId
      ) {
        process.stderr.write(
          `API request failed: ${params.errorText}\n`
        );
      }
    });

    // Wait for first page
    process.stderr.write("Waiting for first page of results...\n");
    while (collectedPages.length < 1) {
      await new Promise((r) => setTimeout(r, 500));
    }
    // Small delay to let the page settle after first load
    await new Promise((r) => setTimeout(r, 2000));

    const totalPages = collectedPages[0].Paging?.TotalPages || 1;

    // Click "next page" for remaining pages
    for (let p = 2; p <= totalPages; p++) {
      process.stderr.write(`Clicking next page (${p}/${totalPages})...\n`);
      await page.send("Runtime.evaluate", {
        expression: `document.querySelector("a.lnkNextResultsPage")?.click()`,
      });

      // Wait for the response to arrive
      const deadline = Date.now() + 15_000;
      while (collectedPages.length < p && Date.now() < deadline) {
        await new Promise((r) => setTimeout(r, 500));
      }
      if (collectedPages.length < p) {
        process.stderr.write(`Timed out waiting for page ${p}\n`);
        break;
      }
      // Brief pause between pages
      await new Promise((r) => setTimeout(r, 1000));
    }

    // Merge all results into the first page's response structure
    const merged = { ...collectedPages[0] };
    merged.Results = collectedPages.flatMap((p) => p.Results || []);
    merged.Paging = {
      ...merged.Paging,
      RecordsPerPage: merged.Results.length,
      RecordsShowing: merged.Results.length,
    };

    process.stderr.write(
      `Done: ${merged.Results.length} total results from ${collectedPages.length} pages\n`
    );

    const jsonOutput = JSON.stringify(merged);
    if (OUTPUT_FILE) {
      writeFileSync(OUTPUT_FILE, jsonOutput, "utf-8");
      process.stderr.write(`Wrote ${jsonOutput.length} chars to ${OUTPUT_FILE}\n`);
    } else {
      process.stdout.write(jsonOutput);
    }

    clearTimeout(timer);
    cleanup();
    process.exit(0);
  } catch (err) {
    process.stderr.write(`Error: ${err.message}\n`);
    clearTimeout(timer);
    cleanup();
    process.exit(1);
  }
}

main();
