import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/query_provider.dart';
import '../models/query_result.dart';

class QueryScreen extends ConsumerStatefulWidget {
  const QueryScreen({super.key});

  @override
  ConsumerState<QueryScreen> createState() => _QueryScreenState();
}

class _QueryScreenState extends ConsumerState<QueryScreen> {
  final _queryController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showSuggestions = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final query = ModalRoute.of(context)?.settings.arguments as String?;
    if (query != null && _queryController.text.isEmpty) {
      _queryController.text = query;
      _submitQuery();
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submitQuery() {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() => _showSuggestions = false);
    ref.read(queryProvider.notifier).submitQuery(query);
  }

  @override
  Widget build(BuildContext context) {
    final queryState = ref.watch(queryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask a Question'),
        actions: [
          if (queryState.result != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.read(queryProvider.notifier).clearResult();
                setState(() => _showSuggestions = true);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Query input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    maxLines: 2,
                    minLines: 1,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _submitQuery(),
                    onTap: () {
                      if (queryState.result == null) {
                        setState(() => _showSuggestions = true);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Ask about facilities, resources, incidents...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _queryController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _queryController.clear();
                                ref.read(queryProvider.notifier).clearResult();
                                setState(() => _showSuggestions = true);
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Voice input button
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: IconButton(
                    icon: const Icon(Icons.mic, color: Colors.white),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Voice input: Enable microphone permission'),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                CircleAvatar(
                  backgroundColor: AppTheme.accentColor,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: queryState.isLoading ? null : _submitQuery,
                  ),
                ),
              ],
            ),
          ),

          // Results area
          Expanded(
            child: queryState.isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Analyzing your query...'),
                      ],
                    ),
                  )
                : queryState.result != null
                    ? _buildResult(queryState.result!)
                    : _showSuggestions
                        ? _buildSuggestions()
                        : _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    final history = ref.read(queryProvider).queryHistory;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (history.isNotEmpty) ...[
          Text(
            'Recent Queries',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
          ),
          const SizedBox(height: 8),
          ...history.take(5).map((q) => _SuggestionChip(
                label: q,
                icon: Icons.history,
                onTap: () {
                  _queryController.text = q;
                  _submitQuery();
                },
              )),
          const Divider(height: 24),
        ],
        Text(
          'Suggested Queries',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
        ),
        const SizedBox(height: 8),
        ...AppConstants.querySuggestions.map(
          (q) => _SuggestionChip(
            label: q,
            icon: Icons.lightbulb_outline,
            onTap: () {
              _queryController.text = q;
              _submitQuery();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Type your question above\nor tap the mic for voice input',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(QueryResult result) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Confidence & metadata bar
          Row(
            children: [
              _ConfidenceBadge(score: result.confidenceScore),
              const Spacer(),
              Text(
                '${result.responseTimeMs}ms',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const SizedBox(width: 8),
              Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
            ],
          ),
          const SizedBox(height: 16),

          // Answer card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.smart_toy, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'AI Response',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  SelectableText(
                    result.answer,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Map markers summary
          if (result.mapMarkers.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Locations Found',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.map, size: 18),
                          label: const Text('View on Map'),
                          onPressed: () =>
                              Navigator.pushNamed(context, '/map'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...result.mapMarkers.take(5).map(
                          (m) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppTheme.statusColor(m.status ?? ''),
                              radius: 16,
                              child: Icon(
                                _markerIcon(m.type),
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            title: Text(m.label, style: const TextStyle(fontSize: 14)),
                            subtitle: Text(
                              '${m.status ?? ''} • ${m.details?['distance_km'] ?? ''}km',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                    if (result.mapMarkers.length > 5)
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/map'),
                        child: Text(
                            'View all ${result.mapMarkers.length} locations'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Data sources
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Data Sources',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...result.dataSources.map(
                    (s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.storage, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(s.name, style: const TextStyle(fontSize: 13)),
                          const Spacer(),
                          Text(
                            '${s.recordCount} records • ${s.freshness}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                icon: Icons.share,
                label: 'Share',
                onTap: () {},
              ),
              _ActionButton(
                icon: Icons.bookmark_outline,
                label: 'Save',
                onTap: () {},
              ),
              _ActionButton(
                icon: Icons.download,
                label: 'Export',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _markerIcon(String type) {
    switch (type) {
      case 'hospital':
        return Icons.local_hospital;
      case 'clinic':
        return Icons.medical_services;
      case 'pharmacy':
        return Icons.local_pharmacy;
      case 'shelter':
        return Icons.house;
      case 'ambulance':
        return Icons.local_shipping;
      default:
        return Icons.location_on;
    }
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final double score;
  const _ConfidenceBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    if (score >= 0.85) {
      color = Colors.green;
      label = 'High Confidence';
    } else if (score >= 0.7) {
      color = Colors.orange;
      label = 'Medium Confidence';
    } else {
      color = Colors.red;
      label = 'Low Confidence';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$label (${(score * 100).toInt()}%)',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.accentColor),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
