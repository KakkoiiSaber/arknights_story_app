import { analyzeStoryFlow } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/log/symbolicFlow';
import { entryContentKey } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/log/textEntry';
import type { ParsedLine, RuntimeLogPosition } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/types';
import type { LogLineEntry } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/log/types';

export function readHistory(lines: ParsedLine[], visited: ReadonlySet<number>,
  position: RuntimeLogPosition, variables: Record<string, unknown> = {}): LogLineEntry[] {
  const flow = analyzeStoryFlow(lines, variables);
  const selections = new Map(position.selections.map(s => [s.decisionId, s.optionIndex]));
  const seen = new Set<string>();
  const result: LogLineEntry[] = [];
  for (const emission of [...flow.emissions].sort((a, b) => a.lineIndex - b.lineIndex)) {
    if (!flow.conditions.evaluate(emission.audience, selections)) continue;
    if (emission.kind === 'choice') {
      const selected = selections.get(emission.decisionId);
      if (selected == null) continue;
      result.push({lineIndex: emission.lineIndex, speaker: '', source: 'dialogue',
        spans: [{text: `› ${emission.options.find(o => o.optionIndex === selected)?.label ?? ''}`, color: null}]});
    } else {
      const key = entryContentKey(emission.entry);
      if (!visited.has(emission.entry.lineIndex) || seen.has(key)) continue;
      seen.add(key);
      result.push(emission.entry);
    }
  }
  return result;
}
