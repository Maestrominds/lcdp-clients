import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [sveltekit()],
	server: {
		proxy: {
			'/api': {
				target: 'https://lcdp-server-production.up.railway.app',
				changeOrigin: true,
				rewrite: (path) => path.replace(/^\/api/, ''),
				configure: (proxy) => {
					proxy.on('proxyRes', (proxyRes, req, res) => {
						const setCookie = proxyRes.headers['set-cookie'];
						if (setCookie) {
							res.setHeader('set-cookie', setCookie);
						}
					});
				}
			}
		}
	}
});
