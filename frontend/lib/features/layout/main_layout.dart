import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/cart_provider.dart';

class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  
  final List<_NavItem> _navItems = [
    _NavItem(path: '/', icon: Icons.home, label: 'Home'),
    _NavItem(path: '/videos', icon: Icons.play_circle, label: 'Videos'),
    _NavItem(path: '/reels', icon: Icons.movie, label: 'Reels'),
    _NavItem(path: '/shop', icon: Icons.shopping_bag, label: 'Shop'),
    _NavItem(path: '/profile', icon: Icons.person, label: 'Profile'),
  ];

  final List<_NavItem> _sidebarOnlyItems = [
    _NavItem(path: '/search', icon: Icons.search, label: 'Search'),
    _NavItem(path: '/messages', icon: Icons.message, label: 'Messages'),
    _NavItem(path: '/settings', icon: Icons.settings, label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateActivity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateActivity();
    }
  }

  Future<void> _updateActivity() async {
    await _storage.write(
      key: 'last_activity',
      value: DateTime.now().toIso8601String(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Fetch cart when layout mounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().fetchCart();
    });
  }

  int _getCurrentIndex() {
    final location = GoRouterState.of(context).matchedLocation;
    
    // Find exact match first, then check for path prefix
    for (int i = 0; i < _navItems.length; i++) {
      if (location == _navItems[i].path) {
        return i;
      } else if (location.startsWith(_navItems[i].path) && _navItems[i].path != '/') {
        return i;
      }
    }
    
    // Default to home (index 0) if on root path
    if (location == '/') {
      return 0;
    }
    
    return 0; // fallback to home
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;

        return Scaffold(
          body: Row(
            children: [
              // Desktop sidebar
              if (isDesktop) _buildSidebar(),

              // Main content
              Expanded(
                child: Column(
                  children: [
                    // Mobile header
                    if (!isDesktop) _buildMobileHeader(),

                    // Page content
                    Expanded(child: widget.child),
                  ],
                ),
              ),
            ],
          ),
          // Mobile bottom navigation
          bottomNavigationBar: isDesktop ? null : _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildSidebar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().user;
    final location = GoRouterState.of(context).matchedLocation;
    final isHomePage = location == '/';

    return Container(
      width: 256,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: isHomePage
                ? PopupMenuButton<String>(
                    offset: const Offset(0, 50),
                    onSelected: (value) {
                      if (value == 'content') {
                        context.go('/upload-content');
                      } else if (value == 'product') {
                        context.go('/add-product');
                      }
                    },
                    itemBuilder: (context) {
                      final isSeller = user?.isSeller ?? false;
                      if (isSeller) {
                        return [
                          const PopupMenuItem(
                            value: 'content',
                            child: Row(
                              children: [
                                Icon(Icons.add_photo_alternate),
                                SizedBox(width: 12),
                                Text('Add Content'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'product',
                            child: Row(
                              children: [
                                Icon(Icons.inventory_2),
                                SizedBox(width: 12),
                                Text('Add Product'),
                              ],
                            ),
                          ),
                        ];
                      } else {
                        return [
                          const PopupMenuItem(
                            value: 'content',
                            child: Row(
                              children: [
                                Icon(Icons.add_photo_alternate),
                                SizedBox(width: 12),
                                Text('Add Content'),
                              ],
                            ),
                          ),
                        ];
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Buzz',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'Cart',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.electricBlue,
                                ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.keyboard_arrow_down, size: 20),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Buzz',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'Cart',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.electricBlue,
                              ),
                        ),
                      ],
                    ),
                  ),
          ),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ..._navItems.map((item) => _buildNavButton(item, true)),
                const SizedBox(height: 16),
                Divider(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                const SizedBox(height: 16),
                ..._sidebarOnlyItems.map((item) => _buildNavButton(item, true)),
              ],
            ),
          ),

          // User profile
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkAccent.withAlpha(128)
                    : AppColors.lightAccent.withAlpha(128),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.electricBlue,
                    child: Text(
                      user?.name[0].toUpperCase() ?? 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user?.name ?? 'User',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user?.email ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, size: 20),
                    onPressed: () async {
                      await context.read<AuthProvider>().logout();
                      if (mounted) {
                        context.go('/login');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cart = context.watch<CartProvider>().cart;
    final location = GoRouterState.of(context).matchedLocation;
    final isHomePage = location == '/';

    return SafeArea(
      bottom: false,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
        ),
      child: Row(
        children: [
          isHomePage
              ? PopupMenuButton<String>(
                  offset: const Offset(0, 40),
                  onSelected: (value) {
                    if (value == 'content') {
                      context.go('/upload-content');
                    } else if (value == 'product') {
                      context.go('/add-product');
                    }
                  },
                  itemBuilder: (context) {
                    final user = context.read<AuthProvider>().user;
                    final isSeller = user?.isSeller ?? false;
                    if (isSeller) {
                      return [
                        const PopupMenuItem(
                          value: 'content',
                          child: Row(
                            children: [
                              Icon(Icons.add_photo_alternate, size: 18),
                              SizedBox(width: 8),
                              Text('Add Content'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'product',
                          child: Row(
                            children: [
                              Icon(Icons.inventory_2, size: 18),
                              SizedBox(width: 8),
                              Text('Add Product'),
                            ],
                          ),
                        ),
                      ];
                    } else {
                      return [
                        const PopupMenuItem(
                          value: 'content',
                          child: Row(
                            children: [
                              Icon(Icons.add_photo_alternate, size: 18),
                              SizedBox(width: 8),
                              Text('Add Content'),
                            ],
                          ),
                        ),
                      ];
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          'Buzz',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'Cart',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.electricBlue,
                              ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 18),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Buzz',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Cart',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.electricBlue,
                            ),
                      ),
                    ],
                  ),
                ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/search'),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () => context.go('/cart'),
              ),
              if (cart.itemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.electricBlue,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${cart.itemCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIndex = _getCurrentIndex();

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          context.go(_navItems[index].path);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.electricBlue,
        unselectedItemColor: isDark
            ? AppColors.darkMutedForeground
            : AppColors.lightMutedForeground,
        items: _navItems
            .map((item) => BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildNavButton(_NavItem item, bool isSidebar) {
    final location = GoRouterState.of(context).matchedLocation;
    final isActive = location == item.path || 
                     (location.startsWith(item.path) && item.path != '/');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isActive
            ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => context.go(item.path),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isActive
                      ? (isDark
                          ? AppColors.darkPrimaryForeground
                          : AppColors.lightPrimaryForeground)
                      : (isDark
                          ? AppColors.darkMutedForeground
                          : AppColors.lightMutedForeground),
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isActive
                            ? (isDark
                                ? AppColors.darkPrimaryForeground
                                : AppColors.lightPrimaryForeground)
                            : (isDark
                                ? AppColors.darkMutedForeground
                                : AppColors.lightMutedForeground),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String path;
  final IconData icon;
  final String label;

  _NavItem({required this.path, required this.icon, required this.label});
}
