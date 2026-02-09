import 'package:flutter/material.dart';
import 'package:locode/features/scan/domain/services/deep_analysis_service.dart';
import 'package:locode/features/browser/presentation/pages/safe_browser_page.dart';
import 'package:locode/services/notification_verdict.dart';

class AnalysisBottomSheet extends StatefulWidget {
  final String url;
  final VoidCallback? onReport;

  const AnalysisBottomSheet({super.key, required this.url, this.onReport});

  @override
  State<AnalysisBottomSheet> createState() => _AnalysisBottomSheetState();
}

class _AnalysisBottomSheetState extends State<AnalysisBottomSheet> {
  late final DeepAnalysisService _analysisService;
  Map<String, dynamic>? _result;
  bool _isAnalyzing = true;
  String _error = '';

  final List<String> _stageLabels = [
    'URL Structure Analysis',
    'Redirect Chain Resolution',
    'Page Content Inspection',
    'Community Report Check',
    'Final AI Reasoning',
  ];

  @override
  void initState() {
    super.initState();
    const apiKey = String.fromEnvironment('GEMINI_API_KEY');
    _analysisService = DeepAnalysisService(apiKey);
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    try {
      final apiKey = String.fromEnvironment('GEMINI_API_KEY');
      _analysisService = DeepAnalysisService(apiKey);
      
      final result = await _analysisService.analyzeUrl(
        widget.url,
        onStep: (action, detail) {
          print('[Loco] Bottom sheet step: $action — $detail');
          // We could add local state to show these steps in the bottom sheet UI
        },
      );

      if (mounted) {
        setState(() {
          _result = result;
          _isAnalyzing = false;
        });
        await NotificationVerdict.showVerdictNotification(
          widget.url,
          riskScore: result['risk_score'],
          summary: result['summary'],
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _isAnalyzing ? _buildProgress() : _buildResult(),
                    if (!_isAnalyzing) _buildActions(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    if (_isAnalyzing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔍 Analyzing URL...',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            widget.url,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    final verdict = _result!['verdict'];
    final riskScore = _result!['risk_score'];
    Color color = Colors.green;
    String label = 'VERIFIED SAFE';
    if (verdict == 'dangerous') {
      color = Colors.red;
      label = 'DANGEROUS';
    } else if (verdict == 'suspicious') {
      color = Colors.orange;
      label = 'SUSPICIOUS';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              '$label (Risk: $riskScore/100)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.url,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildProgress() {
    final completedStages = _result?['stages']?.length ?? 0;
    return Column(
      children: [
        ...List.generate(5, (index) {
          final isCompleted = index < completedStages;
          final isProcessing = index == completedStages;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                if (isCompleted)
                  const Icon(Icons.check_circle, color: Colors.green, size: 20)
                else if (isProcessing)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  const Icon(Icons.circle_outlined, color: Colors.grey, size: 20),
                const SizedBox(width: 12),
                Text(
                  _stageLabels[index],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isProcessing ? FontWeight.bold : FontWeight.normal,
                    color: isCompleted ? Colors.black87 : (isProcessing ? Colors.blue : Colors.grey),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: completedStages / 5,
          backgroundColor: Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),
        Text('${(completedStages / 5 * 100).round()}%', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildResult() {
    if (_error.isNotEmpty) {
      return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    }

    final summary = _result!['summary'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          summary,
          style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
        ),
        const SizedBox(height: 20),
        if (_result!['key_findings'] != null) ...[
          const Text('Key Findings:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          ...( _result!['key_findings'] as List).map((finding) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(finding, style: const TextStyle(fontSize: 13))),
              ],
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildActions() {
    final verdict = _result!['verdict'];
    return Column(
      children: [
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: verdict == 'dangerous' ? Colors.grey[200] : Colors.blue,
              foregroundColor: verdict == 'dangerous' ? Colors.black87 : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context); // Close bottom sheet
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SafeBrowserPage(
                    url: widget.url,
                    verdict: verdict,
                    summary: _result!['summary'],
                    riskScore: _result!['risk_score'],
                  ),
                ),
              );
            },
            child: Text(
              verdict == 'dangerous' ? 'Open Anyway (Not Recommended)' : 'Open in Safe Browser',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context); // Close sheet
              if (widget.onReport != null) {
                widget.onReport!();
              }
            },
            child: const Text('Report & Close', style: TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }
}
