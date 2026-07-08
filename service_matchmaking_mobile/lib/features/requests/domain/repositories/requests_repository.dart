import '../entities/category.dart';
import '../entities/paginated_result.dart';
import '../entities/proposal.dart';
import '../entities/service_request.dart';

abstract class RequestsRepository {
  Future<List<Category>> getCategories();
  Future<PaginatedResult<ServiceRequest>> getOpenRequests({
    int page = 1,
    int limit = 20,
    String? categoryId,
  });
  Future<List<ServiceRequest>> getMyRequests({
    required String userId,
    String? status,
  });
  Future<ServiceRequest> getRequestById(String requestId);
  Future<String> createRequest({
    required String categoryId,
    required String title,
    required String description,
    required String urgency,
    String? locationAddress,
    double? locationLat,
    double? locationLng,
    List<String> photos = const [],
  });
  Future<String?> uploadRequestImage(String filePath);
  Future<List<Proposal>> getProposalsByRequest(String requestId);
  Future<void> submitProposal({
    required String requestId,
    required String message,
    double? priceEstimate,
  });
  Future<String?> acceptProposal(String proposalId);
  Future<void> declineProposal(String proposalId);
  Future<void> deleteProposal(String proposalId);
  Future<List<Proposal>> getMyProposals();
  Future<void> updateRequestStatus({
    required String requestId,
    required String status,
  });
}
