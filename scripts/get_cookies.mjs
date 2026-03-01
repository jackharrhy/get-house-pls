#!/usr/bin/env node

// Launches real Chrome (not Playwright's Chromium) with remote debugging,
// navigates to the target URL to solve Incapsula bot detection challenge,
// extracts cookies, and prints them as a single-line cookie header string.
//
// Usage: node scripts/get_cookies.mjs [url]
// Default URL: https://api2.realtor.ca/Listing.svc/PropertySearch_Post

import { execSync, spawn } from "node:child_process";
import { mkdirSync } from "node:fs";
import http from "node:http";

const TARGET_URL =
  process.argv[2] ||
  "https://api2.realtor.ca/Listing.svc/PropertySearch_Post";
const CDP_PORT = 9333;
const PROFILE_DIR = "/tmp/chrome-realtor-cookies";
const TIMEOUT_MS = 30_000;

// Find Chrome/Chromium binary. Respects CHROME_BIN env var.
function findChrome() {
  if (process.env.CHROME_BIN) {
    return process.env.CHROME_BIN;
  }

  const candidates = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/usr/bin/google-chrome",
    "/usr/bin/google-chrome-stable",
    "/usr/bin/chromium-browser",
    "/usr/bin/chromium",
  ];
  for (const path of candidates) {
    try {
      execSync(`test -x "${path}"`, { stdio: "ignore" });
      return path;
    } catch {
      continue;
    }
  }
  throw new Error(
    "Chrome not found. Install Google Chrome or set CHROME_BIN."
  );
}

// Detect if we're running in a container (no display available)
function isContainer() {
  try {
    execSync("test -f /.dockerenv", { stdio: "ignore" });
    return true;
  } catch {
    return !process.env.DISPLAY && !process.env.WAYLAND_DISPLAY;
  }
}

// Start Xvfb virtual display if running in a container.
// Incapsula detects --headless mode and invalidates the reese84 token,
// so we use Xvfb to give Chromium a real (virtual) display instead.
function ensureDisplay() {
  // Already have a display — nothing to do
  if (process.env.DISPLAY) {
    return () => {};
  }

  // Not a container — macOS/desktop has a display
  if (!isContainer()) {
    return () => {};
  }

  const display = `:${99 + Math.floor(Math.random() * 100)}`;
  const xvfb = spawn("Xvfb", [display, "-screen", "0", "1280x720x24", "-ac"], {
    stdio: "ignore",
    detached: true,
  });
  xvfb.unref();

  // Give Xvfb a moment to start
  execSync("sleep 0.5");
  process.env.DISPLAY = display;
  process.stderr.write(`Xvfb started on ${display}\n`);

  return () => {
    try {
      xvfb.kill("SIGTERM");
    } catch {}
  };
}

// Fetch JSON from CDP endpoint
function cdpFetch(path) {
  return new Promise((resolve, reject) => {
    const req = http.get(
      `http://127.0.0.1:${CDP_PORT}${path}`,
      { timeout: 5000 },
      (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          try {
            resolve(JSON.parse(data));
          } catch {
            reject(new Error(`Bad JSON from CDP: ${data.slice(0, 200)}`));
          }
        });
      }
    );
    req.on("error", reject);
  });
}

// Wait for CDP to be ready
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

// Send a CDP command over WebSocket
function cdpCommand(wsUrl, method, params = {}) {
  return new Promise((resolve, reject) => {
    // Dynamic import for environments that support it
    import("node:stream").then(() => {
      const ws = new WebSocket(wsUrl);
      const id = 1;

      ws.onopen = () => {
        ws.send(JSON.stringify({ id, method, params }));
      };

      ws.onmessage = (event) => {
        const msg = JSON.parse(event.data);
        if (msg.id === id) {
          ws.close();
          if (msg.error) {
            reject(new Error(msg.error.message));
          } else {
            resolve(msg.result);
          }
        }
      };

      ws.onerror = (err) => reject(err);

      setTimeout(() => {
        ws.close();
        reject(new Error("CDP command timeout"));
      }, 10_000);
    });
  });
}

async function main() {
  mkdirSync(PROFILE_DIR, { recursive: true });

  const chromePath = findChrome();
  const container = isContainer();
  const cleanupDisplay = ensureDisplay();

  // Base flags
  const flags = [
    `--remote-debugging-port=${CDP_PORT}`,
    `--user-data-dir=${PROFILE_DIR}`,
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-background-networking",
    "--disable-sync",
    "--disable-extensions",
  ];

  // Container-specific flags (no --headless; Xvfb provides the display)
  if (container) {
    flags.push(
      "--no-sandbox", // required when running as root in Docker
      "--disable-setuid-sandbox",
      "--disable-dev-shm-usage", // /dev/shm is small in containers
      "--disable-gpu",
      "--window-size=1280,720"
    );
  }

  flags.push(TARGET_URL);

  // Launch Chrome
  const chrome = spawn(chromePath, flags, {
    stdio: "ignore",
    detached: false,
  });

  const cleanup = () => {
    try {
      chrome.kill("SIGTERM");
    } catch {}
    cleanupDisplay();
  };

  // Set a hard timeout
  const timer = setTimeout(() => {
    process.stderr.write("Timeout waiting for cookies\n");
    cleanup();
    process.exit(1);
  }, TIMEOUT_MS);

  try {
    await waitForCDP();

    // Get the browser WebSocket URL
    const version = await cdpFetch("/json/version");
    const wsUrl = version.webSocketDebuggerUrl;

    // Wait for Incapsula JS challenge to resolve (poll for reese84 cookie)
    let cookies = [];
    for (let attempt = 0; attempt < 30; attempt++) {
      await new Promise((r) => setTimeout(r, 1000));

      const result = await cdpCommand(
        wsUrl,
        "Storage.getCookies",
        {}
      );
      cookies = result.cookies || [];

      const reese84 = cookies.find((c) => c.name === "reese84");
      if (reese84) {
        // Format as cookie header string
        const cookieStr = cookies
          .map((c) => `${c.name}=${c.value}`)
          .join("; ");
        process.stdout.write(cookieStr);
        clearTimeout(timer);
        cleanup();
        process.exit(0);
      }
    }

    // If we get here, no reese84 cookie was found
    process.stderr.write(
      "No reese84 cookie found. Available cookies: " +
        cookies.map((c) => c.name).join(", ") +
        "\n"
    );
    process.exit(1);
  } catch (err) {
    process.stderr.write(`Error: ${err.message}\n`);
    process.exit(1);
  } finally {
    clearTimeout(timer);
    cleanup();
  }
}

main();
