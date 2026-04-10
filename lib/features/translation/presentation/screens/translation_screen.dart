import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_bloc.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_event.dart';
import 'package:omni_bridge/features/translation/presentation/screens/components/overlay_content.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final _focusNode = FocusNode();
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // Hide content while the window repositions itself to overlay size.
    // The window resize is async (multiple OS calls), so for ~180ms the
    // window is mid-transition — rendering content during that window
    // causes a visible "glitch to wrong position" frame.
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final key = event.logicalKey;
    final bloc = context.read<TranslationBloc>();

    if (key == LogicalKeyboardKey.space) {
      bloc.add(ToggleRunningEvent());
      return KeyEventResult.handled;
    }

    if (ctrl && key == LogicalKeyboardKey.keyM) {
      bloc.add(ToggleShrinkEvent());
      return KeyEventResult.handled;
    }

    if (ctrl && key == LogicalKeyboardKey.keyH) {
      Navigator.pushNamed(context, '/history-panel');
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      appWindow.minimize();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 100),
        child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: WindowBorder(
          color: Colors.transparent,
          width: 0,
          child: Stack(
            children: [
              MoveWindow(),
              Center(child: buildOverlayContent(context)),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
