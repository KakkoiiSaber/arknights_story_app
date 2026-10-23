import { resolveScriptURL } from './source.mjs';

export class StoryQueue {
  constructor(script, serialized) {
    this.current = {script: resolveScriptURL(script).href, title: '', summary: '', storyName: ''};
    this.entries = [];
    this.index = -1;
    try {
      const input = JSON.parse(serialized || '[]');
      if (!Array.isArray(input)) return;
      this.entries = input.map(entry => {
        if (!entry || typeof entry.script !== 'string' || !entry.script.trim())
          throw new Error('Invalid story queue entry');
        return {script: resolveScriptURL(entry.script).href,
          title: typeof entry.title === 'string' ? entry.title : '',
          storyName: typeof entry.storyName === 'string' ? entry.storyName : '',
          summary: typeof entry.summary === 'string' ? entry.summary : ''};
      });
      this.index = this.entries.findIndex(entry => entry.script === this.current.script);
      if (this.index >= 0) this.current = this.entries[this.index];
    } catch { this.entries = []; }
  }

  get next() { return this.index < 0 ? null : this.entries[this.index + 1] ?? null; }
  get isStoryEnd() { return this.index >= 0 && !this.next; }
  advance() {
    if (!this.next) return false;
    this.current = this.entries[++this.index];
    return true;
  }
}

/// One transition per completed section; dialogs give readers time to review.
export class CompletionTransition {
  constructor(delayMs = 1000) { this.delayMs = delayMs; this.reset(); }
  reset() { this.since = null; this.fired = false; }
  tick(now, blocked) {
    if (this.fired) return false;
    if (blocked) { this.since = null; return false; }
    if (this.since === null) this.since = now;
    if (now - this.since < this.delayMs) return false;
    this.fired = true;
    return true;
  }
}
