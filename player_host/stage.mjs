import { cp, access } from 'node:fs/promises';
const source = new URL('../web/prts-player/', import.meta.url);
const destination = new URL('../build/web/prts-player/', import.meta.url);
// Explicit staging also handles Flutter incremental builds that cached the web
// input file list before the host generated its additional files.
await access(new URL('index.html', source));
await access(new URL('../build/web/index.html', import.meta.url));
await cp(source, destination, { recursive: true, force: true });
console.log('PRTS host staged into build/web/prts-player');
