import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/translation_bloc.dart';
import 'bloc/translation_event.dart';
import 'components/overlay_content.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
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
      body: Focus(
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
    );
  }
}
