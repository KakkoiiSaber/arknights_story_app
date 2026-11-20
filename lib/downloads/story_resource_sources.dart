typedef StorySourceResolver = List<Uri> Function(Uri original);

/// The renderer already provides the canonical PRTS URL.
List<Uri> storyResourceSources(Uri original) => [original];

bool isGitHubRaw(Uri uri) => uri.host == 'raw.githubusercontent.com';
