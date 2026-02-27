import 'app.dart';
import 'core/routes/routes_config.dart';
import 'core/tray_manager.dart';
import 'core/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the window and tray manager
  await initializeWindow();
  await initializeTray();

  runApp(const MyApp());

  // Configure the main window once it is ready
  doWhenWindowReady(() {
    configureMainWindow();
  });
}
