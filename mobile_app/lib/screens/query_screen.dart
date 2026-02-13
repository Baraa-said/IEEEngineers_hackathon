import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/query_provider.dart';
import '../providers/language_provider.dart';
import '../models/query_result.dart';
import '../widgets/scroll_reveal.dart';

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
    final lang = ref.read(languageProvider);
    ref.read(queryProvider.notifier).submitQuery(query, language: lang);
  }

  @override
  Widget build(BuildContext context) {
    final queryState = ref.watch(queryProvider);
    final lang = ref.watch(languageProvider);
    final tr = (String key) => S.t(key, lang);

    return Directionality(
      textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('ask_question')),
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
            // Input bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _submitQuery(),
                      onTap: () {
                        if (queryState.result == null) setState(() => _showSuggestions = true);
                      },
                      decoration: InputDecoration(
                        hintText: tr('ask_hint'),
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
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppTheme.accentColor,
                    radius: 22,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: queryState.isLoading ? null : _submitQuery,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: queryState.isLoading
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(tr('analyzing')),
                      ],
                    ))
                  : queryState.error != null && queryState.result == null
                      ? Center(child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 12),
                              Text(queryState.error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 14)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _submitQuery,
                                icon: const Icon(Icons.refresh),
                                label: Text(tr('try_again')),
                              ),
                            ],
                          ),
                        ))
                      : queryState.result != null
                          ? _buildResult(queryState.result!, tr, lang)
                          : _showSuggestions
                              ? _buildSuggestions(tr, lang)
                              : Center(child: Text(tr('type_question'), style: const TextStyle(color: Colors.grey))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions(String Function(String) tr, String lang) {
    final history = ref.read(queryProvider).queryHistory;
    final suggestions = [tr('q1'), tr('q2'), tr('q3'), tr('q4')];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (history.isNotEmpty) ...[
          ScrollReveal(index: 0, child: Text(tr('recent_queries'), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 13))),
          const SizedBox(height: 6),
          ...history.take(3).toList().asMap().entries.map((e) => ScrollReveal(index: e.key + 1, child: _chipTile(e.value, Icons.history))),
          const Divider(height: 20),
        ],
        ScrollReveal(index: 4, child: Text(tr('suggested_queries'), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 13))),
        const SizedBox(height: 6),
        ...suggestions.asMap().entries.map((e) => ScrollReveal(index: e.key + 5, child: _chipTile(e.value, Icons.lightbulb_outline))),
      ],
    );
  }

  Widget _chipTile(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: Icon(icon, size: 18, color: Colors.grey[600]),
        title: Text(label, style: const TextStyle(fontSize: 13)),
        trailing: const Icon(Icons.chevron_right, size: 16),
        onTap: () {
          _queryController.text = label;
          _submitQuery();
        },
      ),
    );
  }

  Widget _buildResult(QueryResult result, String Function(String) tr, String lang) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Confidence
          Row(
            children: [
              _ConfidenceBadge(score: result.confidenceScore, tr: tr),
              const Spacer(),
              Text('${result.responseTimeMs}ms', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),

          // Answer
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.smart_toy, color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 6),
                    Text(tr('ai_response'), style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 14)),
                  ]),
                  const Divider(),
                  SelectableText(result.answer, style: const TextStyle(fontSize: 14, height: 1.5)),
                ],
              ),
            ),
          ),

          // Map markers
          if (result.mapMarkers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(tr('locations_found'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        TextButton(
                          child: Text(tr('view_on_map'), style: const TextStyle(fontSize: 12)),
                          onPressed: () => Navigator.pushNamed(context, '/map'),
                        ),
                      ],
                    ),
                    ...result.mapMarkers.take(5).map((m) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.statusColor(m.status ?? ''),
                            radius: 14,
                            child: Icon(_markerIcon(m.type), color: Colors.white, size: 14),
                          ),
                          title: Text(m.label, style: const TextStyle(fontSize: 13)),
                          subtitle: Text('${m.status ?? ''}', style: const TextStyle(fontSize: 11)),
                        )),
                  ],
                ),
              ),
            ),
          ],

          // Data sources
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('data_sources'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  ...result.dataSources.map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          const Icon(Icons.storage, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(s.name, style: const TextStyle(fontSize: 12)),
                          const Spacer(),
                          Text('${s.recordCount} • ${s.freshness}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ]),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _markerIcon(String type) {
    switch (type) {
      case 'hospital': return Icons.local_hospital;
      case 'clinic': return Icons.medical_services;
      case 'shelter': return Icons.house;
      case 'ambulance': return Icons.local_shipping;
      default: return Icons.location_on;
    }
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final double score;
  final String Function(String) tr;
  const _ConfidenceBadge({required this.score, required this.tr});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    if (score >= 0.85) {
      color = Colors.green;
      label = tr('high_confidence');
    } else if (score >= 0.7) {
      color = Colors.orange;
      label = tr('medium_confidence');
    } else {
      color = Colors.red;
      label = tr('low_confidence');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text('$label (${(score * 100).toInt()}%)',
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
