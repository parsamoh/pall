// server.js
const express = require("express");
require("dotenv").config();

const {
  SERVER_NAME,
  SERVER_IP, // Used for SS links
  VMESS_CERT,
  VMESS_KEY,
  SS_CHACHA20_PORT,
  SS_CHACHA20_PASSWORD,
  SS_AESGCM_PORT,
  SS_AESGCM_PASSWORD,
  VMESS_PORT,
  VMESS_UUID,
  VMESS_WSPATH,
  TROJAN_PORT,
  TROJAN_PASSWORD,
  NAIVE_PORT,
  NAIVE_USER,
  NAIVE_PASSWORD,
  SHADOWTLS_SERVER, // Note: ShadowTLS isn't a standard subscription link type
  SHADOWTLS_SERVER_PORT, // Note: ShadowTLS isn't a standard subscription link type
  SHADOWTLS_PASSWORD, // Note: ShadowTLS isn't a standard subscription link type
  TUIC_PORT,
  TUIC_UUID,
  TUIC_PASSWORD,
  TUIC_CONGESTION,
  HYSTERIA2_PORT,
  HYSTERIA2_PASSWORD,
  HYSTERIA2_OBFS,
  HYSTERIA2_UP_MBPS,
  HYSTERIA2_DOWN_MBPS,
  ANYTLS_PORT,
  ANYTLS_PASSWORD,
} = process.env;

// Helper to maybe push a link string
const pushIf = (arr, cond, fn) => {
  if (cond) arr.push(fn());
};

function makeSubscriptionLinks() {
  const links = [];

  // Shadowsocks: chacha20-ietf-poly1305
  pushIf(
    links,
    SS_CHACHA20_PORT && SS_CHACHA20_PASSWORD && SERVER_IP,
    () => {
      const userInfo = Buffer.from(
        `chacha20-ietf-poly1305:${SS_CHACHA20_PASSWORD}`
      ).toString("base64");
      return `ss://${userInfo}@${SERVER_IP}:${SS_CHACHA20_PORT}#${encodeURIComponent("ss-chacha20-ietf-poly1305")}`;
    }
  );

  // Shadowsocks: 2022-blake3-aes-128-gcm
  pushIf(
    links,
    SS_AESGCM_PORT && SS_AESGCM_PASSWORD && SERVER_IP,
    () => {
      const userInfo = Buffer.from(
        `2022-blake3-aes-128-gcm:${SS_AESGCM_PASSWORD}`
      ).toString("base64");
      return `ss://${userInfo}@${SERVER_IP}:${SS_AESGCM_PORT}#${encodeURIComponent("ss-2022-blake3-aes-128-gcm")}`;
    }
  );

  // Vmess over WS + TLS
  pushIf(links, VMESS_PORT && VMESS_UUID && VMESS_WSPATH && SERVER_NAME, () => {
    const vmessJson = JSON.stringify({
      v: "2",
      ps: "vmess-ws",
      add: SERVER_NAME,
      port: Number(VMESS_PORT),
      id: VMESS_UUID,
      aid: "0", // alterId
      scy: "auto", // cipher
      net: "ws",
      path: VMESS_WSPATH,
      host: SERVER_NAME,
      tls: "tls",
    });
    const vmessBase64 = Buffer.from(vmessJson).toString("base64");
    return `vmess://${vmessBase64}`;
  });

  // Trojan
  pushIf(links, TROJAN_PORT && TROJAN_PASSWORD && SERVER_NAME, () => {
    return `trojan://${TROJAN_PASSWORD}@${SERVER_NAME}:${TROJAN_PORT}#${encodeURIComponent("trojan")}`;
  });

  // Naiveproxy (naive+https)
  pushIf(links, NAIVE_PORT && NAIVE_USER && NAIVE_PASSWORD && SERVER_NAME, () => {
    return `naive+https://${encodeURIComponent(NAIVE_USER)}:${encodeURIComponent(NAIVE_PASSWORD)}@${SERVER_NAME}:${NAIVE_PORT}#${encodeURIComponent("naive")}`;
  });

  // TUIC
  pushIf(links, TUIC_PORT && TUIC_UUID && TUIC_PASSWORD && SERVER_NAME, () => {
    // TUIC v5 is commonly used, include relevant parameters
    const params = new URLSearchParams({
      version: "5", // Or the version your server supports
      congestion_control: TUIC_CONGESTION,
      udp_relay_mode: "native",
      sni: SERVER_NAME
    }).toString();
    return `tuic://${TUIC_UUID}:${TUIC_PASSWORD}@${SERVER_IP}:${TUIC_PORT}?${params}#${encodeURIComponent("tuic")}`;
  });

  // Hysteria2
  pushIf(links, HYSTERIA2_PORT && HYSTERIA2_PASSWORD && SERVER_NAME, () => {
    const params = new URLSearchParams({
      sni: SERVER_NAME,
      "obfs-password": HYSTERIA2_OBFS
    }).toString();
    return `hysteria2://${HYSTERIA2_PASSWORD}@${SERVER_IP}:${HYSTERIA2_PORT}?${params}#${encodeURIComponent("hysteria2")}`;
  });


  pushIf(links, ANYTLS_PORT && ANYTLS_PASSWORD && SERVER_NAME, () => {
    const params = new URLSearchParams({
      sni: SERVER_NAME,
      security: "tls"
    }).toString();
    return `anytls://${ANYTLS_PASSWORD}@${SERVER_IP}:${ANYTLS_PORT}?${params}#${encodeURIComponent("anytls")}`;
  });

  // Note: ShadowTLS are not standard subscription link types
  // and are typically configured as transport layers within a client,
  // rather than as top-level subscription links. They are excluded here.

  return links;
}

const app = express();

// Serve a simple HTML page pointing users at the subscription URL
app.get("/", (_req, res) => {
  const subUrl = `https://${SERVER_NAME}/subscribe`;
  res.send(`
    <html>
      <head><title>Sing-box Subscription</title></head>
      <body>
        <h1>Sing-box Subscription</h1>
        <p>This server provides a base64 encoded Sing-box subscription list.</p>
        <p>Add this URL to your Sing-box client's subscription settings:</p>
        <pre>${subUrl}</pre>
      </body>
    </html>
  `);
});

// The subscription endpoint: returns base64 encoded links
app.get("/subscribe", (_req, res) => {
  const links = makeSubscriptionLinks();
  const subscriptionContent = links.join("\n");
  const base64Subscription = Buffer.from(subscriptionContent).toString(
    "base64"
  );

  res.setHeader("Content-Type", "text/plain");
  // Optional: Add a header for the client to recognize the subscription name
  // res.setHeader("Subscription-Userinfo", "upload=0; download=0; total=107374182400; expire=253402300799"); // Example usage info if you implement tracking
  res.send(base64Subscription);
});

app.listen(8080, () => {
  console.log("✅ HTTPS server running on port 443");
  console.log(`Subscription URL: https://${SERVER_NAME}/subscribe`);
});

