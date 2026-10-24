import { test } from 'node:test';
import assert from 'node:assert/strict';
import { build } from 'esbuild';
import { choiceMap } from './reading-progress.mjs';

test('pinned PRTS runtime restores the saved branch at the physical source line', async () => {
  const bundle = await build({stdin:{contents:`
    export { StoryRuntime } from './third_party/prts-widgets/src/widgets/StoryPlayer/engine/runtime.ts';
    export { createContext, FakeRenderer, FakeAudio } from './third_party/prts-widgets/tests/helpers/runtimeFakes.ts';
  `,resolveDir:process.cwd(),loader:'ts'},bundle:true,write:false,platform:'node',format:'esm'});
  const {StoryRuntime, createContext, FakeRenderer, FakeAudio} = await import(
    `data:text/javascript;base64,${Buffer.from(bundle.outputFiles[0].text).toString('base64')}`);
  const renderer = new FakeRenderer();
  const runtime = new StoryRuntime(createContext([
    '[name="A"]start',
    '[decision(options="left;right",values="1;2")]',
    '[predicate(references="1")]',
    '[name="A"]left',
    '[predicate(references="2")]',
    '[name="B"]right',
    '[predicate(references="1;2")]',
    '[name="A"]end',
  ]),renderer,new FakeAudio());
  let timer;
  try {
    const reached = new Promise((resolve,reject) => {
      timer=setTimeout(()=>reject(new Error('restore timed out')),3000);
      runtime.seekToLine(6,choiceMap([{decisionId:2,optionIndex:1}]),update => {
        if (update.phase==='reached') resolve();
        else if (update.phase!=='seeking') reject(new Error(update.phase));
      });
    });
    await runtime.start(); await reached;
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(runtime.getDisplayedLineIndex(),6);
    assert.deepEqual(renderer.lastDialogue,{speaker:'B',text:'right'});
    assert.deepEqual(runtime.getLogPosition().selections,[{decisionId:2,optionIndex:1,value:2}]);
    assert.equal(runtime.getAutoPlayState().mode,'default');
  } finally { clearTimeout(timer); runtime.destroy(); }
});
