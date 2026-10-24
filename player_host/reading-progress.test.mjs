import { test } from 'node:test';
import assert from 'node:assert/strict';
import { chapterKey, scriptHash, restorable, choiceMap } from './reading-progress.mjs';

test('chapter identity ignores resource host and filename extension', () => {
  assert.equal(chapterKey('https://raw.githubusercontent.com/Kengxxiao/ArknightsGameData/master/zh_CN/gamedata/story/obt/main/a.txt'),'obt/main/a');
});
test('hash normalizes Windows line endings', async () => {
  assert.equal(await scriptHash('a\r\nb'),await scriptHash('a\nb'));
  assert.notEqual(await scriptHash('a'),await scriptHash('b'));
});
test('restoration requires compatible script, existing line and unfinished record', () => {
  const checkpoint={scriptHash:'abc',line:8,choices:[]};
  assert.equal(restorable(checkpoint,'abc',[{lineNumber:8}]),true);
  assert.equal(restorable({...checkpoint,completed:true},'abc',[{lineNumber:8}]),false);
  assert.equal(restorable({...checkpoint,completed:true,atEnd:false},'abc',[{lineNumber:8}]),true);
  assert.equal(restorable(checkpoint,'changed',[{lineNumber:8}]),false);
  assert.equal(restorable(checkpoint,'abc',[{lineNumber:2}]),false);
});
test('restoration retains decision IDs and option indexes', () => {
  assert.deepEqual([...choiceMap([{decisionId:4,optionIndex:1},{decisionId:'x',optionIndex:0}])],[[4,1]]);
});
