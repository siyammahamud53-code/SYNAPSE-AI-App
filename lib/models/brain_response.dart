class BrainResponse {
  final String id;
  final String status;
  final Map<String, dynamic> data;

  BrainResponse({
    required this.id,
    required this.status,
    required this.data,
  });

  factory BrainResponse.fromJson(Map<String, dynamic> json) {
    return BrainResponse(
      id: json['id'] ?? json['commandId'] ?? '',
      status: json['status'] ?? 'completed',
      data: json['data'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'data': data,
    };
  }
}
