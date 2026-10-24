import { sha256 } from '@noble/hashes/sha2.js';

export function chapterKey(source) {
  let path;
  try { path = new URL(source).pathname; } catch { path = source; }
  if (path.includes('/gamedata/story/')) path = path.split('/gamedata/story/')[1];
  return path.replace(/^\/+/, '').replace(/\.txt$/, '');
}

export async function scriptHash(script) {
  const bytes = new TextEncoder().encode(script.replace(/\r\n?/g, '\n'));
  // LAN previews commonly use HTTP, where WebCrypto is unavailable.
  return [...sha256(bytes)].map(b => b.toString(16).padStart(2, '0')).join('');
}

export function restorable(checkpoint, hash, lines) {
  return checkpoint && !checkpoint.atEnd && (checkpoint.atEnd !== undefined || !checkpoint.completed) && checkpoint.scriptHash === hash &&
    Number.isInteger(checkpoint.line) && checkpoint.line > 0 &&
    lines.some(line => line.lineNumber === checkpoint.line) && Array.isArray(checkpoint.choices);
}

export function choiceMap(choices) {
  return new Map(choices.filter(c => Number.isInteger(c.decisionId) && Number.isInteger(c.optionIndex))
    .map(c => [c.decisionId, c.optionIndex]));
}

export function resumePrompt(title) {
  return new Promise(resolve => {
    const dialog = document.createElement('dialog');
    dialog.style.cssText = 'background:#101619;color:#e8eeeb;border:1px solid #586665;padding:24px;max-width:80vw;';
    const text = document.createElement('p');
    text.textContent = `继续上次的阅读位置？${title ? `\n${title}` : ''}`;
    dialog.append(text);
    const finish = value => { dialog.close(); dialog.remove(); resolve(value); };
    for (const [label, value] of [['从头阅读', false], ['继续阅读', true]]) {
      const button = document.createElement('button'); button.textContent = label;
      button.style.cssText = 'padding:10px 20px;margin:8px;background:#253236;color:white;border:1px solid #85928e;';
      button.onclick = () => finish(value); dialog.append(button);
    }
    dialog.addEventListener('cancel', event => { event.preventDefault(); finish(false); });
    document.body.append(dialog); dialog.showModal();
  });
}

export function readingNotice(message) {
  const notice = document.createElement('div');
  notice.textContent = message;
  notice.setAttribute('role', 'status');
  notice.style.cssText = 'position:fixed;bottom:25%;left:50%;transform:translateX(-50%);z-index:9999;background:#101619ed;color:white;padding:14px 20px;max-width:80%;';
  document.body.append(notice); setTimeout(() => notice.remove(), 5500);
}
