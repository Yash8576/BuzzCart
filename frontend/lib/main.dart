import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/cart_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/api_service.dart';
import 'core/router/app_router.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(
          create: (_) => ApiService(),
          lazy: false,  // Initialize immediately
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProxyProvider<ApiService, AuthProvider>(
          create: (context) => AuthProvider(
            apiService: context.read<ApiService>(),
          ),
          update: (_, api, __) => AuthProvider(apiService: api),
          lazy: false,  // Initialize immediately to load token
        ),
        ChangeNotifierProxyProvider<ApiService, CartProvider>(
          create: (context) => CartProvider(
            apiService: context.read<ApiService>(),
          ),
          update: (_, api, __) => CartProvider(apiService: api),
        ),
      ],
      child: const BuzzSocialCartApp(),
    ),
  );
}

class BuzzSocialCartApp extends StatelessWidget {
  const BuzzSocialCartApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    
    return MaterialApp.router(
      title: 'BuzzCart - Social Commerce',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeProvider.themeMode,
      routerConfig: createAppRouter(authProvider),
    );
  }
}
