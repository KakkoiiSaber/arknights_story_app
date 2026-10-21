typedef StorySourceResolver = List<Uri> Function(Uri original);

/// Delivery candidates only: PRTS remains the canonical ID and parser mapping.
/// PRTS split character/face images cannot be replaced by arkdata's composed
/// portraits, even when a similarly named file happens to exist.
List<Uri> storyResourceSources(Uri original) {
  if (original.origin != 'https://torappu.prts.wiki' ||
      original.hasQuery ||
      original.hasFragment ||
      original.userInfo.isNotEmpty) {
    return [original];
  }
  const folders = {
    '/assets/avg/background/': 'avg/backgrounds/',
    '/assets/avg/images/': 'avg/images/',
    '/assets/audio/': 'audio/sound_beta_2/',
  };
  for (final entry in folders.entries) {
    if (!original.path.startsWith(entry.key)) continue;
    final suffix = original.pathSegments.skip(
      entry.key.split('/').where((part) => part.isNotEmpty).length,
    );
    final raw = Uri(
      scheme: 'https',
      host: 'raw.githubusercontent.com',
      pathSegments: [
        'akgcc',
        'arkdata',
        'main',
        'assets',
        'torappu',
        'dynamicassets',
        ...entry.value.split('/').where((s) => s.isNotEmpty),
        ...suffix,
      ],
    );
    return [raw, original];
  }
  return [original];
}

bool isGitHubRaw(Uri uri) => uri.host == 'raw.githubusercontent.com';
