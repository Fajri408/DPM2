import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:seclick/model/log_entry.dart';
import 'package:http/http.dart' as http;
import 'package:seclick/model/predict_response.dart';

class ApiService {
  static String baseUrl = dotenv.env['API_URL']!;

  static Future<List<LogEntry>> fetchLogs() async {
    final response = await http.get(Uri.parse('$baseUrl/history'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => LogEntry.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch data');
    }
  }

  static Future<PredictResponse> checkUrl(String url) async {
    final response = await http.post(
      Uri.parse('$baseUrl/predict'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"url": url}),
    );

    if (response.statusCode == 200) {
      return PredictResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to predict url');
    }
  }
}
