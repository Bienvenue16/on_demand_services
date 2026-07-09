import '../../../../core/network/api_client.dart';
import 'package:dio/dio.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/paginated_result.dart';
import '../../domain/entities/proposal.dart';
import '../../domain/entities/service_request.dart';
import '../../domain/repositories/requests_repository.dart';

class RequestsRepositoryImpl implements RequestsRepository {
  RequestsRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;
  final Map<String, Map<String, String?>> _userPreviewCache = {};

  @override
  Future<List<Category>> getCategories() async {
    final raw = await _apiClient.getList('/categories', skipAuth: true);
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (item) => Category(
            id: (item['id'] ?? item['_id'] ?? '').toString(),
            name: (item['name'] ?? '').toString(),
            slug: (item['slug'] ?? '').toString(),
            icon: item['icon']?.toString(),
          ),
        )
        .toList();
  }

  @override
  Future<PaginatedResult<ServiceRequest>> getOpenRequests({
    int page = 1,
    int limit = 20,
    String? categoryId,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      'status': 'open',
    };
    if (categoryId != null && categoryId.isNotEmpty) {
      query['category_id'] = categoryId;
    }

    final data = await _apiClient.get('/requests', query: query);

    final dynamic rawItems = data['data'] ?? data['items'] ?? <dynamic>[];
    final rawMapped = (rawItems is List ? rawItems : <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(_mapRequest)
        .toList();
    final items = await _enrichRequestsWithClientPreview(rawMapped);

    return PaginatedResult<ServiceRequest>(
      items: items,
      total:
          int.tryParse((data['total'] ?? items.length).toString()) ??
          items.length,
      page: int.tryParse((data['page'] ?? page).toString()) ?? page,
      limit: int.tryParse((data['limit'] ?? limit).toString()) ?? limit,
    );
  }

  @override
  Future<List<ServiceRequest>> getMyRequests({
    required String userId,
    String? status,
  }) async {
    final query = <String, dynamic>{'page': 1, 'limit': 100};
    if (status != null && status.isNotEmpty) {
      query['status'] = status;
    }

    final data = await _apiClient.get('/requests', query: query);
    final dynamic rawItems = data['data'] ?? data['items'] ?? <dynamic>[];

    final rawMapped = (rawItems is List ? rawItems : <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(_mapRequest)
        .toList();

    final enriched = await _enrichRequestsWithClientPreview(rawMapped);
    return enriched.where((request) => request.clientId == userId).toList();
  }

  @override
  Future<ServiceRequest> getRequestById(String requestId) async {
    final data = await _apiClient.get('/requests/$requestId');
    final mapped = _mapRequest(data, fallbackId: requestId);
    final enriched = await _enrichRequestsWithClientPreview([mapped]);
    return enriched.first;
  }

  @override
  Future<String> createRequest({
    required String categoryId,
    required String title,
    required String description,
    required String urgency,
    String? locationAddress,
    double? locationLat,
    double? locationLng,
    List<String> photos = const [],
  }) async {
    final payload = <String, dynamic>{
      'category_id': categoryId,
      'title': title,
      'description': description,
      'urgency': urgency,
      'photos': photos,
    };

    // Le backend exige des coordonnees reelles si on envoie un lieu : on n'envoie
    // 'location' que si une position GPS a effectivement ete capturee.
    if (locationLat != null && locationLng != null) {
      payload['location'] = {
        'lat': locationLat,
        'lng': locationLng,
        if (locationAddress != null && locationAddress.trim().isNotEmpty)
          'address': locationAddress.trim(),
      };
    }

    final data = await _apiClient.post('/requests', data: payload);
    final id = (data['id'] ?? data['_id'] ?? '').toString();
    return id;
  }

  @override
  Future<String?> uploadRequestImage(String filePath) async {
    final data = await _apiClient.postMultipart(
      '/uploads/image',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'file_type': 'request',
      }),
    );

    return (data['url'] ?? data['file_url'] ?? data['path'])?.toString();
  }

  @override
  Future<List<Proposal>> getProposalsByRequest(String requestId) async {
    final data = await _apiClient.get(
      '/proposals/request/$requestId',
      query: {'page': 1, 'limit': 50},
    );

    final dynamic rawItems = data['data'] ?? data['items'] ?? <dynamic>[];
    final proposals = (rawItems is List ? rawItems : <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (item) => Proposal(
            id: (item['id'] ?? item['_id'] ?? '').toString(),
            requestId: (item['request_id'] ?? requestId).toString(),
            providerId: (item['provider_id'] ?? '').toString(),
            message: (item['message'] ?? '').toString(),
            status: (item['status'] ?? 'pending').toString(),
            providerName: _extractProviderName(item),
            providerAvatarUrl: _extractProviderAvatarUrl(item),
            priceEstimate: _toDoubleOrNull(item['price_estimate']),
            createdAt: DateTime.tryParse((item['created_at'] ?? '').toString()),
          ),
        )
        .toList();

    return _enrichProposalsWithProviderPreview(proposals);
  }

  @override
  Future<void> submitProposal({
    required String requestId,
    required String message,
    double? priceEstimate,
  }) async {
    final payload = <String, dynamic>{
      'request_id': requestId,
      'message': message,
    };
    if (priceEstimate != null) {
      payload['price_estimate'] = priceEstimate;
    }

    await _apiClient.post('/proposals', data: payload);
  }

  @override
  Future<String?> acceptProposal(String proposalId) async {
    final data = await _apiClient.post('/proposals/$proposalId/accept');
    return (data['room_id'] ?? data['roomId'])?.toString();
  }

  @override
  Future<void> declineProposal(String proposalId) async {
    await _apiClient.post('/proposals/$proposalId/decline');
  }

  @override
  Future<void> deleteProposal(String proposalId) async {
    await _apiClient.delete('/proposals/$proposalId');
  }

  @override
  Future<List<Proposal>> getMyProposals() async {
    final data = await _apiClient.get(
      '/proposals/mine',
      query: {'page': 1, 'limit': 100},
    );

    final dynamic rawItems = data['data'] ?? data['items'] ?? <dynamic>[];
    return (rawItems is List ? rawItems : <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((item) {
          final requestMap = _extractRequestMap(item);
          final clientMap = requestMap?['client'];
          final client = clientMap is Map<dynamic, dynamic> ? clientMap : null;
          final location = requestMap?['location'];
          final locationMap = location is Map<dynamic, dynamic>
              ? location
              : null;

          return Proposal(
            id: (item['id'] ?? item['_id'] ?? '').toString(),
            requestId: (item['request_id'] ?? '').toString(),
            providerId: (item['provider_id'] ?? '').toString(),
            message: (item['message'] ?? '').toString(),
            status: (item['status'] ?? 'pending').toString(),
            providerName: _extractProviderName(item),
            providerAvatarUrl: _extractProviderAvatarUrl(item),
            requestTitle: requestMap?['title']?.toString(),
            requestUrgency: requestMap?['urgency']?.toString(),
            requestStatus: requestMap?['status']?.toString(),
            requestPhotos: _extractRequestPhotos(item),
            requestCategoryId: requestMap?['category_id']?.toString(),
            clientId: requestMap?['client_id']?.toString(),
            clientName: client?['full_name']?.toString(),
            clientAvatarUrl:
                (client?['avatar_url']?.toString().trim().isNotEmpty ?? false)
                ? _normalizeMediaUrl(client!['avatar_url'].toString().trim())
                : null,
            clientLocationAddress: locationMap?['address']?.toString(),
            priceEstimate: _toDoubleOrNull(item['price_estimate']),
            createdAt: DateTime.tryParse((item['created_at'] ?? '').toString()),
          );
        })
        .toList();
  }

  @override
  Future<void> updateRequestStatus({
    required String requestId,
    required String status,
  }) async {
    await _apiClient.patch(
      '/requests/$requestId/status',
      data: {'status': status},
    );
  }

  ServiceRequest _mapRequest(Map<dynamic, dynamic> item, {String? fallbackId}) {
    final clientId = _extractClientId(item);
    final location = item['location'];
    final locationMap = location is Map<dynamic, dynamic> ? location : null;
    return ServiceRequest(
      id: (item['id'] ?? item['_id'] ?? fallbackId ?? '').toString(),
      categoryId: (item['category_id'] ?? '').toString(),
      title: (item['title'] ?? '').toString(),
      description: (item['description'] ?? '').toString(),
      urgency: (item['urgency'] ?? 'medium').toString(),
      status: (item['status'] ?? 'open').toString(),
      clientId: clientId,
      clientName: _extractClientName(item),
      clientAvatarUrl: _extractClientAvatarUrl(item),
      locationAddress: _extractLocationAddress(item),
      locationLat: _toDoubleOrNull(locationMap?['lat']),
      locationLng: _toDoubleOrNull(locationMap?['lng']),
      photos: _extractPhotos(item),
      proposalsCount:
          int.tryParse((item['proposals_count'] ?? 0).toString()) ?? 0,
      createdAt: DateTime.tryParse((item['created_at'] ?? '').toString()),
    );
  }

  String? _extractLocationAddress(Map<dynamic, dynamic> item) {
    final location = item['location'];
    if (location is Map<dynamic, dynamic>) {
      return location['address']?.toString();
    }
    return null;
  }

  List<String> _extractPhotos(Map<dynamic, dynamic> item) {
    final photos = item['photos'];
    if (photos is List) {
      return photos
          .map(_extractPhotoValue)
          .whereType<String>()
          .where((url) => url.isNotEmpty)
          .map(_normalizeMediaUrl)
          .toList();
    }
    return const <String>[];
  }

  String? _extractProviderName(Map<dynamic, dynamic> item) {
    final provider = item['provider'];
    if (provider is Map<dynamic, dynamic>) {
      return provider['full_name']?.toString();
    }
    return null;
  }

  String? _extractProviderAvatarUrl(Map<dynamic, dynamic> item) {
    final provider = item['provider'];
    if (provider is Map<dynamic, dynamic>) {
      final raw = (provider['avatar_url'] ?? provider['avatar'])?.toString();
      if (raw != null && raw.trim().isNotEmpty) {
        return _normalizeMediaUrl(raw.trim());
      }
    }
    return null;
  }

  String? _extractClientId(Map<dynamic, dynamic> item) {
    final direct = item['client_id'];
    if (direct is Map<dynamic, dynamic>) {
      final mapped = (direct['id'] ?? direct['_id'])?.toString();
      if (mapped != null && mapped.trim().isNotEmpty) {
        return mapped.trim();
      }
    }
    if (direct != null) {
      final raw = direct.toString().trim();
      if (raw.isNotEmpty) {
        return raw;
      }
    }

    final client = item['client'];
    if (client is Map<dynamic, dynamic>) {
      final mapped = (client['id'] ?? client['_id'])?.toString();
      if (mapped != null && mapped.trim().isNotEmpty) {
        return mapped.trim();
      }
    }

    return null;
  }

  String? _extractClientName(Map<dynamic, dynamic> item) {
    final client = item['client'];
    if (client is Map<dynamic, dynamic>) {
      final name = (client['full_name'] ?? client['name'])?.toString();
      if (name != null && name.trim().isNotEmpty) {
        return name.trim();
      }
    }

    final clientIdAsMap = item['client_id'];
    if (clientIdAsMap is Map<dynamic, dynamic>) {
      final name = (clientIdAsMap['full_name'] ?? clientIdAsMap['name'])
          ?.toString();
      if (name != null && name.trim().isNotEmpty) {
        return name.trim();
      }
    }

    final directName = (item['client_name'] ?? item['client_full_name'])
        ?.toString();
    if (directName != null && directName.trim().isNotEmpty) {
      return directName.trim();
    }

    return null;
  }

  String? _extractClientAvatarUrl(Map<dynamic, dynamic> item) {
    final client = item['client'];
    if (client is Map<dynamic, dynamic>) {
      final raw = (client['avatar_url'] ?? client['avatar'])?.toString();
      if (raw != null && raw.trim().isNotEmpty) {
        return _normalizeMediaUrl(raw.trim());
      }
    }

    final clientIdAsMap = item['client_id'];
    if (clientIdAsMap is Map<dynamic, dynamic>) {
      final raw = (clientIdAsMap['avatar_url'] ?? clientIdAsMap['avatar'])
          ?.toString();
      if (raw != null && raw.trim().isNotEmpty) {
        return _normalizeMediaUrl(raw.trim());
      }
    }

    final direct = (item['client_avatar_url'] ?? item['client_avatar'])
        ?.toString();
    if (direct != null && direct.trim().isNotEmpty) {
      return _normalizeMediaUrl(direct.trim());
    }

    return null;
  }

  Map<dynamic, dynamic>? _extractRequestMap(Map<dynamic, dynamic> item) {
    final request = item['request'];
    if (request is Map<dynamic, dynamic>) {
      return request;
    }
    return null;
  }

  List<String> _extractRequestPhotos(Map<dynamic, dynamic> item) {
    final request = _extractRequestMap(item);
    if (request == null) {
      return const <String>[];
    }

    final photos = request['photos'];
    if (photos is List) {
      return photos
          .map(_extractPhotoValue)
          .whereType<String>()
          .where((url) => url.isNotEmpty)
          .map(_normalizeMediaUrl)
          .toList();
    }
    return const <String>[];
  }

  String? _extractPhotoValue(dynamic value) {
    if (value is String) {
      final raw = value.trim();
      return raw.isEmpty ? null : raw;
    }

    if (value is Map<dynamic, dynamic>) {
      final raw = (value['url'] ?? value['file_url'] ?? value['path'])
          ?.toString()
          .trim();
      if (raw == null || raw.isEmpty) {
        return null;
      }
      return raw;
    }

    return null;
  }

  String _normalizeMediaUrl(String rawUrl) {
    final baseUri = Uri.parse(_apiClient.baseUrl);

    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      final parsed = Uri.tryParse(rawUrl);
      if (parsed != null) {
        final host = parsed.host.toLowerCase();
        if (host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0') {
          return Uri(
            scheme: baseUri.scheme,
            host: baseUri.host,
            port: baseUri.hasPort ? baseUri.port : null,
            path: parsed.path,
            query: parsed.hasQuery ? parsed.query : null,
          ).toString();
        }
      }
      return rawUrl;
    }

    if (rawUrl.startsWith('//')) {
      return '${baseUri.scheme}:$rawUrl';
    }

    final normalizedPath = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
    return Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
      path: normalizedPath,
    ).toString();
  }

  double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Future<List<Proposal>> _enrichProposalsWithProviderPreview(
    List<Proposal> proposals,
  ) async {
    if (proposals.isEmpty) return proposals;

    final idsToFetch = proposals
        .where((p) => p.providerName == null && p.providerId.isNotEmpty)
        .map((p) => p.providerId)
        .where((id) => !_userPreviewCache.containsKey(id))
        .toSet()
        .toList();

    final freshPreviews = <String, Map<String, String?>>{};
    for (final providerId in idsToFetch) {
      try {
        final data = await _apiClient.get('/users/$providerId');
        final name = (data['full_name'] ?? data['name'])?.toString().trim();
        final avatar = data['avatar_url']?.toString().trim();
        final preview = <String, String?>{
          'full_name': (name != null && name.isNotEmpty) ? name : null,
          'avatar_url': (avatar != null && avatar.isNotEmpty)
              ? _normalizeMediaUrl(avatar)
              : null,
        };
        freshPreviews[providerId] = preview;
        // On ne memorise durablement que si un avatar existe : sinon un compte
        // fraichement cree (sans photo au premier chargement) resterait sans
        // avatar pour le reste de la session, meme apres l'upload d'une photo.
        if (preview['avatar_url'] != null) {
          _userPreviewCache[providerId] = preview;
        }
      } catch (_) {
        freshPreviews[providerId] = const {
          'full_name': null,
          'avatar_url': null,
        };
      }
    }

    return proposals.map((proposal) {
      if (proposal.providerName != null && proposal.providerAvatarUrl != null) {
        return proposal;
      }
      final preview =
          _userPreviewCache[proposal.providerId] ??
          freshPreviews[proposal.providerId];
      if (preview == null) return proposal;
      return Proposal(
        id: proposal.id,
        requestId: proposal.requestId,
        providerId: proposal.providerId,
        message: proposal.message,
        status: proposal.status,
        providerName: proposal.providerName ?? preview['full_name'],
        providerAvatarUrl: proposal.providerAvatarUrl ?? preview['avatar_url'],
        requestTitle: proposal.requestTitle,
        requestUrgency: proposal.requestUrgency,
        requestStatus: proposal.requestStatus,
        requestPhotos: proposal.requestPhotos,
        priceEstimate: proposal.priceEstimate,
        createdAt: proposal.createdAt,
      );
    }).toList();
  }

  Future<List<ServiceRequest>> _enrichRequestsWithClientPreview(
    List<ServiceRequest> requests,
  ) async {
    if (requests.isEmpty) {
      return requests;
    }

    final idsToFetch = requests
        .map((request) => request.clientId)
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .where((id) {
          final cached = _userPreviewCache[id];
          return cached == null;
        })
        .toSet()
        .toList();

    final freshPreviews = <String, Map<String, String?>>{};
    for (final clientId in idsToFetch) {
      try {
        final data = await _apiClient.get('/users/$clientId');
        final name = (data['full_name'] ?? data['name'])?.toString().trim();
        final avatar = data['avatar_url']?.toString().trim();
        final preview = <String, String?>{
          'full_name': (name != null && name.isNotEmpty) ? name : null,
          'avatar_url': (avatar != null && avatar.isNotEmpty)
              ? _normalizeMediaUrl(avatar)
              : null,
        };
        freshPreviews[clientId] = preview;
        // Idem : on ne fige le cache que si un avatar existe reellement.
        if (preview['avatar_url'] != null) {
          _userPreviewCache[clientId] = preview;
        }
      } catch (_) {
        freshPreviews[clientId] = const {'full_name': null, 'avatar_url': null};
      }
    }

    return requests.map((request) {
      final clientId = request.clientId;
      if (clientId == null || clientId.trim().isEmpty) {
        return request;
      }

      final preview =
          _userPreviewCache[clientId.trim()] ?? freshPreviews[clientId.trim()];
      if (preview == null) {
        return request;
      }

      return request.copyWith(
        clientName: request.clientName ?? preview['full_name'],
        clientAvatarUrl: request.clientAvatarUrl ?? preview['avatar_url'],
      );
    }).toList();
  }
}
