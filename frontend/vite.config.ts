import adapter from '@sveltejs/adapter-static';
import { sveltekit } from '@sveltejs/kit/vite';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';
import { defineConfig } from 'vitest/config';
export default defineConfig({
  define: { 'import.meta.env.VITE_GIT_SHA': JSON.stringify(process.env.GIT_SHA || 'development'), '__SG_BUILD_ID__': JSON.stringify(process.env.GIT_SHA && process.env.GIT_SHA !== 'unknown' ? process.env.GIT_SHA : Date.now().toString()) },
  plugins: [sveltekit({ preprocess: vitePreprocess(), alias: { '$lib': './src/lib' }, adapter: adapter({ fallback: 'index.html' }), serviceWorker: { register: false } })],
  server: { proxy: { '/api': 'http://127.0.0.1:18765', '/guide': 'http://127.0.0.1:18765' } },
  test: { include: ['src/**/*.test.ts'], environment: 'node' }
});
