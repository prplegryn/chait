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
    final normalizedQuery = query.trim();
    if (!provider.enabled ||
        provider.baseUrl.trim().isEmpty ||
        normalizedQuery.isEmpty) {
      return [];
    }

    _client = HttpClient();
    try {
      final kind = provider.kind.trim().toLowerCase();
      if (kind == 'brave') {
        return await _searchBrave(provider, apiKey, normalizedQuery);
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
    if (results.isEmpty) {
      return '';
    }
    final buffer = StringBuffer(
      '以下是本轮联网搜索得到的资料。请只在相关时引用，不要编造来源；如果资料不足，说明不足。\n',
    );
    for (var index = 0; index < results.length; index += 1) {
      final item = results[index];
      buffer
        ..writeln('${index + 1}. ${item.title}')
        ..writeln('   URL: ${item.url}')
        ..writeln('   摘要: ${item.snippet}');
    }
    return buffer.toString().trim();
  }

  Future<List<SearchResult>> _searchBrave(
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
    return _parseResults(results);
  }

  Future<List<SearchResult>> _searchExa(
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
    return _parseResults(decoded is Map ? decoded['results'] : null);
  }

  Future<List<SearchResult>> _searchLinkUp(
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
    return _parseResults(decoded is Map ? decoded['results'] : decoded);
  }

  Future<List<SearchResult>> _searchTavily(
    SearchProviderConfig provider,
    String apiKey,
    String query,
  ) async {
    final body = <String, Object?>{
      'api_key': apiKey.trim(),
      'query': query,
      'max_results': provider.maxResults,
      'search_depth': 'basic',
      ..._decodeJsonObject(provider.extraBodyJson),
    };
    final request = await _client!.postUrl(_join(provider.baseUrl, '/search'));
    request.headers.contentType = ContentType.json;
    _applyHeaders(request, provider.customHeadersJson);
    request.write(jsonEncode(body));
    final decoded = await _readJson(request);
    return _parseResults(decoded is Map ? decoded['results'] : decoded);
  }

  Future<List<SearchResult>> _searchCustom(
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
      return _parseResults(
        decoded['results'] ?? decoded['data'] ?? decoded['items'],
      );
    }
    return _parseResults(decoded);
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
      final title = _firstString(map, const ['title', 'name']);
      final url = _firstString(map, const ['url', 'link', 'href']);
      final snippet = _firstString(
        map,
        const ['content', 'text', 'snippet', 'description', 'summary'],
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

  Uri _join(String baseUrl, String path) {
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
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
