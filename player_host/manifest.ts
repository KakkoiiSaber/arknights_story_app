import { chapterManifest } from './download-manifest';
import { installNativeDelivery } from './native-delivery';

declare global { interface Window { flutter_inappwebview?: { callHandler(name: string, ...args: unknown[]): Promise<unknown> }; } }
installNativeDelivery(false);
let started = false;
async function start() {
  if (started || !window.flutter_inappwebview) return;
  started = true;
  try {
    const script = new URLSearchParams(location.search).get('script');
    if (!script) throw new Error('Missing script');
    const urls = await chapterManifest(script, AbortSignal.timeout(90000));
    // UI, fonts and mapping metadata are bundled in the app, not downloaded.
    await window.flutter_inappwebview.callHandler('chapterManifest', { script, urls: urls.filter(url => new URL(url).origin !== location.origin) });
  } catch (error) {
    await window.flutter_inappwebview.callHandler('chapterManifest', { script: new URLSearchParams(location.search).get('script'), error: String(error) });
  }
}
window.addEventListener('flutterInAppWebViewPlatformReady', () => { void start(); });
void start();
