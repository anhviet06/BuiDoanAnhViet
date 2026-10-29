import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'app_providers.dart';
import 'providers/auth_provider.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/token_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi');

  // Dựng các thành phần dùng chung và nối vòng 401 -> đăng xuất
  final storage = SecureTokenStorage();
  final api = ApiClient(storage: storage);
  final auth = AuthProvider(storage, AuthService(api));
  api.onUnauthorized = auth.handleUnauthorized;
  auth.init();

  runApp(MultiProvider(
    providers: buildAppProviders(api: api, auth: auth),
    child: const TimeGuardApp(),
  ));
}
