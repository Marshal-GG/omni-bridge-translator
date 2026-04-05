import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:omni_bridge/features/settings/presentation/blocs/settings_bloc.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/settings_event.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/settings_state.dart';
import 'package:omni_bridge/core/constants/languages.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'package:omni_bridge/features/translation/data/datasources/translation_rest_datasource.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_bloc.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_event.dart';
import 'package:omni_bridge/features/settings/presentation/widgets/settings_helpers.dart';
import 'package:omni_bridge/core/widgets/omni_card.dart';
import 'package:omni_bridge/core/widgets/omni_dropdown.dart';

import 'package:omni_bridge/core/widgets/omni_badge.dart';

Widget buildLanguagesTab(BuildContext context, SettingsState state) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionLabel('Source'),
                  const SizedBox(height: 6),
                  _langDropdown(
                    context: context,
                    items: appLanguages.entries
                        .where((e) => e.key != 'none')
                        .toList(),
                    selected: MapEntry(
                      state.settings.sourceLang,
                      appLanguages[state.settings.sourceLang] ??
                          state.settings.sourceLang,
                    ),
                    hint:
                        appLanguages[state.settings.sourceLang] ??
                        'Search language...',
                    onSelect: (item) {
                      context.read<SettingsBloc>().add(
                        UpdateTempSettingEvent(sourceLang: item.key),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 24, 12, 0),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: Colors.white24,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionLabel('Target'),
                  const SizedBox(height: 6),
                  _langDropdown(
                    context: context,
                    items: appLanguages.entries
                        .where((e) => e.key != 'auto')
                        .toList(),
                    selected: MapEntry(
                      state.settings.targetLang,
                      appLanguages[state.settings.targetLang] ??
                          state.settings.targetLang,
                    ),
                    hint:
                        appLanguages[state.settings.targetLang] ??
                        'Search language...',
                    onSelect: (item) {
                      context.read<SettingsBloc>().add(
                        UpdateTempSettingEvent(targetLang: item.key),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _langDropdown({
  required BuildContext context,
  required List<MapEntry<String, String>> items,
  required MapEntry<String, String> selected,
  required String hint,
  required void Function(MapEntry<String, String> item) onSelect,
  Set<String> disabledKeys = const {},
}) {
  return OmniDropdown<MapEntry<String, String>>(
    items: items,
    itemAsString: (entry) => entry.value,
    selectedItem: selected,
    compareFn: (a, b) => a.key == b.key,
    onChanged: (item) {
      if (item != null && !disabledKeys.contains(item.key)) {
        onSelect(item);
      }
    },
    hintText: hint,
    showSearchBox: true,
    disableItemFn: (item) => disabledKeys.contains(item.key),
  );
}

// ─── Translation Model Selector ───────────────────────────────────────────────────────

Widget _buildRecommendedBadge({required bool isActive}) {
  return OmniBadge(
    text: 'Recommended',
    color: isActive ? Colors.blueAccent : Colors.blue.shade700,
  );
}

Widget _buildDownloadedBadge() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.blueAccent.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
    ),
    child: const Text(
      'Downloaded',
      style: TextStyle(
        color: Colors.blueAccent,
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Widget buildTranslationModelSelector(
  BuildContext context,
  SettingsState state,
) {
  const translationModels = {
    'google': 'Google Translate (Free)',
    'google_api': 'Google Cloud (Official API)',
    'mymemory': 'MyMemory',
    'riva-nmt': 'NVIDIA Riva (Fast, High Quality)',
    'llama': 'Llama 3.1 8B (Accurate, Slower)',
  };

  bool hasAccess(String engineKey) {
    return SubscriptionRemoteDataSource.instance.canUseModel(engineKey);
  }

  final needsNvidiaKey =
      ['riva-nmt', 'llama'].contains(state.settings.translationModel) ||
      state.settings.transcriptionModel == 'riva-asr';

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OmniCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionLabel('Translation Engine'),
            const SizedBox(height: 10),
            SizedBox(
                  height: 36,
                  child: OmniDropdown<MapEntry<String, String>>(
                    showSearchBox: false,
                    items: translationModels.entries.toList(),
                    itemAsString: (entry) => entry.value,
                    selectedItem: MapEntry(
                      state.settings.translationModel,
                      translationModels[state.settings.translationModel] ??
                          state.settings.translationModel,
                    ),
                    onBeforeChange: (prev, next) async {
                      if (next == null) return false;
                      return hasAccess(next.key);
                    },
                    compareFn: (a, b) => a.key == b.key,
                    onChanged: (entry) {
                      if (entry != null && hasAccess(entry.key)) {
                        context.read<TranslationBloc>().add(
                          RequestModelUnloadEvent(),
                        );
                        Future.delayed(const Duration(milliseconds: 50), () {
                          if (context.mounted) {
                            context.read<SettingsBloc>().add(
                              UpdateTempSettingEvent(
                                translationModel: entry.key,
                              ),
                            );
                          }
                        });
                      }
                    },
                    disableItemFn: (item) => !hasAccess(item.key),
                    dropdownBuilder: (context, selectedItem) {
                      if (selectedItem == null) return const SizedBox();

                      final isRecommended = selectedItem.key == 'google';
                      final statusKey = {
                        'google': 'google_translate',
                        'google_api': 'google_api',
                        'mymemory': 'mymemory',
                        'riva-nmt': 'riva-nmt',
                        'llama': 'llama',
                      }[selectedItem.key];

                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedItem.value,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (statusKey != null) ...[
                            const SizedBox(width: 8),
                            ModelStatusIndicator(
                              status: state.modelStatuses[statusKey],
                              compact: true,
                            ),
                          ],
                          if (isRecommended) ...[
                            const SizedBox(width: 8),
                            _buildRecommendedBadge(isActive: true),
                          ],
                        ],
                      );
                    },
                    maxHeight: 250,
                    itemBuilder: (popupContext, item, isCurrentlySelected) {
                      final isRecommended = item.key == 'google';
                      final itemHasAccess = hasAccess(item.key);
                      final statusKey = {
                        'google': 'google_translate',
                        'google_api': 'google_api',
                        'mymemory': 'mymemory',
                        'riva-nmt': 'riva-nmt',
                        'llama': 'llama',
                      }[item.key];

                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.value,
                              style: TextStyle(
                                color: itemHasAccess
                                    ? (isCurrentlySelected
                                          ? Colors.tealAccent
                                          : Colors.white70)
                                    : Colors.white30,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (statusKey != null) ...[
                            const SizedBox(width: 8),
                            ModelStatusIndicator(
                              status: state.modelStatuses[statusKey],
                              compact: true,
                            ),
                          ],
                          if (!itemHasAccess) ...[
                            const SizedBox(width: 8),
                            _buildTierLockBadge(
                              '${SubscriptionRemoteDataSource.instance.getNameForTier(SubscriptionRemoteDataSource.instance.getRequirement('engines', item.key, SubscriptionRemoteDataSource.instance.getTierAt(1)))}+',
                            ),
                          ],
                          if (isRecommended && itemHasAccess) ...[
                            const SizedBox(width: 8),
                            _buildRecommendedBadge(
                              isActive: isCurrentlySelected,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
            if (state.translationCompatibilityError != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.translationCompatibilityError!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),

      if (needsNvidiaKey) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(children: [_NvidiaApiKeySection(state: state)]),
        ),
      ],

      const SizedBox(height: 16),
      OmniCard(
        padding: const EdgeInsets.all(16),
        child: _buildTranscriptionModelSection(context, state),
      ),
    ],
  );
}

// ─── Transcription Engine Section ─────────────────────────────────────────────

Widget _buildTranscriptionModelSection(
  BuildContext context,
  SettingsState state,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionLabel('Transcription Method'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TranscriptionOption(
                  value: 'online',
                  groupValue: state.settings.transcriptionModel,
                  label: 'Google Online',
                  icon: Icons.cloud_outlined,
                  status: state.modelStatuses['google_asr'],
                  onChanged: (v) {
                    context.read<SettingsBloc>().add(
                      UpdateTempSettingEvent(transcriptionModel: v),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TranscriptionOption(
                  value: 'riva-asr',
                  groupValue: state.settings.transcriptionModel,
                  label: 'NVIDIA Riva',
                  status: state.modelStatuses['riva-asr'],
                  isRecommended: true,
                  locked: !SubscriptionRemoteDataSource.instance
                      .canUseModel('riva-asr'),
                  icon: Icons.bolt_rounded,
                  onChanged: (v) {
                    context.read<SettingsBloc>().add(
                      UpdateTempSettingEvent(transcriptionModel: v),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TranscriptionOption(
                  value:
                      state.settings.transcriptionModel.startsWith('whisper')
                      ? state.settings.transcriptionModel
                      : 'whisper-base',
                  groupValue: state.settings.transcriptionModel,
                  label: 'Whisper Offline',
                  status: state.modelStatuses[state.settings.transcriptionModel
                          .startsWith('whisper')
                      ? state.settings.transcriptionModel
                      : 'whisper-base'],
                  locked: !SubscriptionRemoteDataSource.instance
                      .canUseModel('whisper-base'),
                  icon: Icons.offline_bolt_outlined,
                  onChanged: (v) {
                    context.read<SettingsBloc>().add(
                      UpdateTempSettingEvent(transcriptionModel: v),
                    );
                  },
                ),
              ),
            ],
          ),

          // Whisper model manager (shown when offline is selected)
          if (state.settings.transcriptionModel.startsWith('whisper')) ...[
            const SizedBox(height: 12),
            _WhisperModelCard(
              selectedModel: state.settings.transcriptionModel,
              modelStatuses: state.modelStatuses,
              onModelChanged: (newModel) {
                context.read<SettingsBloc>().add(
                  UpdateTempSettingEvent(transcriptionModel: newModel),
                );
              },
            ),
          ],
        ],
      ),
    ],
  );
}

// ─── Single transcription option row ─────────────────────────────────────────

class _TranscriptionOption extends StatelessWidget {
  final String value;
  final String groupValue;
  final String label;
  final IconData icon;
  final bool isRecommended;
  final bool locked;
  final dynamic status;
  final ValueChanged<String> onChanged;

  const _TranscriptionOption({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.icon,
    this.isRecommended = false,
    this.locked = false,
    this.status,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected =
        value == groupValue ||
        (value.startsWith('whisper') && groupValue.startsWith('whisper'));
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: locked ? null : () => onChanged(value),
      child: Opacity(
        opacity: locked ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.tealAccent.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? Colors.tealAccent.withValues(alpha: 0.5)
                  : Colors.white12,
            ),
          ),
          child: Column(
            children: [
              locked
                  ? const Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: Colors.white24,
                    )
                  : Icon(
                      icon,
                      size: 18,
                      color: isSelected ? Colors.tealAccent : Colors.white38,
                    ),
              if (status != null) ...[
                const SizedBox(height: 4),
                ModelStatusIndicator(status: status, compact: true),
              ],
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
              if (isRecommended) ...[
                const SizedBox(height: 6),
                _buildRecommendedBadge(isActive: isSelected),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Whisper model download / delete card ─────────────────────────────────────

class _WhisperModelCard extends StatefulWidget {
  final String selectedModel;
  final Map<String, dynamic> modelStatuses;
  final ValueChanged<String> onModelChanged;

  const _WhisperModelCard({
    required this.selectedModel,
    required this.modelStatuses,
    required this.onModelChanged,
  });

  @override
  State<_WhisperModelCard> createState() => _WhisperModelCardState();
}

class _WhisperModelCardState extends State<_WhisperModelCard> {
  final TranslationRestDatasource _svc = TranslationRestDatasource();
  Map<String, dynamic> _status = {
    'downloaded': false,
    'progress': 0.0,
    'status': 'idle',
    'size_mb': 0.0,
  };
  final Map<String, bool> _downloadedModels = {};
  Timer? _pollTimer;

  String get _currentSize => widget.selectedModel.split('-').last;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(_WhisperModelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedModel != widget.selectedModel) {
      _refresh();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final s = await _svc.getStatus(_currentSize);
    if (!mounted) return;
    setState(() {
      _status = s;
      _downloadedModels[_currentSize] = s['downloaded'] == true;
    });
    _startPollingIfNeeded();
    unawaited(_refreshAll());
  }

  Future<void> _refreshAll() async {
    final sizes = ['tiny', 'base', 'small', 'medium'];
    for (final s in sizes) {
      if (s != _currentSize) {
        unawaited(_svc.getStatus(s).then((stats) {
          if (mounted) {
            setState(() {
              _downloadedModels[s] = stats['downloaded'] == true;
            });
          }
        }));
      }
    }
  }

  void _startPollingIfNeeded() {
    final statusStr = _status['status'] as String? ?? 'idle';
    if (statusStr == 'downloading') {
      _pollTimer ??= Timer.periodic(
        const Duration(milliseconds: 600),
        (_) => _refresh(),
      );
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _startDownload() async {
    await _svc.startDownload(_currentSize);
    await _refresh();
  }

  Future<void> _deleteModel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text(
          'Delete Whisper Model',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will delete the "${_currentSize.toUpperCase()}" model (~${_status['size_mb'] ?? 0} MB). You can re-download it anytime.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _svc.deleteModel(_currentSize);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusStr = _status['status'] as String? ?? 'idle';
    final isDownloaded = _status['downloaded'] as bool? ?? false;
    final isDownloading = statusStr == 'downloading';
    final progress = (_status['progress'] as num? ?? 0).toDouble() / 100.0;
    final sizeMb = (_status['size_mb'] as num? ?? 0).toDouble();
    final isError = statusStr == 'error';

    final modelOptions = {
      'tiny': 'Tiny (~75 MB) - Fastest',
      'base': 'Base (~145 MB) - Fast',
      'small': 'Small (~460 MB) - Balanced',
      'medium': 'Medium (~1.5 GB) - High Accuracy',
    };

    final currentTier =
        SubscriptionRemoteDataSource.instance.currentStatus?.tier ??
        SubscriptionRemoteDataSource.instance.defaultTier;

    bool whisperHasAccess(String size) {
      if (size == 'tiny' || size == 'base') return true;
      final required = SubscriptionRemoteDataSource.instance.getRequirement(
        'whisper',
        size,
        size == 'medium'
            ? SubscriptionRemoteDataSource.instance.getTierAt(2)
            : SubscriptionRemoteDataSource.instance.getTierAt(1),
      );
      return SubscriptionRemoteDataSource.instance.tierHasAccess(
        currentTier,
        required,
      );
    }

    String whisperLockLabel(String size) {
      final required = SubscriptionRemoteDataSource.instance.getRequirement(
        'whisper',
        size,
        size == 'medium'
            ? SubscriptionRemoteDataSource.instance.getTierAt(2)
            : SubscriptionRemoteDataSource.instance.getTierAt(1),
      );
      return '${SubscriptionRemoteDataSource.instance.getNameForTier(required)}+';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.memory_rounded, size: 14, color: Colors.white38),
              const SizedBox(width: 8),
              const Text(
                'Model Size',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (isDownloaded && !isDownloading) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.tealAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 12,
                        color: Colors.tealAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${sizeMb.toStringAsFixed(0)} MB',
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  tooltip: 'Delete model',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _deleteModel,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          GpuStatusIndicator(status: widget.modelStatuses['system-gpu']),
          const SizedBox(height: 16),

          // Size Selection Dropdown
          DropdownButtonHideUnderline(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white12),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  hoverColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: DropdownButton<String>(
                  value: _currentSize,
                  dropdownColor: const Color(0xFF2C2C2C),
                  mouseCursor: SystemMouseCursors.basic,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.white38,
                  ),
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  onChanged: (val) {
                    if (val != null && whisperHasAccess(val)) {
                      widget.onModelChanged('whisper-$val');
                    } else if (val != null && !whisperHasAccess(val)) {
                      Navigator.pushNamed(context, '/history-panel');
                    }
                  },
                  items: modelOptions.entries.map((e) {
                    final isRecommended = e.key == 'base';
                    final isDownloaded = _downloadedModels[e.key] == true;
                    final hasAccess = whisperHasAccess(e.key);
                    final lockLabel = whisperLockLabel(e.key);
                    return DropdownMenuItem<String>(
                      value: e.key,
                      enabled: hasAccess,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: Text(
                              e.value,
                              style: TextStyle(
                                color: hasAccess
                                    ? Colors.white
                                    : Colors.white30,
                              ),
                            ),
                          ),
                          ModelStatusIndicator(
                            status: widget.modelStatuses['whisper-${e.key}'],
                            compact: true,
                          ),
                          if (!hasAccess) ...[
                            const SizedBox(width: 8),
                            _buildTierLockBadge(lockLabel),
                          ],
                          if (isRecommended && hasAccess) ...[
                            const SizedBox(width: 8),
                            _buildRecommendedBadge(
                              isActive: e.key == _currentSize,
                            ),
                          ],
                          if (isDownloaded && hasAccess) ...[
                            const SizedBox(width: 8),
                            _buildDownloadedBadge(),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  selectedItemBuilder: (BuildContext context) {
                    return modelOptions.entries.map((e) {
                      final isRecommended = e.key == 'base';
                      final isDownloaded = _downloadedModels[e.key] == true;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: Text(
                              e.value,
                              style: const TextStyle(color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ModelStatusIndicator(
                            status: widget.modelStatuses['whisper-${e.key}'],
                            compact: true,
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: 8),
                            _buildRecommendedBadge(isActive: true),
                          ],
                          if (isDownloaded) ...[
                            const SizedBox(width: 8),
                            _buildDownloadedBadge(),
                          ],
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),

          if (isDownloading) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.tealAccent,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Downloading Whisper ${_currentSize.toUpperCase()} model…',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],

          if (!isDownloaded && !isDownloading && !isError) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.download_rounded, size: 14),
                label: Text(
                  'Download ${_currentSize.toUpperCase()} Model',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.tealAccent,
                  side: const BorderSide(color: Colors.tealAccent, width: 0.8),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],

          if (isError) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.orangeAccent,
                  size: 14,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Download failed. Check your connection.',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                  ),
                ),
                TextButton(
                  onPressed: _startDownload,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.tealAccent, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── API Key Section ──────────────────────────────────────────────────────────

// ─── NVIDIA API Key Section ──────────────────────────────────────────────────

enum ApiKeyStatus { missing, verifying, valid, invalidFormat, invalidKey }

class _NvidiaApiKeySection extends StatefulWidget {
  final SettingsState state;

  const _NvidiaApiKeySection({required this.state});

  @override
  State<_NvidiaApiKeySection> createState() => _NvidiaApiKeySectionState();
}

class _NvidiaApiKeySectionState extends State<_NvidiaApiKeySection> {
  late TextEditingController _controller;
  bool _obscure = true;
  Timer? _debounce;
  ApiKeyStatus _status = ApiKeyStatus.missing;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.state.settings.nvidiaNimKey,
    );

    // Eagerly set assumed valid state to prevent UI flash before validation completes
    final key = _controller.text.trim();
    if (key.startsWith('nvapi-') && key.length >= 50) {
      _status = ApiKeyStatus.valid;
      _isEditing = false;
    } else {
      _status = ApiKeyStatus.missing;
      _isEditing = true;
    }

    _validateKey(_controller.text, immediate: true);
  }

  @override
  void didUpdateWidget(_NvidiaApiKeySection old) {
    super.didUpdateWidget(old);
    if (old.state.settings.nvidiaNimKey != widget.state.settings.nvidiaNimKey &&
        _controller.text != widget.state.settings.nvidiaNimKey) {
      _controller.text = widget.state.settings.nvidiaNimKey;

      final key = _controller.text.trim();
      if (key.startsWith('nvapi-') && key.length >= 50) {
        _status = ApiKeyStatus.valid;
        _isEditing = false;
      } else {
        _status = ApiKeyStatus.missing;
        _isEditing = true;
      }

      _validateKey(_controller.text, immediate: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _validateKey(String key, {bool immediate = false}) async {
    _debounce?.cancel();

    if (key.trim().isEmpty) {
      setState(() {
        _status = ApiKeyStatus.missing;
        _isEditing = true;
      });
      // Empty key — not invalid, just missing; don't block save
      context.read<SettingsBloc>().add(const SetApiKeyValidityEvent(isValid: true));
      return;
    }

    if (!key.trim().startsWith('nvapi-') || key.trim().length < 50) {
      setState(() {
        _status = ApiKeyStatus.invalidFormat;
        _isEditing = true;
      });
      context.read<SettingsBloc>().add(const SetApiKeyValidityEvent(isValid: false));
      return;
    }

    setState(() => _status = ApiKeyStatus.verifying);

    Future<void> action() async {
      try {
        final res = await http.get(
          Uri.parse('https://integrate.api.nvidia.com/v1/models'),
          headers: {'Authorization': 'Bearer ${key.trim()}'},
        );
        if (mounted) {
          final isValid = res.statusCode == 200;
          setState(() {
            _status = isValid ? ApiKeyStatus.valid : ApiKeyStatus.invalidKey;
            _isEditing = !isValid;
          });
          context.read<SettingsBloc>().add(SetApiKeyValidityEvent(isValid: isValid));
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _status = ApiKeyStatus.invalidKey;
            _isEditing = true;
          });
          context.read<SettingsBloc>().add(const SetApiKeyValidityEvent(isValid: false));
        }
      }
    }

    if (immediate) {
      unawaited(action());
    } else {
      _debounce = Timer(const Duration(milliseconds: 800), action);
    }
  }

  Widget _buildStatusBadge() {
    Color color;
    String text;

    switch (_status) {
      case ApiKeyStatus.missing:
        color = Colors.orange;
        text = 'Required';
        break;
      case ApiKeyStatus.verifying:
        color = Colors.blueGrey;
        text = 'Checking...';
        break;
      case ApiKeyStatus.valid:
        color = Colors.greenAccent;
        text = 'Valid';
        break;
      case ApiKeyStatus.invalidFormat:
      case ApiKeyStatus.invalidKey:
        color = Colors.redAccent;
        text = 'Invalid Key';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if ((_status == ApiKeyStatus.valid || _status == ApiKeyStatus.verifying) &&
        !_isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              sectionLabel('NVIDIA API Key'),
              const SizedBox(width: 8),
              _buildStatusBadge(),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _isEditing = true),
                style: TextButton.styleFrom(foregroundColor: Colors.tealAccent),
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('Edit', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: TextField(
              controller: _controller,
              obscureText: true,
              readOnly: true,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              decoration: InputDecoration(
                fillColor: Colors.white.withValues(alpha: 0.02),
                hintText: 'nvapi-xxxxxxxxxxxxxxxxxxxxxxxx',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                  borderSide: BorderSide(color: Colors.transparent),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                  borderSide: BorderSide(color: Colors.transparent),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                  borderSide: BorderSide(color: Colors.transparent),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final instructions = _nvidiaApiKeyInstructions(
      widget.state.settings.translationModel,
      widget.state.settings.transcriptionModel,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            sectionLabel('NVIDIA API Key'),
            const SizedBox(width: 8),
            _buildStatusBadge(),
            if (_status == ApiKeyStatus.valid) ...[
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _isEditing = false),
                style: TextButton.styleFrom(foregroundColor: Colors.white54),
                icon: const Icon(Icons.close, size: 14),
                label: const Text('Cancel', style: TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          instructions.description,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => launchUrl(Uri.parse(instructions.url)),
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.tealAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.tealAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.open_in_new,
                  size: 10,
                  color: Colors.tealAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  instructions.label,
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: TextField(
            controller: _controller,
            obscureText: _obscure,
            onChanged: (val) {
              context.read<SettingsBloc>().add(
                UpdateTempSettingEvent(nvidiaNimKey: val),
              );
              _validateKey(val);
            },
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'nvapi-xxxxxxxxxxxxxxxxxxxxxxxx',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
              suffixIcon: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white38,
                  size: 16,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ApiKeyInstructions {
  final String description;
  final String label;
  final String url;
  const _ApiKeyInstructions({
    required this.description,
    required this.label,
    required this.url,
  });
}

_ApiKeyInstructions _nvidiaApiKeyInstructions(
  String translationEngine,
  String transcriptionEngine,
) {
  if (translationEngine == 'riva-nmt' ||
      transcriptionEngine == 'riva-asr' ||
      translationEngine == 'llama') {
    return const _ApiKeyInstructions(
      description: 'Generate a free NVIDIA NIM API key.',
      label: 'https://build.nvidia.com/settings/api-keys',
      url: 'https://build.nvidia.com/settings/api-keys',
    );
  } else {
    return const _ApiKeyInstructions(
      description: '',
      label: '',
      url: 'https://build.nvidia.com/settings/api-keys',
    );
  }
}

/// Lock badge rendered next to options the user's tier cannot access.
Widget _buildTierLockBadge(String requiredTierLabel) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.orangeAccent.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_outline, size: 9, color: Colors.orangeAccent),
        const SizedBox(width: 3),
        Text(
          requiredTierLabel,
          style: const TextStyle(
            color: Colors.orangeAccent,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
