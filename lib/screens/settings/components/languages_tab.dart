import 'dart:async';
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
      sectionLabel('Source Language'),
      const SizedBox(height: 4),
      const Text(
        'The language spoken in the captured audio',
        style: TextStyle(color: Colors.white38, fontSize: 11),
      ),
      const SizedBox(height: 10),
      _langDropdown(
        context: context,
        items: appLanguages.entries.where((e) => e.key != 'none').toList(),
        selected: MapEntry(
          state.tempSourceLang,
          appLanguages[state.tempSourceLang] ?? state.tempSourceLang,
        ),
        hint: appLanguages[state.tempSourceLang] ?? 'Search language...',
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
      const SizedBox(height: 20),
      const SizedBox(height: 10),
      _langDropdown(
        context: context,
        items: appLanguages.entries.where((e) => e.key != 'auto').toList(),
        selected: MapEntry(
          state.tempTargetLang,
          appLanguages[state.tempTargetLang] ?? state.tempTargetLang,
        ),
        hint: appLanguages[state.tempTargetLang] ?? 'Search language...',
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

Widget buildTranslationModelSelector(
  BuildContext context,
  SettingsState state,
) {
  const translationModels = {
    'google': 'Google Translate',
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
      const SizedBox(height: 4),
      const Text(
        'Select the backend engine used to translate your speech',
        style: TextStyle(color: Colors.white38, fontSize: 11),
      ),
      const SizedBox(height: 10),
      DropdownSearch<MapEntry<String, String>>(
        items: translationModels.entries.toList(),
        itemAsString: (entry) => entry.value,
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
          menuProps: MenuProps(
            backgroundColor: const Color(0xFF2C2C2C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
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
        _buildApiKeySection(context, state),
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
      const SizedBox(height: 4),
      const Text(
        'How your speech is converted to text before translation',
        style: TextStyle(color: Colors.white38, fontSize: 11),
      ),
      const SizedBox(height: 8),

      // Online option
      _TranscriptionOption(
        value: 'online',
        groupValue: state.tempTranscriptionModel,
        label: 'Online (Google)',
        description: 'No download required · needs internet',
        onChanged: (v) => context.read<SettingsBloc>().add(
          UpdateTempSettingEvent(transcriptionModel: v),
        ),
      ),

      const SizedBox(height: 6),

      // Riva ASR option
      _TranscriptionOption(
        value: 'riva',
        groupValue: state.tempTranscriptionModel,
        label: 'Online (NVIDIA Riva)',
        description: 'Fast, high quality (20+ languages) · requires API key',
        onChanged: (v) => context.read<SettingsBloc>().add(
          UpdateTempSettingEvent(transcriptionModel: v),
        ),
      ),

      const SizedBox(height: 6),

      // Whisper offline option
      _TranscriptionOption(
        value: state.tempTranscriptionModel.startsWith('whisper')
            ? state.tempTranscriptionModel
            : 'whisper-base',
        groupValue: state.tempTranscriptionModel,
        label: 'Offline (Whisper)',
        description: 'Runs locally · fits on device',
        onChanged: (v) => context.read<SettingsBloc>().add(
          UpdateTempSettingEvent(transcriptionModel: v),
        ),
      ),

      // Whisper model manager (shown when offline is selected)
      if (state.tempTranscriptionModel.startsWith('whisper')) ...[
        const SizedBox(height: 8),
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
  final String description;
  final ValueChanged<String> onChanged;

  const _TranscriptionOption({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.description,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // If value is whisper-something and groupValue is whisper-something else, it's still "selected"
    final isSelected =
        value == groupValue ||
        (value.startsWith('whisper') && groupValue.startsWith('whisper'));
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.tealAccent.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.tealAccent.withValues(alpha: 0.5)
                : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            // Custom radio indicator (Radio.groupValue/.onChanged deprecated in 3.32)
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.tealAccent : Colors.white38,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.tealAccent,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
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
    setState(() => _status = s);
    _startPollingIfNeeded();
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
      'base': 'Base (~145 MB) - Fast (Recommended)',
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
                  return DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(e.value),
                  );
                }).toList(),
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

Widget _buildApiKeySection(BuildContext context, SettingsState state) {
  final instructions = _apiKeyInstructions(
    state.tempTranslationModel,
    state.tempTranscriptionModel,
  );

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          sectionLabel('API Key'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: const Text(
              'Required',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        instructions.description,
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      const SizedBox(height: 4),
      GestureDetector(
        onTap: () async {
          // Open URL — no url_launcher needed, just show a tooltip or copy link
        },
        child: Row(
          children: [
            const Icon(Icons.open_in_new, size: 11, color: Colors.tealAccent),
            const SizedBox(width: 4),
            Flexible(
              child: SelectableText(
                instructions.link,
                style: const TextStyle(
                  color: Colors.tealAccent,
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.tealAccent,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      _ApiKeyField(
        initialValue: state.tempApiKey,
        onChanged: (val) {
          context.read<SettingsBloc>().add(UpdateTempSettingEvent(apiKey: val));
        },
      ),
    ],
  );
}

class _ApiKeyInstructions {
  final String description;
  final String link;
  const _ApiKeyInstructions({required this.description, required this.link});
}

_ApiKeyInstructions _apiKeyInstructions(
  String translationEngine,
  String transcriptionEngine,
) {
  if (translationEngine == 'riva' || transcriptionEngine == 'riva') {
    return const _ApiKeyInstructions(
      description: 'Generate a free NVIDIA NIM API key.',
      link: 'https://build.nvidia.com → Sign In → API Keys',
    );
  } else if (translationEngine == 'llama') {
    return const _ApiKeyInstructions(
      description: 'Generate a free NVIDIA NIM API key to access Llama 3.1 8B.',
      link: 'https://build.nvidia.com → Sign In → API Keys',
    );
  } else {
    return const _ApiKeyInstructions(description: '', link: '');
  }
}

class _ApiKeyField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _ApiKeyField({required this.initialValue, required this.onChanged});

  @override
  State<_ApiKeyField> createState() => _ApiKeyFieldState();
}

class _ApiKeyFieldState extends State<_ApiKeyField> {
  late final TextEditingController _controller;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_ApiKeyField old) {
    super.didUpdateWidget(old);
    // Update text if the parent rebuilds with a different initial value
    // (e.g., loaded from Firebase), but don't disturb the cursor.
    if (old.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      obscureText: _obscure,
      onChanged: widget.onChanged,
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
    );
  }
}
