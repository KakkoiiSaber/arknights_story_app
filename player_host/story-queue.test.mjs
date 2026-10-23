import {test} from 'node:test';
import assert from 'node:assert/strict';
import {StoryQueue, CompletionTransition} from './story-queue.mjs';
import {defaultScript} from './source.mjs';

const entry = (name, title = name) => ({script: defaultScript.replace('0_welcome_to_guide.txt', `${name}.txt`), title});
const sections = [entry('prologue'), entry('battle_beg', '行动前'), entry('battle_end', '行动后')];

test('continue from the selected section in review order, not filename order', () => {
  const queue = new StoryQueue(sections[1].script, JSON.stringify(sections));
  assert.equal(queue.current.title, '行动前');
  assert.equal(queue.next.title, '行动后');
  assert.equal(queue.advance(), true);
  assert.equal(queue.current.script, sections[2].script);
  assert.equal(queue.isStoryEnd, true);
  assert.equal(queue.next, null);
  assert.equal(queue.advance(), false);
});

test('missing, malformed or unrelated queues keep single-section playback', () => {
  for (const input of [null, '{', 'null', '[{}]', '[null]', JSON.stringify([entry('other')]),
    JSON.stringify([{script: 'https://example.com/story.txt'}])]) {
    const queue = new StoryQueue(defaultScript, input);
    assert.equal(queue.current.script, defaultScript);
    assert.equal(queue.next, null);
    assert.equal(queue.advance(), false);
  }
});

test('a finished section advances once; opening a panel restarts the grace period', () => {
  const completion = new CompletionTransition(1000);
  assert.equal(completion.tick(0, false), false);
  assert.equal(completion.tick(999, false), false);
  assert.equal(completion.tick(2000, true), false);
  assert.equal(completion.tick(5000, false), false);
  assert.equal(completion.tick(6000, false), true);
  assert.equal(completion.tick(7000, false), false);
  completion.reset();
  assert.equal(completion.tick(8000, false), false);
  assert.equal(completion.tick(9000, false), true);
});


test('skip confirmation follows the current section summary when advancing', () => {
  const entries = [
    {...entry('first'), summary: '第一节简介', storyName: '淬火尘霾'},
    {...entry('second'), summary: '第二节简介', storyName: '淬火尘霾'},
  ];
  const queue = new StoryQueue(entries[0].script, JSON.stringify(entries));
  assert.equal(queue.current.summary, '第一节简介');
  queue.advance();
  assert.equal(queue.current.summary, '第二节简介');
  assert.equal(queue.current.storyName, '淬火尘霾');
  assert.equal(new StoryQueue(defaultScript, null).current.summary, '');
});
