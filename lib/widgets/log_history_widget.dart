import 'package:flutter/material.dart';
import 'package:seclick/model/log_entry.dart';

class LogHistoryWidget extends StatelessWidget {
  final List<LogEntry> logs;

  const LogHistoryWidget({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            elevation: 2,
            child: ExpansionTile(
              leading: log.phishingPercentage > log.safePercentage 
                ? const Icon(Icons.warning_rounded, color: Colors.redAccent)
                : const Icon(Icons.safety_check, color: Colors.green),
              title: Text(log.url),
              subtitle: Text(log.timestamp),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text("Bahaya: ${log.phishingPercentage}"),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text("Aman: ${log.safePercentage}"),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(log.details),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
    );
  }
}
