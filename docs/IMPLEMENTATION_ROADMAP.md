# Buzz Social Cart - Complete Implementation Roadmap

## Overview
This document provides a complete, step-by-step roadmap for building the Buzz Social Cart platform, covering mobile app, web app, backend, and chatbot integration.

---

## PHASE 1: FOUNDATION (Completed ✓)

### 1.1 Architecture & Design ✓
- [x] System architecture diagram created
- [x] Technology stack justified
- [x] Database schema designed (003_buzz_social_cart_schema.sql)
- [x] API contracts documented (docs/api-contracts.md)

### 1.2 Database Setup
**File**: `database/migrations/003_buzz_social_cart_schema.sql`

**Run Migration**:
```bash
cd database
psql -U postgres -d buzzsocialcart -f migrations/003_buzz_social_cart_schema.sql
```

### 1.3 Flutter Dependencies ✓
**File**: `frontend/pubspec.yaml` (updated)

**Install Dependencies**:
```bash
cd frontend
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## PHASE 2: FLUTTER MOBILE APP CORE

### 2.1 Core Architecture (IN PROGRESS)

**Files Created**:
- ✓ `lib/core/config/app_config.dart` - Application configuration
- ✓ `lib/core/theme/app_theme.dart` - Theme definitions
- ✓ `lib/core/models/user.dart` - User models
- ✓ `lib/core/models/product.dart` - Product models

**Files To Create**:

#### Models (Data Layer)
```
lib/core/models/
├── content.dart          # Video & Reel models
├── cart.dart             # Shopping cart models
├── order.dart            # Order models
├── message.dart          # Messaging models
├── search.dart           # Search models
├── analytics.dart        # Analytics event models
└── common.dart           # Shared models (ApiResponse, ErrorResponse, etc.)
```

#### Network Layer
```
lib/core/network/
├── api_client.dart       # Dio HTTP client setup
├── api_endpoints.dart    # All API endpoint constants
├── api_interceptor.dart  # Auth token interceptor
├── network_error.dart    # Error handling
└── ws_client.dart        # WebSocket client for messaging
```

#### Storage Layer
```
lib/core/storage/
├── secure_storage.dart   # JWT token storage (flutter_secure_storage)
├── local_storage.dart    # App preferences (shared_preferences)
└── cache_manager.dart    # API response caching
```

#### Utilities
```
lib/core/utils/
├── validators.dart       # Form validation (email, password, etc.)
├── formatters.dart       # Currency, date formatting
├── logger.dart           # Logging utility
├── constants.dart        # App-wide constants
└── extensions.dart       # Dart extensions
```

#### Routing
```
lib/core/router/
├── app_router.dart       # GoRouter configuration
├── route_guards.dart     # Auth guards
└── routes.dart           # Route name constants
```

### 2.2 State Management with Riverpod

**Provider Structure**:
```
lib/core/providers/
├── auth_provider.dart         # Authentication state
├── theme_provider.dart        # Theme mode state
├── user_provider.dart         # Current user state
├── cart_provider.dart         # Shopping cart state
├── settings_provider.dart     # App settings state
└── connectivity_provider.dart # Network status
```

**Example: Auth Provider**
```dart
// lib/core/providers/auth_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

part 'auth_provider.g.dart';

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AsyncValue<User?> build() {
    // Check if user is already logged in
    return _checkAuth();
  }

  Future<AsyncValue<User?>> _checkAuth() async {
    final authService = ref.read(authServiceProvider);
    try {
      final user = await authService.getCurrentUser();
      return AsyncValue.data(user);
    } catch (e) {
      return const AsyncValue.data(null);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    final authService = ref.read(authServiceProvider);
    
    state = await AsyncValue.guard(() async {
      final authResponse = await authService.login(email, password);
      await authService.saveToken(authResponse.token);
      return authResponse.user;
    });
  }

  Future<void> signup(String email, String password, String username) async {
    state = const AsyncValue.loading();
    final authService = ref.read(authServiceProvider);
    
    state = await AsyncValue.guard(() async {
      final authResponse = await authService.signup(email, password, username);
      await authService.saveToken(authResponse.token);
      return authResponse.user;
    });
  }

  Future<void> logout() async {
    final authService = ref.read(authServiceProvider);
    await authService.logout();
    state = const AsyncValue.data(null);
  }
}
```

### 2.3 Services (Repository Pattern)

**Service Structure**:
```
lib/core/services/
├── auth_service.dart         # Authentication
├── user_service.dart         # User profile & settings
├── product_service.dart      # Product CRUD
├── cart_service.dart         # Cart operations
├── order_service.dart        # Order management
├── content_service.dart      # Videos & Reels
├── search_service.dart       # Search functionality
├── message_service.dart      # Messaging
├── analytics_service.dart    # Event tracking
└── chatbot_service.dart      # RAG chatbot (already exists)
```

---

## PHASE 3: AUTHENTICATION SCREENS

### 3.1 Auth Screens
**User Stories Covered**: Onboarding & Authentication Epic

**Files**:
```
lib/features/auth/
├── presentation/
│   ├── screens/
│   │   ├── login_screen.dart
│   │   ├── signup_screen.dart
│   │   └── welcome_screen.dart
│   └── widgets/
│       ├── email_field.dart
│       ├── password_field.dart
│       ├── auth_button.dart
│       └── social_login_buttons.dart
├── domain/
│   └── repositories/
│       └── auth_repository.dart
└── data/
    ├── repositories/
    │   └── auth_repository_impl.dart
    └── datasources/
        └── auth_remote_datasource.dart
```

**Key Implementation**:
- Login form with email/password
- Signup form with validation
- Password confirmation
- Loading states
- Error handling with clear messages
- Session persistence
- Auto-redirect after successful login

---

## PHASE 4: MAIN APP STRUCTURE

### 4.1 Navigation Shell
**User Stories Covered**: Global Navigation & Structure

**Files**:
```
lib/features/main/
├── presentation/
│   ├── main_screen.dart           # Bottom nav container (mobile)
│   ├── main_web_screen.dart       # Side nav container (web)
│   └── widgets/
│       ├── bottom_nav_bar.dart
│       ├── side_nav_bar.dart
│       └── app_drawer.dart
```

**Mobile Bottom Navigation**:
```dart
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const VideosScreen(),
    const ReelsScreen(),
    const ShoppingScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_outline),
            activeIcon: Icon(Icons.play_circle),
            label: 'Videos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.videocam_outlined),
            activeIcon: Icon(Icons.videocam),
            label: 'Reels',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            activeIcon: Icon(Icons.shopping_bag),
            label: 'Shopping',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showChatbot(context),
        child: const Icon(Icons.chat_bubble_outline),
      ),
    );
  }

  void _showChatbot(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatbotScreen()),
    );
  }
}
```

**Web Side Navigation**:
```dart
class MainWebScreen extends ConsumerStatefulWidget {
  const MainWebScreen({super.key});

  @override
  ConsumerState<MainWebScreen> createState() => _MainWebScreenState();
}

class _MainWebScreenState extends ConsumerState<MainWebScreen> {
  String _currentRoute = '/home';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Side Navigation
          SideNavigationBar(
            currentRoute: _currentRoute,
            onRouteChanged: (route) => setState(() => _currentRoute = route),
          ),
          // Main Content
          Expanded(
            child: _buildScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildScreen() {
    switch (_currentRoute) {
      case '/home':
        return const HomeScreen();
      case '/videos':
        return const VideosScreen();
      case '/reels':
        return const ReelsScreen();
      case '/shopping':
        return const ShoppingScreen();
      case '/profile':
        return const ProfileScreen();
      case '/search':
        return const SearchScreen();
      case '/messages':
        return const MessagesScreen();
      case '/settings':
        return const SettingsScreen();
      default:
        return const HomeScreen();
    }
  }
}
```

---

## PHASE 5: FEATURE SCREENS

### 5.1 Home Feed
**User Stories Covered**: Home Feed & Content Discovery

**Files**:
```
lib/features/home/
├── presentation/
│   ├── screens/
│   │   └── home_screen.dart
│   ├── widgets/
│   │   ├── product_card.dart
│   │   ├── content_preview_card.dart
│   │   ├── feed_item.dart
│   │   └── empty_feed_state.dart
│   └── providers/
│       └── home_feed_provider.dart
├── domain/
│   ├── models/
│   │   └── feed_item.dart
│   └── repositories/
│       └── feed_repository.dart
└── data/
    └── repositories/
        └── feed_repository_impl.dart
```

**Implementation**:
- Mixed feed (products + videos + reels)
- Pull-to-refresh
- Infinite scroll pagination
- Loading shimmer effect
- Empty state
- Error handling with retry

### 5.2 Videos & Reels
**User Stories Covered**: Videos & Reels Epics

**Files**:
```
lib/features/content/
├── presentation/
│   ├── screens/
│   │   ├── videos_screen.dart
│   │   ├── reels_screen.dart
│   │   ├── video_player_screen.dart
│   │   └── content_detail_screen.dart
│   └── widgets/
│       ├── video_card.dart
│       ├── reel_player.dart
│       ├── video_controls.dart
│       ├── product_tag_overlay.dart
│       └── like_button.dart
├── domain/
│   └── repositories/
│       └── content_repository.dart
└── data/
    └── repositories/
        └── content_repository_impl.dart
```

**Key Features**:
- Video player with controls (video_player + chewie)
- Vertical swipe reels (PageView)
- Autoplay when visible
- Product tags on videos
- Like/Unlike
- View tracking

### 5.3 Shopping & Cart
**User Stories Covered**: Shopping & Cart Epic

**Files**:
```
lib/features/shopping/
├── presentation/
│   ├── screens/
│   │   ├── shopping_screen.dart
│   │   ├── product_detail_screen.dart
│   │   ├── cart_screen.dart
│   │   └── checkout_screen.dart
│   └── widgets/
│       ├── product_grid.dart
│       ├── product_list_item.dart
│       ├── cart_item_card.dart
│       ├── cart_summary.dart
│       ├── product_image_carousel.dart
│       ├── product_rating_widget.dart
│       └── filter_bottom_sheet.dart
├── domain/
│   └── repositories/
│       ├── product_repository.dart
│       └── cart_repository.dart
└── data/
    └── repositories/
        ├── product_repository_impl.dart
        └── cart_repository_impl.dart
```

### 5.4 Search
**User Stories Covered**: Search Epic

**Files**:
```
lib/features/search/
├── presentation/
│   ├── screens/
│   │   ├── search_screen.dart
│   │   └── search_results_screen.dart
│   └── widgets/
│       ├── search_bar_widget.dart
│       ├── search_suggestions.dart
│       ├── search_filters.dart
│       └── category_tabs.dart
├── domain/
│   └── repositories/
│       └── search_repository.dart
└── data/
    └── repositories/
        └── search_repository_impl.dart
```

### 5.5 Messaging
**User Stories Covered**: Messaging Epic

**Files**:
```
lib/features/messaging/
├── presentation/
│   ├── screens/
│   │   ├── conversations_screen.dart
│   │   └── chat_screen.dart
│   └── widgets/
│       ├── conversation_list_item.dart
│       ├── message_bubble.dart
│       ├── product_message_card.dart
│       └── message_input.dart
├── domain/
│   └── repositories/
│       └── messaging_repository.dart
└── data/
    ├── repositories/
    │   └── messaging_repository_impl.dart
    └── websocket/
        └── message_websocket_client.dart
```

**WebSocket Integration**:
```dart
class MessageWebSocketClient {
  late WebSocketChannel _channel;
  final StreamController<Message> _messageController = StreamController.broadcast();

  Stream<Message> get messages => _messageController.stream;

  void connect(String token) {
    _channel = WebSocketChannel.connect(
      Uri.parse('${AppConfig.wsBaseUrl}/messaging?token=$token'),
    );

    _channel.stream.listen((data) {
      final message = Message.fromJson(jsonDecode(data));
      _messageController.add(message);
    });
  }

  void sendMessage(String conversationId, String text) {
    _channel.sink.add(jsonEncode({
      'type': 'send_message',
      'conversation_id': conversationId,
      'message_text': text,
      'message_type': 'text',
    }));
  }

  void disconnect() {
    _channel.sink.close();
    _messageController.close();
  }
}
```

### 5.6 Profile & Settings
**User Stories Covered**: Profile & Settings Epics

**Files**:
```
lib/features/profile/
├── presentation/
│   ├── screens/
│   │   ├── profile_screen.dart
│   │   ├── edit_profile_screen.dart
│   │   ├── settings_screen.dart
│   │   ├── followers_screen.dart
│   │   └── following_screen.dart
│   └── widgets/
│       ├── profile_header.dart
│       ├── profile_stats.dart
│       ├── content_grid.dart
│       └── settings_tile.dart
├── domain/
│   └── repositories/
│       ├── profile_repository.dart
│       └── settings_repository.dart
└── data/
    └── repositories/
        ├── profile_repository_impl.dart
        └── settings_repository_impl.dart
```

### 5.7 Chatbot Integration
**User Stories Covered**: Chatbot functionality

**Files**:
```
lib/features/chatbot/
├── presentation/
│   ├── screens/
│   │   └── chatbot_screen.dart
│   └── widgets/
│       ├── chat_message_bubble.dart
│       ├── source_document_card.dart
│       ├── chat_input.dart
│       └── document_upload_button.dart
├── domain/
│   └── repositories/
│       └── chatbot_repository.dart
└── data/
    └── repositories/
        └── chatbot_repository_impl.dart
```

**Already exists**: `lib/shared/services/chatbot_service.dart` - Use this

### 5.8 Seller Tools
**User Stories Covered**: Seller Tools & Analytics

**Files**:
```
lib/features/seller/
├── presentation/
│   ├── screens/
│   │   ├── product_management_screen.dart
│   │   ├── create_product_screen.dart
│   │   ├── seller_analytics_screen.dart
│   │   └── upload_content_screen.dart
│   └── widgets/
│       ├── product_form.dart
│       ├── image_picker_widget.dart
│       ├── analytics_chart.dart
│       └── product_metrics_card.dart
├── domain/
│   └── repositories/
│       └── seller_repository.dart
└── data/
    └── repositories/
        └── seller_repository_impl.dart
```

---

## PHASE 6: BACKEND API (Go)

### 6.1 Project Structure
```
backend/
├── cmd/
│   └── server/
│       └── main.go                # Entry point
├── internal/
│   ├── config/
│   │   └── config.go              # App configuration
│   ├── models/
│   │   ├── user.go
│   │   ├── product.go
│   │   ├── content.go
│   │   ├── cart.go
│   │   ├── order.go
│   │   └── message.go
│   ├── handlers/
│   │   ├── auth_handler.go
│   │   ├── user_handler.go
│   │   ├── product_handler.go
│   │   ├── content_handler.go
│   │   ├── cart_handler.go
│   │   ├── order_handler.go
│   │   ├── message_handler.go
│   │   └── search_handler.go
│   ├── services/
│   │   ├── auth_service.go
│   │   ├── user_service.go
│   │   ├── product_service.go
│   │   ├── content_service.go
│   │   ├── cart_service.go
│   │   ├── order_service.go
│   │   └── message_service.go
│   ├── repository/
│   │   ├── user_repository.go
│   │   ├── product_repository.go
│   │   ├── content_repository.go
│   │   ├── cart_repository.go
│   │   ├── order_repository.go
│   │   └── message_repository.go
│   ├── middleware/
│   │   ├── auth.go                # JWT authentication
│   │   ├── cors.go
│   │   ├── logger.go
│   │   └── rate_limiter.go
│   ├── database/
│   │   └── postgres.go            # DB connection
│   ├── websocket/
│   │   └── hub.go                 # WebSocket hub for messaging
│   └── utils/
│       ├── jwt.go
│       ├── hash.go
│       └── validator.go
└── pkg/
    └── errors/
        └── errors.go               # Custom errors
```

### 6.2 Example: Auth Handler
```go
// internal/handlers/auth_handler.go
package handlers

import (
    "encoding/json"
    "net/http"
    "github.com/gorilla/mux"
    "backend/internal/services"
)

type AuthHandler struct {
    authService *services.AuthService
}

func NewAuthHandler(authService *services.AuthService) *AuthHandler {
    return &AuthHandler{authService: authService}
}

type SignupRequest struct {
    Email           string `json:"email" validate:"required,email"`
    Password        string `json:"password" validate:"required,min=8"`
    PasswordConfirm string `json:"password_confirm" validate:"required"`
    Username        string `json:"username" validate:"required,min=3,max=50"`
    Role            string `json:"role" validate:"oneof=consumer seller"`
}

func (h *AuthHandler) Signup(w http.ResponseWriter, r *http.Request) {
    var req SignupRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        respondError(w, http.StatusBadRequest, "Invalid request")
        return
    }

    if req.Password != req.PasswordConfirm {
        respondError(w, http.StatusBadRequest, "Passwords don't match")
        return
    }

    authResponse, err := h.authService.Signup(req.Email, req.Password, req.Username, req.Role)
    if err != nil {
        respondError(w, http.StatusBadRequest, err.Error())
        return
    }

    respondJSON(w, http.StatusCreated, authResponse)
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
    var req struct {
        Email    string `json:"email"`
        Password string `json:"password"`
    }
    
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        respondError(w, http.StatusBadRequest, "Invalid request")
        return
    }

    authResponse, err := h.authService.Login(req.Email, req.Password)
    if err != nil {
        respondError(w, http.StatusUnauthorized, "Invalid credentials")
        return
    }

    respondJSON(w, http.StatusOK, authResponse)
}
```

### 6.3 Main Router Setup
```go
// cmd/server/main.go
package main

import (
    "log"
    "net/http"
    "github.com/gorilla/mux"
    "backend/internal/config"
    "backend/internal/database"
    "backend/internal/handlers"
    "backend/internal/middleware"
)

func main() {
    cfg := config.Load()
    db := database.Connect(cfg.DatabaseURL)
    
    router := mux.NewRouter()
    
    // Middleware
    router.Use(middleware.CORS)
    router.Use(middleware.Logger)
    
    // Public routes
    authHandler := handlers.NewAuthHandler(/* ... */)
    router.HandleFunc("/api/v1/auth/signup", authHandler.Signup).Methods("POST")
    router.HandleFunc("/api/v1/auth/login", authHandler.Login).Methods("POST")
    
    // Protected routes
    api := router.PathPrefix("/api/v1").Subrouter()
    api.Use(middleware.AuthMiddleware)
    
    api.HandleFunc("/auth/me", authHandler.GetMe).Methods("GET")
    api.HandleFunc("/auth/logout", authHandler.Logout).Methods("POST")
    
    // Product routes
    productHandler := handlers.NewProductHandler(/* ... */)
    api.HandleFunc("/products", productHandler.GetProducts).Methods("GET")
    api.HandleFunc("/products", productHandler.CreateProduct).Methods("POST")
    api.HandleFunc("/products/{id}", productHandler.GetProduct).Methods("GET")
    api.HandleFunc("/products/{id}", productHandler.UpdateProduct).Methods("PUT")
    
    // WebSocket
    router.HandleFunc("/ws/messaging", handlers.HandleWebSocket)
    
    log.Printf("Server starting on :%s", cfg.Port)
    log.Fatal(http.ListenAndServe(":"+cfg.Port, router))
}
```

---

## PHASE 7: WEB APP (Flutter Web)

### 7.1 Responsive Layout Detection
```dart
// lib/core/utils/responsive_helper.dart
class ResponsiveHelper {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1024;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  static bool isWeb(BuildContext context) =>
      kIsWeb && (isTablet(context) || isDesktop(context));
}
```

### 7.2 Adaptive Navigation
```dart
// lib/features/main/presentation/main_adaptive_screen.dart
class MainAdaptiveScreen extends ConsumerWidget {
  const MainAdaptiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ResponsiveHelper.isWeb(context)) {
      return const MainWebScreen(); // Side navigation
    } else {
      return const MainScreen(); // Bottom navigation
    }
  }
}
```

---

## PHASE 8: DEPLOYMENT

### 8.1 Docker Setup
**Files**:
- `backend/Dockerfile` (exists)
- `chatbot/Dockerfile` (exists)
- `frontend/Dockerfile` (exists)
- `docker/docker-compose.yml` (exists)

### 8.2 Kubernetes (Optional)
**Files in `k8s/`**: Already configured

### 8.3 Mobile Build
```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ipa --release
```

### 8.4 Web Build
```bash
flutter build web --release
```

---

## USER STORIES COVERAGE CHECKLIST

### ✅ Onboarding & Authentication (11 stories)
- [x] Database schema
- [ ] Backend API
- [ ] Flutter screens
- [ ] Form validation
- [ ] Session management

### ✅ Global Navigation (9 stories)
- [x] Bottom nav (mobile)
- [ ] Side nav (web)
- [ ] Tab persistence
- [ ] Back navigation

### ✅ Home Feed (7 stories)
- [ ] Mixed feed display
- [ ] Pull to refresh
- [ ] Loading states
- [ ] Empty states

### ✅ Videos (9 stories)
- [ ] Video list/grid
- [ ] Video player
- [ ] Product tagging
- [ ] Cart from video

### ✅ Reels (8 stories)
- [ ] Vertical swipe
- [ ] Autoplay
- [ ] Sound controls
- [ ] Like/favorite

### ✅ Shopping & Cart (13 stories)
- [ ] Product browsing
- [ ] Filters/sort
- [ ] Cart management
- [ ] Checkout flow

### ✅ Seller Tools (7 stories)
- [ ] Product CRUD
- [ ] Content association
- [ ] Analytics dashboard

### ✅ Search (9 stories)
- [ ] Multi-category search
- [ ] Suggestions
- [ ] Result grouping

### ✅ Messaging (10 stories)
- [ ] Conversation list
- [ ] Chat UI
- [ ] Real-time WebSocket
- [ ] Product sharing

### ✅ Profile (8 stories)
- [ ] Profile display
- [ ] Edit profile
- [ ] Content/products grid
- [ ] Followers/following

### ✅ Settings (8 stories)
- [ ] Notification preferences
- [ ] Password change
- [ ] Privacy settings
- [ ] Theme switcher

### ✅ Themes (5 stories)
- [x] Light/dark themes
- [ ] System default
- [ ] Manual override
- [ ] Theme persistence

---

## NEXT STEPS

1. **Run database migration** to set up schema
2. **Complete Flutter models** (generate freezed files)
3. **Implement core services** (auth, products, etc.)
4. **Build authentication screens**
5. **Implement main navigation**
6. **Build feature screens** iteratively
7. **Develop backend API** in parallel
8. **Integrate chatbot** using existing service
9. **Test & refine**
10. **Deploy**

---

## ESTIMATED TIMELINE

- **Phase 1-2 (Foundation & Core)**: 1 week
- **Phase 3 (Auth)**: 3 days
- **Phase 4 (Navigation)**: 2 days
- **Phase 5 (Feature Screens)**: 3-4 weeks
  - Home Feed: 3 days
  - Videos/Reels: 1 week
  - Shopping/Cart: 1 week
  - Search: 3 days
  - Messaging: 1 week
  - Profile/Settings: 4 days
  - Seller Tools: 5 days
- **Phase 6 (Backend)**: 3-4 weeks (parallel)
- **Phase 7 (Web Adaptation)**: 1 week
- **Phase 8 (Deployment)**: 1 week

**Total**: 8-10 weeks for MVP
