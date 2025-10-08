enum FeedFilter {
  all('Semua'),
  short('Shorts'),
  request('Request'),
  jastip('Post');

  final String label;

  const FeedFilter(this.label);
}