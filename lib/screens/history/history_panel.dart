import 'package:flutter/material.dart';
import '../../core/services/history_service.dart';
import '../../models/history_entry.dart';
import 'components/history_app_bar.dart';
import 'components/history_list_components.dart';
import 'components/history_entry_item.dart';

class HistoryPanel extends StatelessWidget {
  const HistoryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: buildHistoryAppBar(context),
      body: Row(
        children: [
          // ── LEFT: Live Transcriptions ──────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildHistoryColumnHeader(
                  '📝  Live Transcripts',
                  'Every utterance captured',
                ),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: ValueListenableBuilder<List<HistoryEntry>>(
                    valueListenable: HistoryService.instance.liveEntries,
                    builder: (_, entries, _) {
                      if (entries.isEmpty) {
                        return buildHistoryEmptyState(
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
                buildHistoryColumnHeader(
                  '🔁  5-Second Re-translations',
                  'Cleaner, context-aware output',
                ),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: ValueListenableBuilder<List<HistoryEntry>>(
                    valueListenable: HistoryService.instance.chunkedEntries,
                    builder: (_, entries, _) {
                      if (entries.isEmpty) {
                        return buildHistoryEmptyState(
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
        return buildHistoryEntryItem(entry);
      },
    );
  }
}
