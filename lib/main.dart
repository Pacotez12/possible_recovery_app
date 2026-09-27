import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/api_client.dart';
import 'data/local_db.dart';
import 'data/queue_service.dart';
import 'data/sync_service.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme/tokens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final localDb = LocalDb();
  final apiClient = ApiClient();
  final syncService = SyncService(apiClient: apiClient, localDb: localDb);
  final queueService = QueueService(apiClient: apiClient, localDb: localDb);

  runApp(
    MultiProvider(
      providers: [
        Provider<LocalDb>.value(value: localDb),
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider<SyncService>.value(value: syncService),
        ChangeNotifierProvider<QueueService>.value(value: queueService),
      ],
      child: const PossibleRecoveryApp(),
    ),
  );
}

class PossibleRecoveryApp extends StatelessWidget {
  const PossibleRecoveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POSsible Recovery',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SplashScreen(),
    );
  }
}
