import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/upload_content_provider.dart';
import '../providers/add_product_provider.dart';
import '../models/models.dart';
import '../../features/auth/screens/splash_page.dart';
import '../../features/auth/screens/login_page.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/layout/main_layout.dart';
import '../../features/home/screens/home_page.dart';
import '../../features/shop/screens/shop_page.dart';
import '../../features/videos/screens/videos_page.dart';
import '../../features/reels/screens/reels_page.dart';
import '../../features/cart/screens/cart_page.dart';
import '../../features/cart/screens/checkout_page.dart';
import '../../features/profile/screens/profile_page.dart';
import '../../features/messages/screens/messages_page.dart';
import '../../features/search/screens/search_page.dart';
import '../../features/settings/screens/settings_page.dart';
import '../../features/upload/presentation/screens/add_product_screen.dart';
import '../../features/upload/presentation/screens/upload_content_screen.dart';

// Create a router that refreshes when AuthProvider changes
GoRouter createAppRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isSplash = state.matchedLocation == '/splash';
      final isLogin = state.matchedLocation == '/login';
      final isSignup = state.matchedLocation == '/signup';
      final isAuth = isLogin || isSignup;

      debugPrint(
          'Router redirect - isLoading: ${authProvider.isLoading}, isAuthenticated: ${authProvider.isAuthenticated}, location: ${state.matchedLocation}');

      // Show splash while loading
      if (authProvider.isLoading) {
        return isSplash ? null : '/splash';
      }

      // After loading completes, redirect from splash
      if (isSplash && !authProvider.isLoading) {
        return authProvider.isAuthenticated ? '/' : '/login';
      }

      // Redirect authenticated users away from auth pages
      if (authProvider.isAuthenticated && isAuth) {
        return '/';
      }

      // Redirect unauthenticated users to login
      if (!authProvider.isAuthenticated && !isAuth && !isSplash) {
        return '/login';
      }

      return null;
    },
    routes: [
      // Splash screen
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),

      // Public routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),

      // Protected routes with layout
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: '/shop',
            builder: (context, state) => const ShopPage(),
          ),
          GoRoute(
            path: '/shop/:productId',
            builder: (context, state) {
              final productId = state.pathParameters['productId']!;
              final ownPreview =
                  state.uri.queryParameters['own_preview'] == '1';
              return ShopPage(
                productId: productId,
                allowOwnProductPreview: ownPreview,
              );
            },
          ),
          GoRoute(
            path: '/videos',
            builder: (context, state) => const VideosPage(),
          ),
          GoRoute(
            path: '/videos/:videoId',
            builder: (context, state) {
              final videoId = state.pathParameters['videoId']!;
              return VideosPage(videoId: videoId);
            },
          ),
          GoRoute(
            path: '/reels',
            builder: (context, state) => const ReelsPage(),
          ),
          GoRoute(
            path: '/cart',
            builder: (context, state) => const CartPage(),
          ),
          GoRoute(
            path: '/checkout',
            builder: (context, state) => const CheckoutPage(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: '/profile/:userId',
            builder: (context, state) {
              final userId = state.pathParameters['userId']!;
              return ProfilePage(userId: userId);
            },
          ),
          GoRoute(
            path: '/messages',
            builder: (context, state) => MessagesPage(
              intent: state.extra is MessagesRouteIntent
                  ? state.extra as MessagesRouteIntent
                  : null,
            ),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: '/add-product',
            builder: (context, state) {
              final editingProduct =
                  state.extra is ProductModel ? state.extra as ProductModel : null;
              return AddProductScreen(editingProduct: editingProduct);
            },
            onExit: (context) async {
              final provider = context.read<AddProductProvider>();
              if (!provider.hasUnsavedWork) {
                return true; // Allow navigation if no unsaved work
              }

              // Show confirmation dialog
              final shouldLeave = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Discard Product?'),
                  content: const Text(
                    'You have unsaved changes. Are you sure you want to discard this product?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Continue Editing'),
                    ),
                    TextButton(
                      onPressed: () {
                        provider.clearAll(); // Clear state on discard
                        Navigator.pop(context, true);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Discard'),
                    ),
                  ],
                ),
              );

              return shouldLeave ?? false;
            },
          ),
          GoRoute(
            path: '/upload-content',
            builder: (context, state) => const UploadContentScreen(),
            onExit: (context) async {
              final provider = context.read<UploadContentProvider>();
              if (!provider.hasUnsavedWork) {
                return true; // Allow navigation if no unsaved work
              }

              // Show confirmation dialog
              final shouldLeave = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Discard Content?'),
                  content: const Text(
                    'You have unsaved changes. Are you sure you want to discard this content?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Continue Editing'),
                    ),
                    TextButton(
                      onPressed: () {
                        provider.clearAll(); // Clear state on discard
                        Navigator.pop(context, true);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Discard'),
                    ),
                  ],
                ),
              );

              return shouldLeave ?? false;
            },
          ),
        ],
      ),
    ],
  );
}
