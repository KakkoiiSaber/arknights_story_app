import type { ReaderPreferences } from './reader-preferences';

type NativeBridge = { callHandler(name: string, ...args: unknown[]): Promise<unknown> };

export async function notifyHost(action: 'exit' | 'preferences' | 'progress', value?: ReaderPreferences | Record<string, unknown>) {
  const native = (window as Window & { flutter_inappwebview?: NativeBridge }).flutter_inappwebview;
  if (new URLSearchParams(location.search).get('native') === '1' && native) {
    return native.callHandler('arkstory', action, value);
  }
  if (window.parent !== window) {
    window.parent.postMessage(action === 'exit' ? 'arkstory:exit' :
      JSON.stringify({ type: action === 'progress' ? 'arkstory:progress' : 'arkstory:save-preferences', value }), location.origin);
  } else if (action === 'exit') {
    history.back();
  }
}

let checkpointRequestId = 0;
export async function requestCheckpoint(chapterId: string): Promise<Record<string, unknown> | null> {
  if (new URLSearchParams(location.search).get('native') === '1' &&
      !(window as Window & { flutter_inappwebview?: NativeBridge }).flutter_inappwebview) {
    await new Promise<void>(resolve => {
      const finish = () => {
        clearTimeout(timer); window.removeEventListener('flutterInAppWebViewPlatformReady', finish); resolve();
      };
      const timer = setTimeout(finish, 3000);
      window.addEventListener('flutterInAppWebViewPlatformReady', finish);
    });
  }
  const native = (window as Window & { flutter_inappwebview?: NativeBridge }).flutter_inappwebview;
  if (new URLSearchParams(location.search).get('native') === '1' && native) {
    return await native.callHandler('arkstory', 'checkpoint', chapterId) as Record<string, unknown> | null;
  }
  if (window.parent === window) return null;
  const requestId = `checkpoint-${Date.now()}-${++checkpointRequestId}`;
  return new Promise(resolve => {
    const finish = (value: Record<string, unknown> | null) => {
      clearTimeout(timeout); window.removeEventListener('message', listener); resolve(value);
    };
    const listener = (event: MessageEvent) => {
      if (event.origin !== location.origin || event.source !== window.parent || typeof event.data !== 'string') return;
      try {
        const value = JSON.parse(event.data);
        if (value.type === 'arkstory:checkpoint' && value.requestId === requestId) finish(value.value);
      } catch { /* Other host messages. */ }
    };
    const timeout = setTimeout(() => finish(null), 3000);
    window.addEventListener('message', listener);
    window.parent.postMessage(JSON.stringify({type: 'arkstory:checkpoint-request', requestId, chapterId}), location.origin);
  });
}
