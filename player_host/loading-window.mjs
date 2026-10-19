/** Select physical source lines using upstream parser boundaries, preserving continuations.
 * This is a host loading policy, not a second interpreter of AVG control flow.
 */
export function loadingWindow(source, parsed, currentLine = 1, dialogueCount = 8) {
  const start = parsed.findIndex(line => line.lineNumber >= currentLine);
  if (start < 0) return [];
  let end = start;
  let texts = 0;
  // Bound command-only passages too; the runtime can always load on demand.
  while (end < parsed.length && end - start < 160) {
    const line = parsed[end++];
    if (line.kind !== 'command' && line.text?.trim() && ++texts >= dialogueCount) break;
  }
  const first = parsed[start]?.lineNumber ?? 1;
  // The parser's implicit endtip can share the final dialogue's line number.
  const boundary = parsed.slice(end).find(line => line.lineNumber > parsed[end - 1]?.lineNumber);
  const last = boundary?.lineNumber ?? source.length + 1;
  return source.slice(first - 1, last - 1);
}
