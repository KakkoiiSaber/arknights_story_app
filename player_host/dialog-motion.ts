// Keep dialogs modal until their exit animation completes, so clicks cannot
// reach the story canvas while the overlay fades away.
const closing = new WeakMap<HTMLDialogElement, Promise<void>>();
const animated = (panel: HTMLDialogElement) => ['log-panel', 'skip-panel', 'settings-panel'].includes(panel.id);
const duration = () => matchMedia('(prefers-reduced-motion: reduce)').matches ? 0 : 220;

export function openReaderDialog(panel: HTMLDialogElement) {
  if (panel.open) return;
  delete panel.dataset.closing;
  panel.showModal();
  if (!animated(panel)) return;
  panel.animate([{ opacity: 0 }, { opacity: 1 }], { duration: duration(), easing: 'ease-out' });
  panel.querySelector('.skip-content, #log-content, #settings-panel .panel-content')?.animate(
    [{ transform: 'translateY(8px)' }, { transform: 'translateY(0)' }],
    { duration: duration(), easing: 'cubic-bezier(.2,.7,.2,1)' });
}

export function closeReaderDialog(panel: HTMLDialogElement): Promise<void> {
  const pending = closing.get(panel);
  if (pending) return pending;
  if (!panel.open) return Promise.resolve();
  if (!animated(panel)) { panel.close(); return Promise.resolve(); }
  const task = (async () => {
    panel.getAnimations().forEach(animation => animation.cancel());
    panel.dataset.closing = 'true';
    const content = panel.querySelector('.skip-content, #log-content, #settings-panel .panel-content');
    content?.getAnimations().forEach(animation => animation.cancel());
    content?.animate([{ transform: 'translateY(0)' }, { transform: 'translateY(5px)' }],
      { duration: duration(), easing: 'ease-in' });
    await panel.animate([{ opacity: 1 }, { opacity: 0 }],
      { duration: duration(), easing: 'ease-in', fill: 'forwards' }).finished.catch(() => {});
    panel.close();
    panel.getAnimations().forEach(animation => animation.cancel());
    delete panel.dataset.closing;
  })();
  closing.set(panel, task);
  void task.finally(() => closing.delete(panel));
  return task;
}
