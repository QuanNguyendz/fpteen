class ReportModel {
  const ReportModel({
    required this.id,
    required this.reporterId,
    required this.storeId,
    required this.content,
    required this.status,
    this.adminNote,
    required this.createdAt,
    this.storeName,
    this.reporterName,
  });

  final String id;
  final String reporterId;
  final String storeId;
  final String content;
  final String status;
  final String? adminNote;
  final DateTime createdAt;
  final String? storeName;
  final String? reporterName;

  bool get isPending => status == 'pending';
  bool get isResolved => status == 'resolved';

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    final storeJson = json['stores'] as Map<String, dynamic>?;
    final userJson = json['users'] as Map<String, dynamic>?;
    return ReportModel(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String,
      storeId: json['store_id'] as String,
      content: json['content'] as String,
      status: json['status'] as String,
      adminNote: json['admin_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      storeName: storeJson?['name'] as String?,
      reporterName: userJson?['full_name'] as String?,
    );
  }
}
