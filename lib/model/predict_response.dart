class PredictResponse {
  final List<dynamic> features;
  final double phishingPercentage;
  final double safePercentage;
  final String url;

  PredictResponse({
    required this.features,
    required this.phishingPercentage,
    required this.safePercentage,
    required this.url,
  });

  factory PredictResponse.fromJson(Map<String, dynamic> json) {
    return PredictResponse(
      features: json['features'] ?? [],
      phishingPercentage: json['phishing_percentage'] ?? 0.0,
      safePercentage: json['safe_percentage'] ?? 0.0,
      url: json['url'] ?? ''
    );
  }
}
