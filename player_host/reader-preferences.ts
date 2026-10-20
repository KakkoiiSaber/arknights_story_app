export interface ReaderPreferences {
  doctorName: string;
  fontScale: number;
  typingIntervalMs: number;
}

declare global {
  var __arkstoryPreferences: ReaderPreferences | undefined;
  var __arkstoryApplyPreferences: ((value: unknown) => void) | undefined;
  var __arkstoryRefreshDialogue: (() => void) | undefined;
}

export function normalizePreferences(value: unknown): ReaderPreferences {
  const input = value && typeof value === 'object'
    ? value as Partial<ReaderPreferences> : {};
  const clamp = (value: unknown, min: number, max: number, fallback: number) =>
    typeof value === 'number' && Number.isFinite(value)
      ? Math.min(max, Math.max(min, value)) : fallback;
  return {
    doctorName: typeof input.doctorName === 'string' && input.doctorName.trim()
      ? Array.from(input.doctorName.trim()).slice(0, 32).join('') : '博士',
    fontScale: clamp(input.fontScale, 0.8, 1.4, 1),
    typingIntervalMs: Math.round(clamp(input.typingIntervalMs, 0, 100, 40)),
  };
}

export function installReaderPreferences(query: URLSearchParams) {
  globalThis.__arkstoryApplyPreferences = value => {
    globalThis.__arkstoryPreferences = normalizePreferences(value);
    globalThis.__arkstoryRefreshDialogue?.();
  };
  let initial: unknown;
  try { initial = JSON.parse(query.get('preferences') || '{}'); } catch { /* defaults */ }
  globalThis.__arkstoryApplyPreferences(initial);
  window.addEventListener('message', event => {
    if (event.source !== window.parent || event.origin !== location.origin ||
        typeof event.data !== 'string') return;
    try {
      const message = JSON.parse(event.data);
      if (message.type === 'arkstory:preferences')
        globalThis.__arkstoryApplyPreferences?.(message.value);
    } catch { /* unrelated host messages */ }
  });
  if (window.parent !== window)
    window.parent.postMessage('arkstory:ready', location.origin);
}
