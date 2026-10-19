export const GITHUB_ASSETS = 'https://raw.githubusercontent.com/akgcc/arkdata/main/assets';
export const PRTS_ORIGIN = 'https://torappu.prts.wiki';

export function resourceSource() {
  return typeof location !== 'undefined' &&
    new URLSearchParams(location.search).get('resources') === 'prts' ? 'prts' : 'github';
}

// Routing only: upstream continues to interpret every AVG command unchanged.
export function routeAssetURL(raw, source = resourceSource()) {
  if (!raw || source === 'prts') return raw;
  const url = new URL(raw);
  if (url.origin !== PRTS_ORIGIN) return raw;
  if (url.pathname.includes('/__unsupported__/')) {
    throw new Error(`GitHub 立绘缺少 body/index 映射：${decodeURIComponent(url.pathname)}。可切换到 PRTS 资源源。`);
  }
  const families = [
    ['/assets/avg/background/', '/torappu/dynamicassets/avg/backgrounds/'],
    ['/assets/avg/images/', '/torappu/dynamicassets/avg/images/'],
    ['/assets/avg/characters/', '/avg/characters/'],
    ['/assets/audio/', '/torappu/dynamicassets/audio/sound_beta_2/'],
  ];
  for (const [prefix, target] of families) {
    if (url.pathname.startsWith(prefix)) return GITHUB_ASSETS + target + url.pathname.slice(prefix.length);
  }
  throw new Error(`GitHub 资源尚未适配：${url.pathname}。可切换到 PRTS 资源源。`);
}

// Keep PRTS aliases, body counts, offsets and native sizes, replacing only the
// delivery representation with arkdata's precomposed expression/pose PNGs.
export function githubCharacterContext(context) {
  const linkMap = Object.fromEntries(Object.entries(context.linkMap).map(([base, node]) => {
    const array = node.array.map(entry => {
      if (!Number.isInteger(entry.body) || entry.body < 0 ||
          !Number.isInteger(entry.index) || entry.index < 0) {
        // Only fail if this entry is actually referenced by the story. The
        // global table also contains unrelated legacy/custom character nodes.
        return { ...entry, group: -1, image: `__unsupported__/${base}/${entry.name}` };
      }
      const { face, ...rest } = entry;
      return { ...rest, group: -1, image: `${base}#${entry.index + 1}$${entry.body + 1}` };
    });
    return [base, { ...node, array }];
  }));
  return { ...context, linkMap };
}
