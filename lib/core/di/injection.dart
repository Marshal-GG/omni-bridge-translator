import 'package:get_it/get_it.dart';

// Fragments
import 'parts/bloc_di.dart';
import 'parts/repository_di.dart';
import 'parts/usecase_di.dart';
import 'parts/datasource_di.dart';

final sl = GetIt.instance;

Future<void> setupInjection() async {
  initDataSourceDI();
  initRepositoryDI();
  initUseCaseDI();
  initBlocDI();
}
