import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import '../../../core/constants/languages.dart';
import '../../../core/services/whisper_service.dart';
import 'settings_helpers.dart';

Widget buildLanguagesTab(BuildContext context, SettingsState state) {
  return Column(
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
                    state.tempSourceLang,
                    appLanguages[state.tempSourceLang] ?? state.tempSourceLang,
                  ),
                  hint:
                      appLanguages[state.tempSourceLang] ??
                      'Search language...',
                  onChanged: (entry) {
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (context.mounted) {
                        context.read<SettingsBloc>().add(
                          UpdateTempSettingEvent(sourceLang: entry!.key),
                        );
                      }
                    });
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
                    state.tempTargetLang,
                    appLanguages[state.tempTargetLang] ?? state.tempTargetLang,
                  ),
                  hint:
                      appLanguages[state.tempTargetLang] ??
                      'Search language...',
                  onChanged: (entry) {
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (context.mounted) {
                        context.read<SettingsBloc>().add(
                          UpdateTempSettingEvent(targetLang: entry!.key),
                        );
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _langDropdown({
  required BuildContext context,
  required List<MapEntry<String, String>> items,
  required MapEntry<String, String> selected,
  required String hint,
  required ValueChanged<MapEntry<String, String>?> onChanged,
}) {
  const dropDec = DropDownDecoratorProps(
    dropdownSearchDecoration: InputDecoration(
      filled: true,
      fillColor: Colors.white10,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Colors.white24),
      ),
    ),
  );

  return DropdownSearch<MapEntry<String, String>>(
    items: items,
    itemAsString: (entry) => entry.value,
    selectedItem: selected,
    compareFn: (a, b) => a.key == b.key,
    onChanged: onChanged,
    popupProps: PopupProps.menu(
      showSearchBox: true,
      fit: FlexFit.loose,
      constraints: const BoxConstraints(maxHeight: 300),
      searchDelay: Duration.zero,
      searchFieldProps: TextFieldProps(
        autofocus: true,
        decoration: searchDecoration(hint),
      ),
      menuProps: MenuProps(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    dropdownDecoratorProps: dropDec,
  );
}

// ─── Translation Model Selector ───────────────────────────────────────────────────────

Widget _buildRecommendedBadge({required bool isActive}) {
  final color = isActive ? Colors.greenAccent : Colors.white38;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(
      'Recommended',
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
    ),
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
    'google': 'Google Translate',
    'mymemory': 'MyMemory',
    'riva': 'NVIDIA Riva (Fast, High Quality)',
    'llama': 'Llama 3.1 8B (Accurate, Slower)',
  };

  const enginesThatNeedKey = {'riva', 'llama'};
  final needsKey =
      enginesThatNeedKey.contains(state.tempTranslationModel) ||
      state.tempTranscriptionModel == 'riva';

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      sectionLabel('AI Translation Engine'),
      const SizedBox(height: 8),
      DropdownSearch<MapEntry<String, String>>(
        items: translationModels.entries.toList(),
        itemAsString: (entry) => entry.value,
        dropdownBuilder: (context, selectedItem) {
          if (selectedItem == null) return const SizedBox();
          final isRecommended = selectedItem.key == 'google';
          return Row(
            children: [
              Text(selectedItem.value, style: const TextStyle(fontSize: 14)),
              if (isRecommended) ...[
                const SizedBox(width: 8),
                _buildRecommendedBadge(isActive: true),
              ],
            ],
          );
        },
        selectedItem: MapEntry(
          state.tempTranslationModel,
          translationModels[state.tempTranslationModel] ??
              state.tempTranslationModel,
        ),
        compareFn: (a, b) => a.key == b.key,
        onChanged: (entry) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (context.mounted) {
              context.read<SettingsBloc>().add(
                UpdateTempSettingEvent(translationModel: entry!.key),
              );
            }
          });
        },
        popupProps: PopupProps.menu(
          fit: FlexFit.loose,
          constraints: const BoxConstraints(maxHeight: 200),
          menuProps: const MenuProps(
            backgroundColor: Color(0xFF2C2C2C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
          itemBuilder: (context, item, isSelected) {
            final isRecommended = item.key == 'google';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isSelected
                  ? Colors.tealAccent.withValues(alpha: 0.1)
                  : Colors.transparent,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.value,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check, color: Colors.tealAccent, size: 18),
                  ],
                  if (isRecommended) ...[
                    const SizedBox(width: 8),
                    _buildRecommendedBadge(isActive: isSelected),
                  ],
                ],
              ),
            );
          },
        ),
        dropdownDecoratorProps: const DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            filled: true,
            fillColor: Colors.white10,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: Colors.white24),
            ),
          ),
        ),
      ),
      if (needsKey) ...[
        const SizedBox(height: 16),
        _ApiKeySection(state: state),
      ],
      const SizedBox(height: 20),
      _buildTranscriptionModelSection(context, state),
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
      sectionLabel('Transcription Method'),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _TranscriptionOption(
              value: 'online',
              groupValue: state.tempTranscriptionModel,
              label: 'Google Online',
              icon: Icons.cloud_outlined,
              onChanged: (v) => context.read<SettingsBloc>().add(
                UpdateTempSettingEvent(transcriptionModel: v),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TranscriptionOption(
              value: 'riva',
              groupValue: state.tempTranscriptionModel,
              label: 'NVIDIA Riva',
              isRecommended: true,
              icon: Icons.bolt_rounded,
              onChanged: (v) => context.read<SettingsBloc>().add(
                UpdateTempSettingEvent(transcriptionModel: v),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TranscriptionOption(
              value: state.tempTranscriptionModel.startsWith('whisper')
                  ? state.tempTranscriptionModel
                  : 'whisper-base',
              groupValue: state.tempTranscriptionModel,
              label: 'Whisper Offline',
              icon: Icons.offline_bolt_outlined,
              onChanged: (v) => context.read<SettingsBloc>().add(
                UpdateTempSettingEvent(transcriptionModel: v),
              ),
            ),
          ),
        ],
      ),

      // Whisper model manager (shown when offline is selected)
      if (state.tempTranscriptionModel.startsWith('whisper')) ...[
        const SizedBox(height: 12),
        _WhisperModelCard(
          selectedModel: state.tempTranscriptionModel,
          onModelChanged: (newModel) {
            context.read<SettingsBloc>().add(
              UpdateTempSettingEvent(transcriptionModel: newModel),
            );
          },
        ),
      ],
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
  final ValueChanged<String> onChanged;

  const _TranscriptionOption({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.icon,
    this.isRecommended = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected =
        value == groupValue ||
        (value.startsWith('whisper') && groupValue.startsWith('whisper'));
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.tealAccent.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.tealAccent.withValues(alpha: 0.5)
                : Colors.white12,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.tealAccent : Colors.white38,
            ),
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
    );
  }
}

// ─── Whisper model download / delete card ─────────────────────────────────────

class _WhisperModelCard extends StatefulWidget {
  final String selectedModel;
  final ValueChanged<String> onModelChanged;

  const _WhisperModelCard({
    required this.selectedModel,
    required this.onModelChanged,
  });

  @override
  State<_WhisperModelCard> createState() => _WhisperModelCardState();
}

class _WhisperModelCardState extends State<_WhisperModelCard> {
  final WhisperService _svc = WhisperService();
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
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    final sizes = ['tiny', 'base', 'small', 'medium'];
    for (final s in sizes) {
      if (s != _currentSize) {
        _svc.getStatus(s).then((stats) {
          if (mounted) {
            setState(() {
              _downloadedModels[s] = stats['downloaded'] == true;
            });
          }
        });
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
          const SizedBox(height: 10),

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
              child: DropdownButton<String>(
                value: _currentSize,
                dropdownColor: const Color(0xFF2C2C2C),
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: Colors.white38,
                ),
                isExpanded: true,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                onChanged: (val) {
                  if (val != null) {
                    widget.onModelChanged('whisper-$val');
                  }
                },
                items: modelOptions.entries.map((e) {
                  final isRecommended = e.key == 'base';
                  final isDownloaded = _downloadedModels[e.key] == true;
                  return DropdownMenuItem<String>(
                    value: e.key,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(e.value),
                        if (isRecommended) ...[
                          const SizedBox(width: 8),
                          _buildRecommendedBadge(
                            isActive: e.key == _currentSize,
                          ),
                        ],
                        if (isDownloaded) ...[
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
                        Text(e.value),
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

enum ApiKeyStatus { missing, verifying, valid, invalidFormat, invalidKey }

class _ApiKeySection extends StatefulWidget {
  final SettingsState state;

  const _ApiKeySection({required this.state});

  @override
  State<_ApiKeySection> createState() => _ApiKeySectionState();
}

class _ApiKeySectionState extends State<_ApiKeySection> {
  late TextEditingController _controller;
  bool _obscure = true;
  Timer? _debounce;
  ApiKeyStatus _status = ApiKeyStatus.missing;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.tempApiKey);
    _validateKey(_controller.text, immediate: true);
  }

  @override
  void didUpdateWidget(_ApiKeySection old) {
    super.didUpdateWidget(old);
    if (old.state.tempApiKey != widget.state.tempApiKey &&
        _controller.text != widget.state.tempApiKey) {
      _controller.text = widget.state.tempApiKey;
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
      return;
    }

    if (!key.trim().startsWith('nvapi-') || key.trim().length < 50) {
      setState(() {
        _status = ApiKeyStatus.invalidFormat;
        _isEditing = true;
      });
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
          setState(() {
            if (res.statusCode == 200) {
              _status = ApiKeyStatus.valid;
              _isEditing = false;
            } else {
              _status = ApiKeyStatus.invalidKey;
              _isEditing = true;
            }
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _status = ApiKeyStatus.invalidKey;
            _isEditing = true;
          });
        }
      }
    }

    if (immediate) {
      action();
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
    if (_status == ApiKeyStatus.valid && !_isEditing) {
      return Row(
        children: [
          sectionLabel('API Key'),
          const SizedBox(width: 8),
          _buildStatusBadge(),
          const SizedBox(width: 12),
          const Text(
            '••••••••••••••••••••••••••••••••',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => setState(() => _isEditing = true),
            icon: const Icon(Icons.edit, size: 14, color: Colors.tealAccent),
            label: const Text(
              'Edit',
              style: TextStyle(color: Colors.tealAccent, fontSize: 12),
            ),
          ),
        ],
      );
    }

    final instructions = _apiKeyInstructions(
      widget.state.tempTranslationModel,
      widget.state.tempTranscriptionModel,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            sectionLabel('API Key'),
            const SizedBox(width: 8),
            _buildStatusBadge(),
            if (_status == ApiKeyStatus.valid) ...[
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _isEditing = false),
                icon: const Icon(Icons.close, size: 14, color: Colors.white54),
                label: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
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
        TextField(
          controller: _controller,
          obscureText: _obscure,
          onChanged: (val) {
            context.read<SettingsBloc>().add(
              UpdateTempSettingEvent(apiKey: val),
            );
            _validateKey(val);
          },
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white10,
            hintText: 'nvapi-xxxxxxxxxxxxxxxxxxxxxxxx',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: Colors.white12),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: Colors.white12),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: Colors.tealAccent, width: 1.5),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.white38,
                size: 18,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
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

_ApiKeyInstructions _apiKeyInstructions(
  String translationEngine,
  String transcriptionEngine,
) {
  if (translationEngine == 'riva' || transcriptionEngine == 'riva') {
    return const _ApiKeyInstructions(
      description: 'Generate a free NVIDIA NIM API key.',
      label: 'https://build.nvidia.com/settings/api-keys',
      url: 'https://build.nvidia.com/settings/api-keys',
    );
  } else if (translationEngine == 'llama') {
    return const _ApiKeyInstructions(
      description: 'Generate a free NVIDIA NIM API key to access Llama 3.1 8B.',
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
