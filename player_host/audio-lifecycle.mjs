// Keep the Pixi context alive across iOS WebKit interruptions. A pending
// resume promise must never hold up rendering or prevent a later touch retry.
export function installAudioLifecycle({ context, stage, native = false,
  page = document, lifecycle = window, navigator: browser = globalThis.navigator }) {
  let disposed = false;
  const sync = () => { if (!disposed) stage.dataset.audioState = context.state; };
  const resume = () => {
    if (disposed || page.visibilityState === 'hidden') return;
    if (native) {
      try {
        if (browser?.audioSession) browser.audioSession.type = 'playback';
      } catch (error) { console.warn('[PRTS audio] playback session unavailable', error); }
    }
    if (context.state === 'suspended' || context.state === 'interrupted') {
      try {
        void context.resume().then(sync).catch(error => {
          if (!disposed) {
            stage.dataset.audioError = String(error);
            console.warn('[PRTS audio] resume failed', error);
          }
        });
      } catch (error) {
        stage.dataset.audioError = String(error);
      }
    }
    sync();
  };
  const gestures = ['pointerdown', 'touchend', 'click', 'keydown'];
  for (const name of gestures) page.addEventListener(name, resume, true);
  page.addEventListener('visibilitychange', resume);
  lifecycle.addEventListener('pageshow', resume);
  lifecycle.addEventListener('focus', resume);
  context.addEventListener('statechange', sync);
  sync();
  return { resume, dispose() {
    disposed = true;
    for (const name of gestures) page.removeEventListener(name, resume, true);
    page.removeEventListener('visibilitychange', resume);
    lifecycle.removeEventListener('pageshow', resume);
    lifecycle.removeEventListener('focus', resume);
    context.removeEventListener('statechange', sync);
  } };
}
