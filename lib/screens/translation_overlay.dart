import '../core/routes/routes_config.dart';
import '../core/services/asr_text_controller.dart';
import '../core/services/asr_ws_client.dart';
import 'package:dropdown_search/dropdown_search.dart';

class TranslationOverlay extends StatelessWidget {
  const TranslationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WindowBorder(
        color: Colors.transparent,
        width: 0,
        child: Stack(
          children: [
            MoveWindow(),
            Center(child: DraggableOverlayContent()),
          ],
        ),
      ),
    );
  }
}

class DraggableOverlayContent extends StatefulWidget {
  const DraggableOverlayContent({super.key});

  @override
  State<DraggableOverlayContent> createState() =>
      _DraggableOverlayContentState();
}

class _DraggableOverlayContentState extends State<DraggableOverlayContent> {
  final AsrWebSocketClient _asrClient = AsrWebSocketClient();

  bool _isSettingsOpen = false;

  // --- COMMITTED SETTINGS ---
  String _activeTargetLang = 'en';
  String _activeSourceLang = 'auto';
  bool _activeUseMic = false;

  // --- TEMP SETTINGS ---
  String _tempTargetLang = 'en';
  String _tempSourceLang = 'auto';
  bool _tempUseMic = false;

  // --- LANGUAGES ---
  final Map<String, String> _languages = {
    'auto': 'Auto-Detect',
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'ru': 'Russian',
    'pt': 'Portuguese',
    'it': 'Italian',
    'ar': 'Arabic',
    'hi': 'Hindi',
    'nl': 'Dutch',
    'tr': 'Turkish',
    'vi': 'Vietnamese',
    'pl': 'Polish',
    'id': 'Indonesian',
    'th': 'Thai',
    'bn': 'Bengali',
  };

  @override
  void initState() {
    super.initState();
    _asrClient.start(); // 🔥 Start Python ASR sidecar connection
  }

  @override
  void dispose() {
    _asrClient.stop();
    super.dispose();
  }

  // --- TOGGLE SETTINGS ---
  Future<void> _toggleSettings() async {
    setState(() {
      _isSettingsOpen = !_isSettingsOpen;
    });

    if (_isSettingsOpen) {
      _tempTargetLang = _activeTargetLang;
      _tempSourceLang = _activeSourceLang;
      _tempUseMic = _activeUseMic;
      await windowManager.setSize(const Size(400, 520));
    } else {
      await windowManager.setSize(const Size(730, 150));
    }
  }

  // --- SAVE SETTINGS ---
  Future<void> _saveAndClose() async {
    setState(() {
      _activeTargetLang = _tempTargetLang;
      _activeSourceLang = _tempSourceLang;
      _activeUseMic = _tempUseMic;
      _isSettingsOpen = false;
    });

    debugPrint(
      "Saved: $_activeSourceLang → $_activeTargetLang (Mic: $_activeUseMic)",
    );

    // Later we’ll send this to Python via WS
    await windowManager.setSize(const Size(730, 150));
  }

  // --- SETTINGS UI ---
  Widget _buildSettingsUI() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Audio Configuration",
            style: TextStyle(
              color: Colors.tealAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          SwitchListTile(
            title: const Text(
              "Microphone Translation",
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            subtitle: const Text(
              "Translate my voice instead of system audio",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            value: _tempUseMic,
            activeThumbColor: Colors.tealAccent,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _tempUseMic = val),
          ),

          const Divider(color: Colors.white24),
          const SizedBox(height: 10),

          const Text(
            "Source Language",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 5),
          DropdownSearch<String>(
            selectedItem: _languages[_tempSourceLang],
            items: _languages.values.toList(),
            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: _dropdownDecoration(),
            ),
            popupProps: PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: const InputDecoration(
                  hintText: "Search language...",
                  hintStyle: TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              containerBuilder: (context, popupWidget) {
                return Container(color: Colors.grey[900], child: popupWidget);
              },
              itemBuilder: (context, item, isSelected) {
                return ListTile(
                  title: Text(
                    item,
                    style: const TextStyle(color: Colors.white),
                  ),
                  selected: isSelected,
                  selectedTileColor: Colors.teal.withValues(alpha: 0.2),
                );
              },
            ),
            onChanged: (val) {
              if (val != null) {
                final key = _languages.entries
                    .firstWhere((e) => e.value == val)
                    .key;
                setState(() => _tempSourceLang = key);
              }
            },
          ),

          const SizedBox(height: 15),

          const Text(
            "Target Language",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 5),
          DropdownSearch<String>(
            selectedItem: _languages[_tempTargetLang],
            items: _languages.entries
                .where((e) => e.key != 'auto')
                .map((e) => e.value)
                .toList(),
            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: _dropdownDecoration(),
            ),
            popupProps: PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: const InputDecoration(
                  hintText: "Search language...",
                  hintStyle: TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              containerBuilder: (context, popupWidget) {
                return Container(color: Colors.grey[900], child: popupWidget);
              },
              itemBuilder: (context, item, isSelected) {
                return ListTile(
                  title: Text(
                    item,
                    style: const TextStyle(color: Colors.white),
                  ),
                  selected: isSelected,
                  selectedTileColor: Colors.teal.withValues(alpha: 0.2),
                );
              },
            ),
            onChanged: (val) {
              if (val != null) {
                final key = _languages.entries
                    .firstWhere((e) => e.value == val)
                    .key;
                setState(() => _tempTargetLang = key);
              }
            },
          ),

          const Spacer(),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _toggleSettings,
                  child: const Text("Cancel"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveAndClose,
                  child: const Text("Save"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static InputDecoration _dropdownDecoration() {
    return const InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.tealAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          // HEADER
          SizedBox(
            height: 32,
            child: Row(
              children: [
                const SizedBox(width: 10),
                const Icon(Icons.translate, size: 14, color: Colors.tealAccent),
                const SizedBox(width: 8),
                Text(
                  _isSettingsOpen
                      ? "Configuration"
                      : "Omni Bridge: Live AI Translator",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 15),
                IconButton(
                  icon: Icon(
                    _isSettingsOpen ? Icons.close : Icons.settings,
                    size: 14,
                    color: Colors.white54,
                  ),
                  onPressed: _toggleSettings,
                ),
                Expanded(child: MoveWindow()),
                MinimizeWindowButton(
                  colors: WindowButtonColors(iconNormal: Colors.white),
                ),
                CloseWindowButton(
                  colors: WindowButtonColors(
                    iconNormal: Colors.white,
                    mouseOver: Colors.red,
                  ),
                  onPressed: () => appWindow.close(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // BODY
          Expanded(
            child: _isSettingsOpen
                ? _buildSettingsUI()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ValueListenableBuilder<String>(
                      valueListenable: asrTextController,
                      builder: (_, text, _) {
                        return Text(
                          text,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
