import 'dart:convert';
import 'dart:io';

import 'models.dart';

class SearchResult {
  SearchResult({
    required this.title,
    required this.url,
    required this.snippet,
  });

  final String title;
  final String url;
  final String snippet;
}

class SearchResponse {
  const SearchResponse({
    this.answer = '',
    this.items = const [],
    this.images = const [],
  });

  final String answer;
  final List<SearchResult> items;
  final List<String> images;

  bool get isEmpty =>
      answer.trim().isEmpty && items.isEmpty && images.isEmpty;
}

class SearchClient {
  HttpClient? _client;

  void cancel() {
    _client?.close(force: true);
    _client = null;
  }

  Future<List<SearchResult>> search({
    required SearchProviderConfig provider,
    required String apiKey,
    required String query,
  }) async {
    return (await searchDetailed(
      provider: provider,
      apiKey: apiKey,
      query: query,
    ))
        .items;
  }

  Future<SearchResponse> searchDetailed({
    required SearchProviderConfig provider,
    required String apiKey,
    required String query,
  }) async {
    final normalizedQuery = query.trim();
    if (!provider.enabled ||
        provider.baseUrl.trim().isEmpty ||
        normalizedQuery.isEmpty) {
      return const SearchResponse();
    }

    _client = HttpClient();
    try {
      final kind = provider.kind.trim().toLowerCase();
      if (kind == 'brave') {
        return await _searchBrave(provider, apiKey, normalizedQuery);
      }
      if (kind == 'serper') {
        return await _searchSerper(provider, apiKey, normalizedQuery);
      }
      if (kind == 'searxng') {
        return await _searchSearXng(provider, normalizedQuery);
      }
      if (kind == 'exa') {
        return await _searchExa(provider, apiKey, normalizedQuery);
      }
      if (kind == 'linkup') {
        return await _searchLinkUp(provider, apiKey, normalizedQuery);
      }
      if (kind == 'custom') {
        return await _searchCustom(provider, apiKey, normalizedQuery);
      }
      return await _searchTavily(provider, apiKey, normalizedQuery);
    } finally {
      _client?.close();
      _client = null;
    }
  }

  String formatResults(List<SearchResult> results) {
    return formatContext(SearchResponse(items: results));
  }

  String formatContext(SearchResponse response) {
    if (response.isEmpty) {
      return '';
    }
    final buffer = StringBuffer(
      '以下是本轮联网搜索得到的资料。请只在相关时引用，不要编造来源；如果资料不足，说明不足。\n',
    );
    if (response.answer.trim().isNotEmpty) {
      buffer
        ..writeln('直接答案：${response.answer.trim()}')
        ..writeln();
    }
    for (var index = 0; index < response.items.length; index += 1) {
      final item = response.items[index];
      buffer
        ..writeln('${index + 1}. ${item.title}')
        ..writeln('   URL: ${item.url}')
        ..writeln('   摘要: ${item.snippet}');
    }
    return buffer.toString().trim();
  }

  String formatToolResponse(SearchResponse response) {
    final items = <Map<String, Object?>>[];
    for (var index = 0; index < response.items.length; index += 1) {
      final item = response.items[index];
      items.add({
        'id': 's${index + 1}',
        'index': index + 1,
        'title': item.title,
        'url': item.url,
        'text': item.snippet,
      });
    }
    return const JsonEncoder.withIndent('  ').convert({
      if (response.answer.trim().isNotEmpty) 'answer': response.answer.trim(),
      'items': items,
      if (response.images.isNotEmpty) 'images': response.images,
    });
  }

  Future<SearchResponse> _searchBrave(
    SearchProviderConfig provider,
    String apiKey,
    String query,
  ) async {
    final uri = _appendQuery(
      _join(provider.baseUrl, '/res/v1/web/search'),
      {
        'q': query,
        'count': provider.maxResults.toString(),
      },
    );
    final request = await _client!.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (apiKey.trim().isNotEmpty) {
      request.headers.set('X-Subscription-Token', apiKey.trim());
    }
    _applyHeaders(request, provider.customHeadersJson);
    final decoded = await _readJson(request);
    final web = decoded is Map ? decoded['web'] : null;
    final results = web is Map ? web['results'] : null;
    return SearchResponse(items: _parseResults(results));
  }

  Future<SearchResponse> _searchExa(
    SearchProviderConfig provider,
    String apiKey,
    String query,
  ) async {
    final body = <String, Object?>{
      'query': query,
      'numResults': provider.maxResults,
      'contents': {'text': true},
      ..._decodeJsonObject(provider.extraBodyJson),
    };
    final request = await _client!.postUrl(_join(provider.baseUrl, '/search'));
    request.headers.contentType = ContentType.json;
    if (apiKey.trim().isNotEmpty) {
      request.headers.set('x-api-key', apiKey.trim());
    }
    _applyHeaders(request, provider.customHeadersJson);
    request.write(jsonEncode(body));
    final decoded = await _readJson(request);
    return SearchResponse(
      items: _parseResults(decoded is Map ? decoded['results'] : null),
    );
  }

  Future<SearchResponse> _searchSerper(
    SearchProviderConfig provider,
    String apiKey,
    String query,
  ) async {
    final body = <String, Object?>{
      'q': query,
      'num': provider.maxResults,
      ..._decodeJsonObject(provider.extraBodyJson),
    };
    final request = await _client!.postUrl(_join(provider.baseUrl, '/search'));
    request.headers.contentType = ContentType.json;
    if (apiKey.trim().isNotEmpty) {
      request.headers.set('X-API-KEY', apiKey.trim());
    }
    _applyHeaders(request, provider.customHeadersJson);
    request.write(jsonEncode(body));
    final decoded = await _readJson(request);
    if (decoded is Map) {
      return SearchResponse(
        answer: _serperAnswer(decoded),
        items: _parseResults(
          decoded['organic'] ?? decoded['results'] ?? decoded['items'],
        ),
        images: _parseImageUrls(decoded['images']),
      );
    }
    return SearchResponse(items: _parseResults(decoded));
  }

  Future<SearchResponse> _searchSearXng(
    SearchProviderConfig provider,
    String query,
  ) async {
    final uri = _appendQuery(
      _join(provider.baseUrl, '/search'),
      {
        'q': query,
        'format': 'json',
        'language': 'auto',
        'safesearch': '0',
      },
    );
    final request = await _client!.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    _applyHeaders(request, provider.customHeadersJson);
    final decoded = await _readJson(request);
    if (decoded is Map) {
      return SearchResponse(
        answer: _firstListString(decoded['answers']),
        items: _parseResults(decoded['results'] ?? decoded['items']),
      );
    }
    return SearchResponse(items: _parseResults(decoded));
  }

  Future<SearchResponse> _searchLinkUp(
    SearchProviderConfig provider,
    String apiKey,
    String query,
  ) async {
    final body = <String, Object?>{
      'q': query,
      'depth': 'standard',
      'outputType': 'searchResults',
      'maxResults': provider.maxResults,
      ..._decodeJsonObject(provider.extraBodyJson),
    };
    final request =
        await _client!.postUrl(_join(provider.baseUrl, '/v1/search'));
    request.headers.contentType = ContentType.json;
    if (apiKey.trim().isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    }
    _applyHeaders(request, provider.customHeadersJson);
    request.write(jsonEncode(body));
    final decoded = await _readJson(request);
    return SearchResponse(
      items: _parseResults(decoded is Map ? decoded['results'] : decoded),
    );
  }

  Future<SearchResponse> _searchTavily(
    SearchProviderConfig provider,
    String apiKey,
    String query,
  ) async {
    final body = <String, Object?>{
      'api_key': apiKey.trim(),
      'query': query,
      'max_results': provider.maxResults,
      'search_depth': 'advanced',
      'include_answer': true,
      'include_images': true,
      ..._decodeJsonObject(provider.extraBodyJson),
    };
    final request = await _client!.postUrl(_join(provider.baseUrl, '/search'));
    request.headers.contentType = ContentType.json;
    _applyHeaders(request, provider.customHeadersJson);
    request.write(jsonEncode(body));
    final decoded = await _readJson(request);
    if (decoded is Map) {
      return SearchResponse(
        answer: _firstString(
          Map<String, Object?>.from(decoded),
          const ['answer'],
        ),
        items: _parseResults(decoded['results']),
        images: _parseImageUrls(decoded['images']),
      );
    }
    return SearchResponse(items: _parseResults(decoded));
  }

  Future<SearchResponse> _searchCustom(
    SearchProviderConfig provider,
    String apiKey,
    String query,
  ) async {
    final body = <String, Object?>{
      'query': query,
      'max_results': provider.maxResults,
      ..._decodeJsonObject(provider.extraBodyJson),
    };
    final request = await _client!.postUrl(Uri.parse(provider.baseUrl.trim()));
    request.headers.contentType = ContentType.json;
    if (apiKey.trim().isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    }
    _applyHeaders(request, provider.customHeadersJson);
    request.write(jsonEncode(body));
    final decoded = await _readJson(request);
    if (decoded is Map) {
      final map = Map<String, Object?>.from(decoded);
      return SearchResponse(
        answer: _firstString(map, const ['answer', 'summary']),
        items: _parseResults(
          decoded['results'] ?? decoded['data'] ?? decoded['items'],
        ),
        images: _parseImageUrls(decoded['images']),
      );
    }
    return SearchResponse(items: _parseResults(decoded));
  }

  Future<Object?> _readJson(HttpClientRequest request) async {
    final response = await request.close().timeout(const Duration(seconds: 30));
    final raw = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SearchException('搜索失败 (${response.statusCode})：${_compact(raw)}');
    }
    return jsonDecode(raw);
  }

  List<SearchResult> _parseResults(Object? value) {
    if (value is! List) {
      return [];
    }
    final results = <SearchResult>[];
    for (final item in value) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, Object?>.from(item);
      final title = _firstString(map, const ['title', 'name', 'heading']);
      final url = _firstString(map, const ['url', 'link', 'href', 'source']);
      final snippet = _firstString(
        map,
        const [
          'content',
          'text',
          'snippet',
          'description',
          'summary',
          'body',
          'markdown',
          'answer',
        ],
      );
      if (title.isNotEmpty || url.isNotEmpty || snippet.isNotEmpty) {
        results.add(
          SearchResult(
            title: title.isEmpty ? '搜索结果' : title,
            url: url,
            snippet: snippet,
          ),
        );
      }
    }
    return results;
  }

  List<String> _parseImageUrls(Object? value) {
    if (value is! List) {
      return const [];
    }
    final urls = <String>[];
    for (final item in value) {
      if (item is String && item.trim().isNotEmpty) {
        urls.add(item.trim());
        continue;
      }
      if (item is Map) {
        final map = Map<String, Object?>.from(item);
        final url = _firstString(
          map,
          const ['url', 'imageUrl', 'image_url', 'thumbnailUrl', 'thumbnail'],
        );
        if (url.isNotEmpty) {
          urls.add(url);
        }
      }
    }
    return urls;
  }

  String _serperAnswer(Map<dynamic, dynamic> decoded) {
    final map = Map<String, Object?>.from(decoded);
    for (final key in const ['answerBox', 'knowledgeGraph']) {
      final value = map[key];
      if (value is! Map) {
        continue;
      }
      final nested = Map<String, Object?>.from(value);
      final text = _firstString(
        nested,
        const ['answer', 'snippet', 'description', 'title'],
      );
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  String _firstListString(Object? value) {
    if (value is! List) {
      return '';
    }
    for (final item in value) {
      if (item is String && item.trim().isNotEmpty) {
        return item.trim();
      }
    }
    return '';
  }

  Uri _join(String baseUrl, String path) {
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    if (normalized.endsWith(path)) {
      return Uri.parse(normalized);
    }
    return Uri.parse('$normalized$path');
  }

  Uri _appendQuery(Uri uri, Map<String, String> query) {
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...query,
    });
  }

  void _applyHeaders(HttpClientRequest request, String source) {
    for (final entry in _decodeJsonObject(source).entries) {
      request.headers.set(entry.key, entry.value.toString());
    }
  }

  Map<String, Object?> _decodeJsonObject(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return Map<String, Object?>.from(decoded);
      }
    } catch (_) {
      return {};
    }
    return {};
  }

  String _firstString(Map<String, Object?> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num || value is bool) {
        return value.toString();
      }
    }
    return '';
  }

  String _compact(String source) {
    return source.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}

class SearchException implements Exception {
  const SearchException(this.message);

  final String message;

  @override
  String toString() => message;
}
