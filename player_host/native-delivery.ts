declare global { var __arkstoryAssetURL: ((url: string) => string) | undefined; }

const native = new URLSearchParams(location.search).get('native') === '1';
export function nativeResourceURL(url: string): string {
  const resolved = new URL(url, document.baseURI);
  if (!native || resolved.origin === location.origin || !/^https?:$/.test(resolved.protocol)) return url;
  const extension = resolved.pathname.match(/\.[a-z0-9]+$/i)?.[0] ?? '.bin';
  const proxy = new URL(`./resource/file${extension}`, document.baseURI);
  proxy.searchParams.set('url', resolved.href);
  return proxy.href;
}
export function installNativeDelivery(mapAssets = true) {
  if (!native) return;
  const originalFetch = window.fetch.bind(window);
  window.fetch = (input, init) => originalFetch(
    input instanceof Request ? new Request(nativeResourceURL(input.url), input) : nativeResourceURL(String(input)), init,
  );
  if (mapAssets) globalThis.__arkstoryAssetURL = nativeResourceURL;
}
