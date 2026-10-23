import { openReaderDialog, closeReaderDialog } from './dialog-motion';
import { setArtView, setSceneUIVisible } from './art-view';
import { readHistory } from './reader-history';
import { normalizePreferences } from './reader-preferences';
import { notifyHost } from './host-bridge';
import type { AutoPlayMode, ParsedLine, StoryPlayer } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/types';

const el = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;

export class ReaderControls {
  private player: StoryPlayer | null = null;
  private lines: ParsedLine[] = [];
  private variables: Record<string, unknown> = {};
  private visited = new Set<number>();
  private unsubscribe?: () => void;

  private skipping = false;

  constructor(skipStory: () => Promise<void>, skipDetails: () => { title: string; summary: string; storyName: string }) {
    el('art-view').onclick = () => {
      if (!this.player || this.modalOpen) return;
      this.manual();
      setArtView(true, true);
    };
    const restoreView = () => { setArtView(false, true); };
    el('restore-view').onclick = restoreView;
    document.addEventListener('keydown', event => {
      if (!el<HTMLButtonElement>('restore-view').hidden && ['Escape', ' ', 'Enter', 'ArrowRight'].includes(event.key)) {
        event.preventDefault();
        event.stopImmediatePropagation();
        restoreView();
      }
    }, true);
    el('skip').onclick = () => {
      if (this.skipping || this.modalOpen || !this.player || ['finished', 'error'].includes(this.player.getState())) return;
      this.manual();
      const details = skipDetails();
      el('skip-story').textContent = details.storyName ? `《${details.storyName}》` : '';
      el('skip-story').hidden = !details.storyName;
      el('skip-title').textContent = details.title || '当前剧情';
      el('skip-summary').textContent = details.summary;
      el('skip-summary').hidden = !details.summary;
      openReaderDialog(el<HTMLDialogElement>('skip-panel'));
      el('skip-cancel').focus();
    };
    el('skip-confirm').onclick = async () => {
      if (this.skipping || !el<HTMLDialogElement>('skip-panel').open) return;
      this.skipping = true;
      await closeReaderDialog(el<HTMLDialogElement>('skip-panel'));
      this.sync();
      try { await skipStory(); }
      finally { this.skipping = false; this.sync(); }
    };
    el('return').onclick = () => { this.manual(); void notifyHost('exit'); };
    el('auto').onclick = () => this.toggleMode('button_auto');
    el('quick').onclick = () => this.toggleMode('quick_play');
    el('speed').onclick = () => {
      const state = this.player?.getAutoPlayState();
      if (!state) return;
      const quick = state.mode === 'quick_play';
      this.player?.setAutoPlaySpeedLevel(((quick ? state.quickSpeedLevel : state.buttonSpeedLevel) + 1) % (quick ? 4 : 3));
      this.sync();
    };
    el('log').onclick = () => this.openLog();
    el('settings').onclick = () => this.openSettings();
    for (const dialog of document.querySelectorAll<HTMLDialogElement>('dialog')) {
      dialog.querySelector<HTMLButtonElement>('[data-close]')!.onclick = () => { void closeReaderDialog(dialog); };
      dialog.addEventListener('cancel', event => {
        event.preventDefault();
        void closeReaderDialog(dialog);
      });
      dialog.addEventListener('close', () => {
        if (dialog.id === 'log-panel') setSceneUIVisible(true);
        el('stage').focus();
      });
    }
    for (const id of ['doctor-name', 'font-scale', 'typing-speed'])
      el(id).addEventListener('input', () => this.saveSettings());
  }

  attach(player: StoryPlayer | null, lines: ParsedLine[] = [], variables: Record<string, unknown> = {}) {
    setArtView(false);
    this.unsubscribe?.();
    this.player = player;
    this.lines = lines;
    this.variables = variables;
    this.visited.clear();
    this.unsubscribe = player?.onDisplayedLineChange(line => {
      if (line != null) this.visited.add(line);
    });
    this.sync();
  }

  private manual() { this.player?.setAutoPlayMode('default'); this.sync(); }

  private toggleMode(mode: AutoPlayMode) {
    if (this.modalOpen || !this.player || this.player.isTheaterMode()) return;
    this.player.setAutoPlayMode(this.player.getAutoPlayState().mode === mode ? 'default' : mode);
    this.sync();
  }

  get modalOpen() { return !!document.querySelector('dialog[open]'); }

  sync() {
    const player = this.player;
    const finished = !player || ['finished', 'error'].includes(player.getState());
    const mode = player?.getAutoPlayState();
    for (const [id, expected] of [['auto', 'button_auto'], ['quick', 'quick_play']]) {
      const button = el<HTMLButtonElement>(id);
      button.disabled = finished || !!player?.isTheaterMode();
      button.setAttribute('aria-pressed', String(mode?.mode === expected));
    }
    el<HTMLButtonElement>('art-view').disabled = finished;
    el<HTMLButtonElement>('skip').disabled = finished || this.skipping;
    el<HTMLButtonElement>('log').disabled = !player;
    const speed = el<HTMLButtonElement>('speed');
    speed.hidden = finished || !mode || mode.mode === 'default';
    if (mode) speed.textContent = `${(mode.mode === 'quick_play' ? mode.quickSpeedLevel : mode.buttonSpeedLevel) + 1} 档`;
  }

  private openLog() {
    if (!this.player) return;
    this.manual();
    const panel = el<HTMLDialogElement>('log-panel');
    const content = el('log-content');
    content.replaceChildren();
    // Use upstream's multiline and branch semantics. Only actual displayed
    // lines and actual choices enter history; unread branches stay hidden.
    for (const entry of readHistory(this.lines, this.visited, this.player.getLogPosition(), this.variables)) {
      const row = document.createElement('div');
      row.className = 'log-entry';
      {
        const speaker = document.createElement('strong');
        speaker.textContent = entry.speaker || '';
        speaker.className = 'log-speaker';
        row.append(speaker);
      }
      const dialogue = document.createElement('div');
      dialogue.className = 'log-dialogue';
      for (const span of entry.spans) {
        const text = document.createElement('span');
        text.textContent = span.text;
        if (span.color && CSS.supports('color', span.color)) text.style.color = span.color;
        if (span.bold) text.style.fontWeight = 'bold';
        if (span.italic) text.style.fontStyle = 'italic';
        dialogue.append(text);
      }
      row.append(dialogue);
      content.append(row);
    }
    if (!content.childElementCount) content.textContent = '暂无剧情记录';
    content.lastElementChild?.classList.add('log-current');
    content.style.setProperty('--log-font-scale', String(globalThis.__arkstoryPreferences?.fontScale ?? 1));
    setSceneUIVisible(false);
    openReaderDialog(panel);
    content.scrollTop = content.scrollHeight;
  }

  private openSettings() {
    this.manual();
    const preferences = normalizePreferences(globalThis.__arkstoryPreferences);
    el<HTMLInputElement>('doctor-name').value = preferences.doctorName;
    el<HTMLInputElement>('font-scale').value = String(preferences.fontScale * 100);
    el<HTMLInputElement>('typing-speed').value = String(100 - preferences.typingIntervalMs);
    this.updateLabels();
    openReaderDialog(el<HTMLDialogElement>('settings-panel'));
  }

  private updateLabels() {
    el('font-value').textContent = `${el<HTMLInputElement>('font-scale').value}%`;
    const delay = 100 - Number(el<HTMLInputElement>('typing-speed').value);
    el('typing-value').textContent = delay === 0 ? '即时显示' : `${delay} 毫秒／字`;
  }

  private saveSettings() {
    const preferences = normalizePreferences({
      doctorName: el<HTMLInputElement>('doctor-name').value,
      fontScale: Number(el<HTMLInputElement>('font-scale').value) / 100,
      typingIntervalMs: 100 - Number(el<HTMLInputElement>('typing-speed').value),
    });
    globalThis.__arkstoryApplyPreferences?.(preferences);
    this.updateLabels();
    void notifyHost('preferences', preferences).then(result => {
      el('settings-note').textContent = typeof result === 'string' ? result : '已应用于所有剧情';
    }).catch(() => { el('settings-note').textContent = '已应用，但暂时无法保存设置'; });
  }
}
