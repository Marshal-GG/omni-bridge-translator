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
  bool _isShrunk = false;

  // --- COMMITTED SETTINGS ---
  String _activeTargetLang = 'en';
  String _activeSourceLang = 'auto';
  bool _activeUseMic = false;
  double _activeFontSize = 18.0;
  bool _activeIsBold = false;
  double _activeOpacity = 0.7;
  int? _activeInputDeviceIndex;
  int? _activeOutputDeviceIndex;

  // --- TEMP SETTINGS ---
  String _tempTargetLang = 'en';
  String _tempSourceLang = 'auto';
  bool _tempUseMic = false;
  double _tempFontSize = 18.0;
  bool _tempIsBold = false;
  double _tempOpacity = 0.7;
  int? _tempInputDeviceIndex;
  int? _tempOutputDeviceIndex;

  // --- DEVICES ---
  List<Map<String, dynamic>> _inputDevices = [];
  List<Map<String, dynamic>> _outputDevices = [];
  bool _devicesLoading = false;
  String _defaultInputDeviceName = 'Default';
  String _defaultOutputDeviceName = 'Default';

  final TextEditingController _fontSizeController = TextEditingController();
  final TextEditingController _opacityController = TextEditingController();

  // --- LANGUAGES ---
  final Map<String, String> _languages = {
    'auto': 'Auto-Detect',
    'none': 'Original Source (Transcription)',
    'en': 'English (en)',
    'es': 'Spanish (es)',
    'fr': 'French (fr)',
    'de': 'German (de)',
    'zh': 'Chinese (zh)',
    'ja': 'Japanese (ja)',
    'ko': 'Korean (ko)',
    'ru': 'Russian (ru)',
    'pt': 'Portuguese (pt)',
    'it': 'Italian (it)',
    'ar': 'Arabic (ar)',
    'hi': 'Hindi (hi)',
    'nl': 'Dutch (nl)',
    'tr': 'Turkish (tr)',
    'vi': 'Vietnamese (vi)',
    'pl': 'Polish (pl)',
    'id': 'Indonesian (id)',
    'th': 'Thai (th)',
    'bn': 'Bengali (bn)',
  };

  @override
  void initState() {
    super.initState();
    _asrClient.start(); // 🔥 Start Python ASR sidecar connection
  }

  @override
  void dispose() {
    _asrClient.stop();
    _fontSizeController.dispose();
    _opacityController.dispose();
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
      _tempFontSize = _activeFontSize;
      _tempIsBold = _activeIsBold;
      _tempOpacity = _activeOpacity;
      _tempInputDeviceIndex = _activeInputDeviceIndex;
      _tempOutputDeviceIndex = _activeOutputDeviceIndex;
      _fontSizeController.text = _tempFontSize.toInt().toString();
      _opacityController.text = (_tempOpacity * 100).toInt().toString();
      await windowManager.setSize(const Size(400, 820));
      appWindow.alignment = Alignment.center;
      _loadDevices();
    } else {
      await windowManager.setSize(const Size(730, 150));
      appWindow.alignment = Alignment.bottomCenter;
    }
  }

  // --- LOAD DEVICES ---
  Future<void> _loadDevices() async {
    setState(() => _devicesLoading = true);
    final result = await _asrClient.loadDevices();
    setState(() {
      _inputDevices =
          (result['input'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      _outputDevices =
          (result['output'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      _defaultInputDeviceName =
          result['default_input_name'] as String? ?? 'Default';
      _defaultOutputDeviceName =
          result['default_output_name'] as String? ?? 'Default';
      _devicesLoading = false;
    });
  }

  // --- DYNAMIC SHRINK SIZE ---
  double _calculateShrunkHeight() {
    // Base padding (approx 40) + (font size * estimated line height 1.5 * 2 lines max)
    return 40.0 + (_activeFontSize * 1.5 * 2);
  }

  // --- TOGGLE SHRINK ---
  Future<void> _toggleShrink() async {
    if (_isSettingsOpen) {
      await _toggleSettings();
    }

    setState(() {
      _isShrunk = !_isShrunk;
    });

    if (_isShrunk) {
      final double shrunkHeight = _calculateShrunkHeight();
      appWindow.minSize = const Size(100, 60);
      await windowManager.setSize(Size(730, shrunkHeight));
    } else {
      await windowManager.setSize(const Size(730, 150));
      appWindow.minSize = const Size(300, 150);
    }
  }

  // --- SAVE SETTINGS ---
  Future<void> _saveAndClose() async {
    setState(() {
      _activeTargetLang = _tempTargetLang;
      _activeSourceLang = _tempSourceLang;
      _activeUseMic = _tempUseMic;
      _activeFontSize = _tempFontSize;
      _activeIsBold = _tempIsBold;
      _activeOpacity = _tempOpacity;
      _activeInputDeviceIndex = _tempInputDeviceIndex;
      _activeOutputDeviceIndex = _tempOutputDeviceIndex;
      _isSettingsOpen = false;
    });

    debugPrint(
      "Saved: $_activeSourceLang → $_activeTargetLang (Mic: $_activeUseMic, InputDevice: $_activeInputDeviceIndex, OutputDevice: $_activeOutputDeviceIndex)",
    );

    _asrClient.updateSettings(
      sourceLang: _activeSourceLang,
      targetLang: _activeTargetLang,
      useMic: _activeUseMic,
      inputDeviceIndex: _activeInputDeviceIndex,
      outputDeviceIndex: _activeOutputDeviceIndex,
    );

    await windowManager.setSize(const Size(730, 150));
    appWindow.alignment = Alignment.bottomCenter;
  }

  // --- SETTINGS UI ---
  Widget _buildSettingsUI() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
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

                const SizedBox(height: 15),

                if (_devicesLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.tealAccent,
                        ),
                      ),
                    ),
                  )
                else ...[
                  // Input Device Dropdown (always visible)
                  const Text(
                    "Input Device (Microphone)",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  DropdownSearch<String>(
                    selectedItem: _tempInputDeviceIndex == null
                        ? 'Default ($_defaultInputDeviceName)'
                        : (_inputDevices.firstWhere(
                                (d) => d['index'] == _tempInputDeviceIndex,
                                orElse: () => {
                                  'name': 'Default ($_defaultInputDeviceName)',
                                },
                              )['name']
                              as String),
                    items: [
                      'Default ($_defaultInputDeviceName)',
                      ..._inputDevices.map((d) => d['name'] as String),
                    ],
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: _dropdownDecoration(),
                    ),
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      containerBuilder: (ctx, w) =>
                          Container(color: Colors.grey[900], child: w),
                      itemBuilder: (ctx, item, isSelected) => ListTile(
                        title: Text(
                          item,
                          style: const TextStyle(color: Colors.white),
                        ),
                        selected: isSelected,
                        selectedTileColor: Colors.teal.withValues(alpha: 0.2),
                      ),
                    ),
                    onChanged: (val) {
                      if (val == null || val.startsWith('Default')) {
                        setState(() => _tempInputDeviceIndex = null);
                      } else {
                        final idx =
                            _inputDevices.firstWhere(
                                  (d) => d['name'] == val,
                                )['index']
                                as int;
                        setState(() => _tempInputDeviceIndex = idx);
                      }
                    },
                  ),
                  const SizedBox(height: 15),

                  // Output Device Dropdown (always visible)
                  const Text(
                    "Output Device (System Audio)",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  DropdownSearch<String>(
                    selectedItem: _tempOutputDeviceIndex == null
                        ? 'Default ($_defaultOutputDeviceName)'
                        : (_outputDevices.firstWhere(
                                (d) => d['index'] == _tempOutputDeviceIndex,
                                orElse: () => {
                                  'name': 'Default ($_defaultOutputDeviceName)',
                                },
                              )['name']
                              as String),
                    items: [
                      'Default ($_defaultOutputDeviceName)',
                      ..._outputDevices.map((d) => d['name'] as String),
                    ],
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: _dropdownDecoration(),
                    ),
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      containerBuilder: (ctx, w) =>
                          Container(color: Colors.grey[900], child: w),
                      itemBuilder: (ctx, item, isSelected) => ListTile(
                        title: Text(
                          item,
                          style: const TextStyle(color: Colors.white),
                        ),
                        selected: isSelected,
                        selectedTileColor: Colors.teal.withValues(alpha: 0.2),
                      ),
                    ),
                    onChanged: (val) {
                      if (val == null || val.startsWith('Default')) {
                        setState(() => _tempOutputDeviceIndex = null);
                      } else {
                        final idx =
                            _outputDevices.firstWhere(
                                  (d) => d['name'] == val,
                                )['index']
                                as int;
                        setState(() => _tempOutputDeviceIndex = idx);
                      }
                    },
                  ),
                  const SizedBox(height: 15),
                ],

                const Divider(color: Colors.white24),
                const SizedBox(height: 10),

                const Text(
                  "Source Language",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 5),
                DropdownSearch<String>(
                  selectedItem: _languages[_tempSourceLang],
                  items: _languages.entries
                      .where((e) => e.key != 'none')
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
                      return Container(
                        color: Colors.grey[900],
                        child: popupWidget,
                      );
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
                      return Container(
                        color: Colors.grey[900],
                        child: popupWidget,
                      );
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

                const SizedBox(height: 25),
                const Divider(color: Colors.white24),
                const SizedBox(height: 10),

                const Text(
                  "Typography",
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),

                SwitchListTile(
                  title: const Text(
                    "Bold Text",
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: const Text(
                    "Make captions thicker and easier to read",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  value: _tempIsBold,
                  activeThumbColor: Colors.tealAccent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _tempIsBold = val),
                ),

                const SizedBox(height: 15),

                const Text(
                  "Font Size",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _tempFontSize,
                        min: 10.0,
                        max: 48.0,
                        divisions: 38,
                        activeColor: Colors.tealAccent,
                        inactiveColor: Colors.white24,
                        onChanged: (val) {
                          setState(() {
                            _tempFontSize = val;
                            _fontSizeController.text = val.toInt().toString();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: _fontSizeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.tealAccent),
                          ),
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val);
                          if (parsed != null && parsed >= 10 && parsed <= 48) {
                            setState(() {
                              _tempFontSize = parsed;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                const Divider(color: Colors.white24),
                const SizedBox(height: 10),

                const Text(
                  "Display",
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),

                const Text(
                  "Window Opacity",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _tempOpacity,
                        min: 0.1,
                        max: 1.0,
                        divisions: 18,
                        activeColor: Colors.tealAccent,
                        inactiveColor: Colors.white24,
                        onChanged: (val) {
                          setState(() {
                            _tempOpacity = val;
                            _opacityController.text = (val * 100)
                                .toInt()
                                .toString();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: _opacityController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          isDense: true,
                          suffix: Text(
                            '%',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.tealAccent),
                          ),
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null && parsed >= 10 && parsed <= 100) {
                            setState(() {
                              _tempOpacity = parsed / 100.0;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Opacity reset button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _tempOpacity = 0.7;
                      _opacityController.text = '70';
                    }),
                    icon: const Icon(
                      Icons.refresh,
                      size: 14,
                      color: Colors.white38,
                    ),
                    label: const Text(
                      'Reset to 70%',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // --- STICKY SAVE/CANCEL BUTTONS ---
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _toggleSettings,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: const Text("Cancel"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveAndClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    elevation: 4,
                  ),
                  child: const Text(
                    "Save",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
    if (_isShrunk) {
      return GestureDetector(
        onTap: _toggleShrink,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(
              alpha: _isSettingsOpen ? _tempOpacity : _activeOpacity,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Stack(
            children: [
              MoveWindow(),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ValueListenableBuilder<String>(
                    valueListenable: asrTextController,
                    builder: (_, text, _) {
                      return Text(
                        text.isEmpty ? "Listening..." : text,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _activeFontSize,
                          fontWeight: _activeIsBold
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: Colors.white,
                          shadows: const [
                            Shadow(
                              offset: Offset(1.0, 1.0),
                              blurRadius: 3.0,
                              color: Colors.black87,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(
          alpha: _isSettingsOpen ? _tempOpacity : _activeOpacity,
        ),
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
                IconButton(
                  icon: const Icon(
                    Icons.compress,
                    size: 14,
                    color: Colors.white70,
                  ),
                  onPressed: _toggleShrink,
                  tooltip: 'Shrink to Captions Only',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                ),
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
                          style: TextStyle(
                            fontSize: _activeFontSize,
                            fontWeight: _activeIsBold
                                ? FontWeight.bold
                                : FontWeight.normal,
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
