import handler from '../worker/src/index.js';
export const onRequest = ({ request, env, waitUntil }) => handler.fetch(request, env, { waitUntil });
