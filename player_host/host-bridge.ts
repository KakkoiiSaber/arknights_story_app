import type { ReaderPreferences } from './reader-preferences';

type NativeBridge = { callHandler(name: string, ...args: unknown[]): Promise<unknown> };

export async function notifyHost(action: 'exit' | 'preferences', value?: ReaderPreferences) {
  const native = (window as Window & { flutter_inappwebview?: NativeBridge }).flutter_inappwebview;
  if (new URLSearchParams(location.search).get('native') === '1' && native) {
    return native.callHandler('arkstory', action, value);
  }
  if (window.parent !== window) {
    window.parent.postMessage(action === 'exit' ? 'arkstory:exit' :
      JSON.stringify({ type: 'arkstory:save-preferences', value }), location.origin);
  } else if (action === 'exit') {
    history.back();
  }
}
