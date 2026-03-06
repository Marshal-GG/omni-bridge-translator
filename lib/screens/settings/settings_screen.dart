import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'bloc/settings_bloc.dart';
import 'bloc/settings_event.dart';
import 'bloc/settings_state.dart';

import 'components/settings_footer.dart';
import 'components/input_output_tab.dart';
import 'components/languages_tab.dart';
import 'components/display_tab.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<SettingsBloc>().add(LoadDevicesEvent());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: WindowBorder(
            color: Colors.white12,
            width: 1,
            child: Container(
              color: const Color(0xFF121212),
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFF1A1A1A),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.tealAccent,
                      indicatorWeight: 2,
                      labelColor: Colors.tealAccent,
                      unselectedLabelColor: Colors.white38,
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: const [
                        Tab(text: 'Input & Output'),
                        Tab(text: 'Languages'),
                        Tab(text: 'Display'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                          child: buildInputOutputTab(context, state),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildLanguagesTab(context, state),
                              const SizedBox(height: 28),
                              buildAiEngineSelector(context, state),
                            ],
                          ),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                          child: buildDisplayTab(context, state),
                        ),
                      ],
                    ),
                  ),
                  SettingsFooter(state: state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
