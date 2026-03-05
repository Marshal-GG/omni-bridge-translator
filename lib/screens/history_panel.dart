import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/services/history_service.dart';
import '../models/history_entry.dart';

class HistoryPanel extends StatelessWidget {
  const HistoryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        title: Row(
          children: const [
            Icon(Icons.history, size: 18, color: Colors.tealAccent),
            SizedBox(width: 10),
            Text(
              'Translation History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.white54,
              size: 18,
            ),
            tooltip: 'Clear History',
            onPressed: () => HistoryService.instance.clear(),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: Container(height: 1, color: Colors.white12),
        ),
      ),
      body: Row(
        children: [
          // ── LEFT: Live Transcriptions ──────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _columnHeader(
                  '📝  Live Transcripts',
                  'Every utterance captured',
                ),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: ValueListenableBuilder<List<HistoryEntry>>(
                    valueListenable: HistoryService.instance.liveEntries,
                    builder: (_, entries, _) {
                      if (entries.isEmpty) {
                        return _emptyState(
                          'No transcriptions yet.\nStart the live translator.',
                        );
                      }
                      return _EntryList(
                        entries: entries,
                        showTranslation: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(width: 1, color: Colors.white12),

          // ── RIGHT: Chunked 5-sec Re-translations ───────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _columnHeader(
                  '🔁  5-Second Re-translations',
                  'Cleaner, context-aware output',
                ),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: ValueListenableBuilder<List<HistoryEntry>>(
                    valueListenable: HistoryService.instance.chunkedEntries,
                    builder: (_, entries, _) {
                      if (entries.isEmpty) {
                        return _emptyState(
                          'Chunks appear every 5 seconds\nonce translation is running.',
                        );
                      }
                      return _EntryList(
                        entries: entries,
                        showTranslation: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _columnHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.tealAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hourglass_empty, color: Colors.white24, size: 32),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryList extends StatefulWidget {
  final List<HistoryEntry> entries;
  final bool showTranslation;
  const _EntryList({required this.entries, required this.showTranslation});

  @override
  State<_EntryList> createState() => _EntryListState();
}

class _EntryListState extends State<_EntryList> {
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(_EntryList old) {
    super.didUpdateWidget(old);
    // Auto-scroll to bottom when new entries arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: widget.entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final entry = widget.entries[i];
        final timeStr = DateFormat('HH:mm:ss').format(entry.timestamp);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timestamp + lang pair
              Row(
                children: [
                  Text(
                    timeStr,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${entry.sourceLang} → ${entry.targetLang}',
                      style: const TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Transcription
              Text(
                entry.transcription,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              if (entry.translation.isNotEmpty &&
                  entry.translation != entry.transcription) ...[
                const SizedBox(height: 4),
                Text(
                  entry.translation,
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
