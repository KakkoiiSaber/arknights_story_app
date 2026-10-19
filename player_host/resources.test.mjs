import {test} from 'node:test';
import assert from 'node:assert/strict';
import {GITHUB_ASSETS, resourceSource, routeAssetURL, githubCharacterContext} from './resources.mjs';

test('default provider is GitHub with an explicit unchanged PRTS baseline', () => {
  assert.equal(resourceSource(), 'github');
  const value = 'https://torappu.prts.wiki/assets/audio/music/demo.mp3';
  assert.equal(routeAssetURL(value,'prts'),value);
  assert.equal(routeAssetURL(null,'github'),null);
});
test('maps image, background and audio directory differences', () => {
  assert.equal(routeAssetURL('https://torappu.prts.wiki/assets/avg/background/bg.png'),
      GITHUB_ASSETS+'/torappu/dynamicassets/avg/backgrounds/bg.png');
  assert.equal(routeAssetURL('https://torappu.prts.wiki/assets/avg/images/cg.png'),
      GITHUB_ASSETS+'/torappu/dynamicassets/avg/images/cg.png');
  assert.equal(routeAssetURL('https://torappu.prts.wiki/assets/audio/music/demo.mp3'),
      GITHUB_ASSETS+'/torappu/dynamicassets/audio/sound_beta_2/music/demo.mp3');
  const local = 'http://localhost:8080/prts-player/metadata/assets/avg/character.json';
  assert.equal(routeAssetURL(local),local);
});
test('preserves layout and aliases while flattening delivery body/expression', () => {
  const input = { audioVariables: {key:'value'}, linkMap: {hero:{
    pos:{x:10,y:203},size:{x:1090,y:1090},bodies:[2,3],
    groups:[{mode:'face_overlay',base:'old-body'}],
    array:[{name:'hero_angry',alias:'angry',body:1,index:2,group:0,face:'old-face'}],
  }}};
  const copy = structuredClone(input);
  const result = githubCharacterContext(input);
  assert.deepEqual(input,copy);
  assert.deepEqual(result.linkMap.hero.pos,input.linkMap.hero.pos);
  assert.deepEqual(result.linkMap.hero.size,input.linkMap.hero.size);
  assert.deepEqual(result.linkMap.hero.bodies,[2,3]);
  assert.equal(result.linkMap.hero.array[0].alias,'angry');
  assert.equal(result.linkMap.hero.array[0].image,'hero#3$2');
  assert.equal(result.linkMap.hero.array[0].group,-1);
  assert.equal(routeAssetURL('https://torappu.prts.wiki/assets/avg/characters/hero%233%242.png'),
      GITHUB_ASSETS+'/avg/characters/hero%233%242.png');
});
test('legacy metadata only fails if referenced; unsupported assets never silently fall back', () => {
  const result = githubCharacterContext({linkMap:{custom:{array:[{name:'special',group:-1,image:'old'}]}}});
  assert.match(result.linkMap.custom.array[0].image,/^__unsupported__\//);
  assert.throws(()=>routeAssetURL('https://torappu.prts.wiki/assets/avg/characters/__unsupported__/custom/special.png'),/body\/index/);
  assert.throws(()=>routeAssetURL('https://torappu.prts.wiki/assets/video/test.mp4'),/尚未适配/);
});
