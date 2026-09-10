const feed = document.querySelector("#feed");
const identityEl = document.querySelector("#identity");
const bodyEl = document.querySelector("#post-body");
const postButton = document.querySelector("#post-button");
const status = document.querySelector("#status");
const networkEl = document.querySelector("#network");
const shortKey = (key) => `${key.slice(0, 10)}…${key.slice(-6)}`;
let simulator = false;
let previousFeed = "";

async function api(path, options) {
  const res = await fetch(path, options);
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || `Request failed (${res.status})`);
  return data;
}

async function loadPosts() {
  const posts = await api("/api/posts");
  const serialized = JSON.stringify(posts);
  if (serialized === previousFeed) return;
  previousFeed = serialized;
  feed.replaceChildren();
  if (!posts.length) feed.textContent = "No posts yet. Write the first one.";
  for (const envelope of posts) {
    const post = envelope.payload;
    const el = document.createElement("article");
    const meta = document.createElement("div");
    meta.className = "meta";
    meta.textContent = `${shortKey(post.author)} · ${new Date(post.timestamp * 1000).toLocaleString()}`;
    const body = document.createElement("p");
    body.textContent = post.body;
    const id = document.createElement("div");
    id.className = "object-id";
    id.textContent = `${envelope.id.slice(0, 16)}… · signature verified`;
    el.append(meta, body, id);
    feed.appendChild(el);
  }
}

function renderNetwork(data) {
  networkEl.hidden = false;
  if (!networkEl.childElementCount) {
    const heading = document.createElement("h2");
    heading.textContent = `${data.current} · simulated mesh`;
    const nodes = document.createElement("div");
    nodes.className = "nodes";
    data.nodes.forEach((node, index) => {
      const link = document.createElement("a");
      link.href = `http://127.0.0.1:${data.base_port + index}`;
      link.dataset.node = node.name;
      nodes.appendChild(link);
    });
    const links = document.createElement("div");
    links.className = "links";
    data.links.forEach((link, index) => {
      const label = document.createElement("label");
      const toggle = document.createElement("input");
      toggle.type = "checkbox";
      toggle.dataset.link = index;
      toggle.addEventListener("change", async () => {
        toggle.disabled = true;
        try {
          await api("/api/network/links", {
            method: "POST", headers: { "content-type": "application/json" },
            body: JSON.stringify({ a: link.a, b: link.b, enabled: toggle.checked }),
          });
          status.textContent = toggle.checked ? "Link connected. Missing posts sync within 5 seconds." : "Link disconnected. Posts remain saved locally.";
        } catch (error) {
          toggle.checked = !toggle.checked;
          status.textContent = error.message;
        } finally { toggle.disabled = false; }
      });
      label.append(toggle, ` ${link.a} ↔ ${link.b}`);
      links.appendChild(label);
    });
    const count = document.createElement("p");
    count.id = "packet-count";
    networkEl.append(heading, nodes, links, count);
  }
  data.nodes.forEach((node) => {
    networkEl.querySelector(`[data-node="${node.name}"]`).textContent = `${node.name}: ${node.posts} posts`;
  });
  data.links.forEach((link, index) => {
    const toggle = networkEl.querySelector(`[data-link="${index}"]`);
    if (!toggle.disabled) toggle.checked = link.enabled;
  });
  document.querySelector("#packet-count").textContent = `${data.delivered} packet deliveries · no RF hardware used`;
}

postButton.addEventListener("click", async () => {
  const body = bodyEl.value.trim();
  if (!body || postButton.disabled) return;
  postButton.disabled = true;
  try {
    await api("/api/posts", {
      method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ body }),
    });
    bodyEl.value = "";
    status.textContent = "Post saved locally.";
    await loadPosts();
  } catch (error) { status.textContent = error.message; }
  finally { postButton.disabled = false; }
});

async function refresh() {
  try {
    await loadPosts();
    if (simulator) renderNetwork(await api("/api/network"));
  } catch (error) { status.textContent = `Node unavailable: ${error.message}`; }
  finally { setTimeout(refresh, 1500); }
}

try {
  const identity = await api("/api/identity");
  identityEl.textContent = `identity: ${shortKey(identity.public_key)}`;
  const res = await fetch("/api/network");
  if (res.ok) { simulator = true; renderNetwork(await res.json()); }
} catch (error) { status.textContent = error.message; }
refresh();
