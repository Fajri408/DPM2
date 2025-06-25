import 'package:flutter/material.dart';
import 'package:seclick/model/log_entry.dart';
import 'package:intl/intl.dart';

class LogHistoryWidget extends StatelessWidget {
  final List<LogEntry> logs;

  const LogHistoryWidget({super.key, required this.logs});

  String _formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return DateFormat('MMM d, y HH:mm').format(date);
    } catch (e) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final isPhishing = log.phishingPercentage > log.safePercentage;
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isPhishing ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: ExpansionTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPhishing ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPhishing ? Icons.warning_rounded : Icons.safety_check,
                color: isPhishing ? Colors.redAccent : Colors.green,
              ),
            ),
            title: Text(
              log.url,
              style: const TextStyle(
                fontFamily: 'Lato',
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _formatTimestamp(log.timestamp),
              style: TextStyle(
                fontFamily: 'Lato',
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPercentageIndicator(
                          "Probability Non-Phishing",
                          log.safePercentage,
                          Colors.green,
                        ),
                        _buildPercentageIndicator(
                          "Probability Phishing",
                          log.phishingPercentage,
                          Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Details",
                      style: TextStyle(
                        fontFamily: 'Lato',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      log.details,
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPercentageIndicator(String label, double percentage, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Lato',
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "${(percentage).toStringAsFixed(1)}%",
          style: TextStyle(
            fontFamily: 'Lato',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

