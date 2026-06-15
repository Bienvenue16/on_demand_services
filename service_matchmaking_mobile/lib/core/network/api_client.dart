import 'package:dio/dio.dart';
import 'dart:async';

import '../constants/api_constants.dart';
import '../errors/app_exception.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient(this._tokenStorage)
      : _dio = Dio(
          BaseOptions(
            baseUrl: ApiConstants.baseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 20),
            headers: const {'Content-Type': 'application/json'},
          ),
        ),
        _refreshDio = Dio(
          BaseOptions(
            baseUrl: ApiConstants.baseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 20),
            headers: const {'Content-Type': 'application/json'},
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );
  }

  final TokenStorage _tokenStorage;
  final Dio _dio;
  final Dio _refreshDio;

  String get baseUrl => _dio.options.baseUrl;

  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final skipAuth = options.extra['skipAuth'] == true;
    if (!skipAuth) {
      final token = await _tokenStorage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final request = err.requestOptions;
    final alreadyRetried = request.extra['retried'] == true;
    final isRefreshCall = request.path.contains('/auth/refresh');

    if (statusCode == 401 && !alreadyRetried && !isRefreshCall) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        final accessToken = await _tokenStorage.readAccessToken();
        request.headers['Authorization'] = 'Bearer $accessToken';
        request.extra['retried'] = true;
        final response = await _dio.fetch(request);
        handler.resolve(response);
        return;
      }
    }

    final detail = _extractErrorMessage(err.response?.data);
    handler.reject(
      DioException(
        requestOptions: request,
        response: err.response,
        type: err.type,
        error: AppException(detail, statusCode: statusCode),
      ),
    );
  }

  Future<bool> _refreshToken() async {
    if (_isRefreshing) {
      final completer = _refreshCompleter;
      if (completer != null) {
        return completer.future;
      }
      return false;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();
    try {
      final refreshToken = await _tokenStorage.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await _tokenStorage.clear();
        _refreshCompleter?.complete(false);
        return false;
      }

      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data ?? <String, dynamic>{};
      final access = (data['access_token'] ?? '').toString();
      final refresh = (data['refresh_token'] ?? '').toString();
      if (access.isEmpty || refresh.isEmpty) {
        await _tokenStorage.clear();
        _refreshCompleter?.complete(false);
        return false;
      }

      await _tokenStorage.saveTokens(accessToken: access, refreshToken: refresh);
      _refreshCompleter?.complete(true);
      return true;
    } on DioException {
      await _tokenStorage.clear();
      _refreshCompleter?.complete(false);
      return false;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
    bool skipAuth = false,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(extra: {'skipAuth': skipAuth}),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required FormData data,
    bool skipAuth = false,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(
          extra: {'skipAuth': skipAuth},
          contentType: 'multipart/form-data',
        ),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? data,
    bool skipAuth = false,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(extra: {'skipAuth': skipAuth}),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? data,
    bool skipAuth = false,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(extra: {'skipAuth': skipAuth}),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    bool skipAuth = false,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
        options: Options(extra: {'skipAuth': skipAuth}),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? query,
    bool skipAuth = false,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        path,
        queryParameters: query,
        options: Options(extra: {'skipAuth': skipAuth}),
      );
      return response.data ?? <dynamic>[];
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) {
    return _tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  Future<void> clearTokens() => _tokenStorage.clear();

  Future<String?> getAccessToken() => _tokenStorage.readAccessToken();

  Future<bool> hasSession() async {
    final access = await _tokenStorage.readAccessToken();
    final refresh = await _tokenStorage.readRefreshToken();
    return (access?.isNotEmpty ?? false) && (refresh?.isNotEmpty ?? false);
  }

  AppException _mapException(DioException error) {
    final existing = error.error;
    if (existing is AppException) return existing;

    return AppException(
      _extractErrorMessage(error.response?.data),
      statusCode: error.response?.statusCode,
    );
  }

  String _extractErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map<String, dynamic>) {
          final msg = first['msg']?.toString();
          if (msg != null && msg.isNotEmpty) {
            return msg;
          }
        }
        final joined = detail.map((e) => e.toString()).join(', ');
        if (joined.isNotEmpty) {
          return joined;
        }
      }
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return 'Une erreur reseau est survenue';
  }

  void dispose() {
    _dio.close();
    _refreshDio.close();
  }
}
