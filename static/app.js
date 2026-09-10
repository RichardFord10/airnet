const feed = document.querySelector("#feed");
const identityEl = document.querySelector("#identity");
const bodyEl = document.querySelector("#post-body");
const postButton = document.querySelector("#post-button");

const shortKey = (key) => `${key.slice(0, 10)}…${key.slice(-6)}`;

async function loadIdentity() {
  const res = await fetch("/api/identity");
  const data = await res.json();
  identityEl.textContent = `identity: ${shortKey(data.public_key)}`;
}

async function loadPosts() {
  const res = await fetch("/api/posts");
  const posts = await res.json();

  feed.innerHTML = "";

  for (const envelope of posts) {
    const post = envelope.payload;
    const el = document.createElement("article");
    el.innerHTML = `
      <div class="meta">${shortKey(post.author)} · ${new Date(post.timestamp * 1000).toLocaleString()}</div>
      <p></p>
      <div class="object-id">${envelope.id.slice(0, 16)}…</div>
    `;
    el.querySelector("p").textContent = post.body;
    feed.appendChild(el);
  }
}

postButton.addEventListener("click", async () => {
  const body = bodyEl.value.trim();
  if (!body) return;

  const res = await fetch("/api/posts", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ body }),
  });

  if (res.ok) {
    bodyEl.value = "";
    await loadPosts();
  }
});

await loadIdentity();
await loadPosts();
