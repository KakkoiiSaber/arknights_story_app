import { readFile } from 'node:fs/promises';

// Verify with the preview site's Referer: Wiki-only hotlinks can return 200
// during research but 403 when the actual Flutter site requests them.
const themes = JSON.parse(await readFile(new URL('../lib/assets/data/story_themes.json', import.meta.url), 'utf8'));
const urls = [...new Set(Object.values(themes).flatMap(theme => [
  theme.coverUrl, theme.titleUrl, ...theme.backgroundUrls,
  theme.musicIntroUrl, theme.musicLoopUrl,
].filter(Boolean)))];
let cursor = 0;
const failures = [];
await Promise.all(Array.from({length: 3}, async () => {
  while (cursor < urls.length) {
    const url = urls[cursor++];
    let failure;
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const response = await fetch(url, {method: 'HEAD',
          headers: {Referer: 'http://192.168.1.102:8080/'}, signal: AbortSignal.timeout(15000)});
        const type = response.headers.get('content-type') ?? '';
        if (!response.ok || !/^(image|audio)\//.test(type)) {
          throw new Error(`HTTP ${response.status}, ${type}`);
        }
        failure = null;
        break;
      } catch (error) { failure = error.message; }
    }
    if (failure) failures.push({url, error: failure});
  }
}));
console.log(JSON.stringify({events: Object.keys(themes).length, checked: urls.length, failures}, null, 2));
if (failures.length) process.exitCode = 1;
