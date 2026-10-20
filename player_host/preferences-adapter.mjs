// Pin adaptations here so upstream remains a clean, independently updatable submodule.
// Fail the build if an upstream hook changes, rather than silently ignoring preferences.
export function adaptReaderPreferences(source, id) {
  const path = id.replaceAll('\\', '/');
  const replace = (from, to) => {
    if (!source.includes(from)) throw new Error(`PRTS reading settings contract changed: ${path}: ${from}`);
    return source.replace(from, to);
  };
  if (path.endsWith('/StoryPlayer/engine/textVariables.ts'))
    return replace('export function getStoryNickname(): string {',
      'export function getStoryNickname(): string {\n  if (globalThis.__arkstoryPreferences) return globalThis.__arkstoryPreferences.doctorName;');
  if (path.endsWith('/StoryPlayer/engine/runtime.ts'))
    return replace('return this.defaultSpeed;',
      'return { ...this.defaultSpeed, typeWriterDelayMs: globalThis.__arkstoryPreferences?.typingIntervalMs ?? this.defaultSpeed.typeWriterDelayMs };');
  if (path.endsWith('/rendering/panels/DialogPanel.ts')) {
    source = replace('    this.applyLayout(layout);', `    globalThis.__arkstoryRefreshDialogue = () => {
      if (!this.dialogue) return;
      this.dialogue.style.fontSize = 24 * (globalThis.__arkstoryPreferences?.fontScale ?? 1);
      if (this.speaker) this.applyNameBestFit(this.speaker.text);
      this.applyLayout(layout);
    };
    globalThis.__arkstoryRefreshDialogue();`);
    source = replace('let size = DialogPanel.NAME_FONT_MAX;',
      'let size = DialogPanel.NAME_FONT_MAX * (globalThis.__arkstoryPreferences?.fontScale ?? 1);');
    source = replace('size >= DialogPanel.NAME_FONT_MIN;',
      'size >= DialogPanel.NAME_FONT_MIN * (globalThis.__arkstoryPreferences?.fontScale ?? 1);');
    source = replace('size -= 1',
      'size -= (globalThis.__arkstoryPreferences?.fontScale ?? 1)');
    // If a very long name still exceeds its fixed region at the smallest
    // preferred size, fit to that region instead of overlapping the dialogue.
    const nameFit = source.match(/  private applyNameBestFit\(name: string\): void \{[\s\S]*?\n  \}/)?.[0];
    if (!nameFit) throw new Error('PRTS speaker name fitting contract changed');
    source = replace(nameFit, nameFit.slice(0, -4) + `
    const width = CanvasTextMetrics.measureText(name, this.speaker.style).width;
    if (width > DialogPanel.NAME_WIDTH)
      this.speaker.style.fontSize *= DialogPanel.NAME_WIDTH / width;
  }`);
    return replace('  destroy(): void {',
      '  destroy(): void {\n    globalThis.__arkstoryRefreshDialogue = undefined;');
  }
}
