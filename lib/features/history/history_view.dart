import 'package:neurovoice_app/core/constants/colors.dart';
import 'package:neurovoice_app/core/constants/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  Future<void> _clearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Clear History"),
        content: const Text(
          "This will permanently delete all past test results. "
          "This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final voiceBox = Hive.box('voice_results');
      final faceBox = Hive.box('facial_results');
      await voiceBox.clear();
      await faceBox.clear();
    }
  }

  Color _riskColor(String level) {
    switch (level) {
      case "High":
        return AppColors.red;
      case "Medium":
        return AppColors.orange;
      default:
        return AppColors.green;
    }
  }

  IconData _riskIcon(String level) {
    switch (level) {
      case "High":
        return Icons.warning;
      case "Medium":
        return Icons.info_outline;
      default:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceBox = Hive.box('voice_results');
    final faceBox = Hive.box('facial_results');

    return Scaffold(
      appBar: AppBar(
        title: const Text("History", style: AppTextStyles.title),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 26),
            tooltip: "Clear history",
            onPressed: () => _clearHistory(context),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          voiceBox.listenable(),
          faceBox.listenable(),
        ]),
        builder: (_, __) {
          final List<Map<String, dynamic>> allResults = [];

          // ---- VOICE RESULTS ----
          for (var item in voiceBox.values) {
            allResults.add({
              ...Map<String, dynamic>.from(item),
              'testType': 'voice',
            });
          }

          // ---- FACE RESULTS ----
          for (var item in faceBox.values) {
            final map = Map<String, dynamic>.from(item);

            allResults.add({
              'riskLevel': map['level'],
              'riskScore': (map['percentage'] as int) / 100.0,
              'blinkRate': map['blinkRate'],
              'motion': map['motion'],
              'asymmetry': map['asymmetry'],
              'timestamp': map['timestamp'],
              'testType': 'face',
            });
          }

          if (allResults.isEmpty) {
            return const Center(
              child: Text(
                "No history yet",
                style: TextStyle(color: AppColors.gray),
              ),
            );
          }

          // Newest first
          allResults.sort(
            (a, b) => DateTime.parse(
              b['timestamp'],
            ).compareTo(DateTime.parse(a['timestamp'])),
          );

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: allResults.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, index) {
              final item = allResults[index];

              final double riskScore = (item['riskScore'] as num).toDouble();
              final String riskLevel = item['riskLevel'];
              final String testType = item['testType'];

              final DateTime time = DateTime.parse(item['timestamp']).toLocal();

              final Color accent = _riskColor(riskLevel);

              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_riskIcon(riskLevel), color: accent),
                ),
                title: Text(
                  "Risk Level: $riskLevel",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Score: ${(riskScore * 100).toStringAsFixed(1)}%"),
                    const SizedBox(height: 4),
                    Text(
                      "Test: ${testType.toUpperCase()}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    // 👇 Facial-only metrics
                    if (testType == 'face') ...[
                      const SizedBox(height: 4),
                      Text(
                        "Blink: ${item['blinkRate'].toStringAsFixed(1)}/min • "
                        "Motion: ${item['motion'].toStringAsFixed(2)} • "
                        "Asym: ${item['asymmetry'].toStringAsFixed(3)}",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
                trailing: Text(
                  "${time.day}/${time.month}/${time.year}\n"
                  "${time.hour}:${time.minute.toString().padLeft(2, '0')}",
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
