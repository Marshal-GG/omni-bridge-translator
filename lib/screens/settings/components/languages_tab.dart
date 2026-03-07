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

// ─── AI Engine Selector ───────────────────────────────────────────────────────

Widget buildAiEngineSelector(BuildContext context, SettingsState state) {
  const aiEngines = {
    'google': 'Google Translate',
    'riva': 'NVIDIA Riva (Fast, High Quality)',
    'llama': 'Llama 3.1 8B (Accurate, Slower)',
  };

  const enginesThatNeedKey = {'riva', 'llama'};
  final needsKey = enginesThatNeedKey.contains(state.tempAiEngine);
  final isGoogle = state.tempAiEngine == 'google';

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
        items: aiEngines.entries.toList(),
        itemAsString: (entry) => entry.value,
        selectedItem: MapEntry(
          state.tempAiEngine,
          aiEngines[state.tempAiEngine] ?? state.tempAiEngine,
        ),
        compareFn: (a, b) => a.key == b.key,
        onChanged: (entry) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (context.mounted) {
              context.read<SettingsBloc>().add(
                UpdateTempSettingEvent(aiEngine: entry!.key),
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
      if (isGoogle) ...[
        const SizedBox(height: 20),
        _buildTranscriptionEngineSection(context, state),
      ],
    ],
  );
}

// ─── Transcription Engine Section ─────────────────────────────────────────────

Widget _buildTranscriptionEngineSection(
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
        groupValue: state.tempTranscriptionEngine,
        label: 'Online (Google)',
        description: 'No download required · needs internet',
        onChanged: (v) => context.read<SettingsBloc>().add(
          UpdateTempSettingEvent(transcriptionEngine: v),
        ),
      ),

      const SizedBox(height: 6),

      // Whisper offline option
      _TranscriptionOption(
        value: 'whisper',
        groupValue: state.tempTranscriptionEngine,
        label: 'Offline (Whisper)',
        description: 'Runs locally · ~145 MB one-time download',
        onChanged: (v) => context.read<SettingsBloc>().add(
          UpdateTempSettingEvent(transcriptionEngine: v),
        ),
      ),

      // Whisper model manager (shown when offline is selected)
      if (state.tempTranscriptionEngine == 'whisper') ...[
        const SizedBox(height: 8),
        _WhisperModelCard(),
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
    final isSelected = value == groupValue;
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
  const _WhisperModelCard();

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

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final s = await _svc.getStatus();
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
    await _svc.startDownload();
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
        content: const Text(
          'This will delete the downloaded model (~145 MB). You can re-download it anytime.',
          style: TextStyle(color: Colors.white70),
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
      await _svc.deleteModel();
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
              const SizedBox(width: 6),
              const Text(
                'Whisper base model',
                style: TextStyle(
                  color: Colors.white70,
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
              if (!isDownloaded && !isDownloading)
                OutlinedButton.icon(
                  onPressed: _startDownload,
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text('Download', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.tealAccent,
                    side: const BorderSide(
                      color: Colors.tealAccent,
                      width: 0.8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),

          // Progress bar
          if (isDownloading) ...[
            const SizedBox(height: 10),
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
            const Text(
              'Downloading Whisper base model…',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],

          // Error
          if (isError) ...[
            const SizedBox(height: 6),
            const Text(
              '⚠ Download failed. Check your connection and try again.',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _startDownload,
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.tealAccent, fontSize: 12),
              ),
            ),
          ],

          // Hint when not downloaded
          if (!isDownloaded && !isDownloading && !isError) ...[
            const SizedBox(height: 6),
            const Text(
              '~145 MB · runs offline on CPU · no API key needed',
              style: TextStyle(color: Colors.white30, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── API Key Section ──────────────────────────────────────────────────────────

Widget _buildApiKeySection(BuildContext context, SettingsState state) {
  final instructions = _apiKeyInstructions(state.tempAiEngine);

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

_ApiKeyInstructions _apiKeyInstructions(String engine) {
  switch (engine) {
    case 'riva':
      return const _ApiKeyInstructions(
        description:
            'Generate a free NVIDIA NIM API key. No credit card needed for trial credits.',
        link: 'https://build.nvidia.com → Sign In → API Keys',
      );
    case 'llama':
      return const _ApiKeyInstructions(
        description:
            'Generate a free NVIDIA NIM API key to access Llama 3.1 8B. No credit card for trial.',
        link: 'https://build.nvidia.com → Sign In → API Keys',
      );
    default:
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
