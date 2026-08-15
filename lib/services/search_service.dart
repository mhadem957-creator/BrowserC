import '../utils/validators.dart';

class SearchService {
  SearchService(this.searxngBaseUrl, {this.safeSearch = 0});

  final String searxngBaseUrl;
  final int safeSearch;

  static const String preferredEngines =
      'google,duckduckgo,brave,wikipedia,wikidata,bing';

  String resolveInput(String rawInput) {
    final input = rawInput.trim();
    if (input.isEmpty) return '';
    if (UrlValidator.isLikelyUrl(input)) {
      return UrlValidator.normalize(input);
    }
    return buildSearchUrl(input);
  }

  String buildSearchUrl(String query) {
    final cleaned = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    final encoded = Uri.encodeQueryComponent(cleaned);
    final root = _searchRoot(searxngBaseUrl);
    final ss = safeSearch.clamp(0, 2);
    return '$root$encoded'
        '&categories=general'
        '&language=auto'
        '&time_range='
        '&safesearch=$ss'
        '&engines=$preferredEngines';
  }

  String _searchRoot(String base) {
    final b = base.trim();
    if (b.endsWith('q=')) return b;
    if (b.contains('?')) {
      if (b.endsWith('&') || b.endsWith('=')) return '${b}q=';
      return '$b&q=';
    }
    return '$b?q=';
  }
}
