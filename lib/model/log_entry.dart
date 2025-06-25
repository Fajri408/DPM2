class LogEntry {
  final String timestamp;
  final String url;
  final String details;
  final double phishingPercentage;
  final double safePercentage;

  LogEntry({
    required this.timestamp,
    required this.url,
    required this.details,
    required this.phishingPercentage,
    required this.safePercentage,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: json['timestamp'] ?? '',
      url: json['url'] ?? '',
      details: json['phishing_percentage'] > json['safe_percentage'] ? "Dangerous Link" : "Safe Link",
      phishingPercentage: json['phishing_percentage'] ?? 0.0,
      safePercentage: json['safe_percentage'] ?? 0.0,
    );
  }
}
