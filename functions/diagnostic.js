// Proxy Claude servi par Cloudflare Pages (même adresse que le site : /diagnostic).
import handler from '../worker/src/index.js';
export const onRequest = ({ request, env, waitUntil }) => handler.fetch(request, env, { waitUntil });
