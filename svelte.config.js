import node from '@sveltejs/adapter-node';
import vercel from '@sveltejs/adapter-vercel';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';
export default {
  preprocess: vitePreprocess(),
  kit: {
    adapter: process.env.VERCEL
      ? vercel({ runtime: 'nodejs22.x', maxDuration: 60 })
      : node(),
    // SvelteKit adds a per-response nonce to its own inline bootstrap script.
    // Style attributes are authored in routes and set through the CSSOM, so
    // styles stay permissive while scripts stay limited to this origin.
    csp: {
      mode: 'auto',
      directives: {
        'default-src': ['self'],
        'script-src': ['self'],
        'style-src': ['self', 'unsafe-inline'],
        'img-src': ['self', 'data:'],
        'font-src': ['self'],
        'connect-src': ['self'],
        'manifest-src': ['self'],
        'object-src': ['none'],
        'base-uri': ['none'],
        'form-action': ['self'],
        'frame-ancestors': ['none'],
      },
    },
  },
};
