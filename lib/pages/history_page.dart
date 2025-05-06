import 'package:flutter/material.dart';
import 'package:seclick/services/api_service.dart';
import 'package:seclick/widgets/log_history_widget.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("History"),
        backgroundColor: const Color(0xFF027373),
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          fontFamily: 'Lato',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ), 
      body: FutureBuilder(
        future: ApiService.fetchLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData) {
            return const Center(child: Text("No history available"));
          }

          final history = snapshot.data!;
          return LogHistoryWidget(logs: history);
        },
      ),
    );
  }
}
