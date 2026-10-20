export const defaultScript = 'https://raw.githubusercontent.com/Kengxxiao/ArknightsGameData/master/zh_CN/gamedata/story/obt/guide/beg/0_welcome_to_guide.txt';

export function resolveScriptURL(input) {
  const url = new URL(input || defaultScript);
  if (url.protocol !== 'https:' || url.hostname !== 'raw.githubusercontent.com' ||
      url.username || url.password || url.port || url.search || url.hash ||
      !/^\/Kengxxiao\/ArknightsGameData(?:_YoStar)?\/[^/]+\/(?:zh_CN|en_US|ja_JP|ko_KR)\/gamedata\/story\/.+\.txt$/.test(url.pathname)) {
    throw new Error('不支持此剧情地址，请从故事主题页重新进入。');
  }
  return url;
}
