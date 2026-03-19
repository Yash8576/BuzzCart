import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/cart_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/upload_content_provider.dart';
import 'core/providers/add_product_provider.dart';
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
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            apiService: context.read<ApiService>(),
          ),
          lazy: false,  // Initialize immediately to load token
        ),
        ChangeNotifierProvider<CartProvider>(
          create: (context) => CartProvider(
            apiService: context.read<ApiService>(),
          ),
        ),
        ChangeNotifierProvider<UploadContentProvider>(
          create: (_) => UploadContentProvider(),
        ),
        ChangeNotifierProvider<AddProductProvider>(
          create: (_) => AddProductProvider(),
        ),
      ],
      child: const BuzzSocialCartApp(),
    ),
  );
}

class BuzzSocialCartApp extends StatefulWidget {
  const BuzzSocialCartApp({super.key});

  @override
  State<BuzzSocialCartApp> createState() => _BuzzSocialCartAppState();
}

class _BuzzSocialCartAppState extends State<BuzzSocialCartApp> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= createAppRouter(context.read<AuthProvider>());
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp.router(
      title: 'BuzzCart - Social Commerce',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeProvider.themeMode,
      routerConfig: _router!,
    );
  }
}
