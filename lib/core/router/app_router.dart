import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fpteen/data/models/menu_item_model.dart';
import 'package:fpteen/data/models/order_model.dart';
import 'package:fpteen/features/ai_assistant/screens/ai_assistant_screen.dart';
import 'package:fpteen/features/admin/screens/admin_dashboard_screen.dart';
import 'package:fpteen/features/admin/screens/create_store_owner_screen.dart';
import 'package:fpteen/features/admin/screens/reports_management_screen.dart';
import 'package:fpteen/features/admin/screens/store_management_screen.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';
import 'package:fpteen/features/auth/screens/login_screen.dart';
import 'package:fpteen/features/auth/screens/register_screen.dart';
import 'package:fpteen/features/auth/screens/forgot_password_screen.dart';
import 'package:fpteen/features/auth/screens/reset_password_screen.dart';
import 'package:fpteen/features/canteen/screens/store_profile_screen.dart';
import 'package:fpteen/features/checkout/screens/checkout_screen.dart';
import 'package:fpteen/features/checkout/screens/continue_payment_screen.dart';
import 'package:fpteen/features/checkout/screens/payment_webview_screen.dart';
import 'package:fpteen/features/home/screens/home_screen.dart';
import 'package:fpteen/features/invoice/screens/invoice_screen.dart';
import 'package:fpteen/features/menu/screens/cart_screen.dart';
import 'package:fpteen/features/feedback/screens/store_feedback_screen.dart';
import 'package:fpteen/features/menu/screens/store_menu_screen.dart';
import 'package:fpteen/features/menu_management/screens/add_edit_menu_item_screen.dart';
import 'package:fpteen/features/menu_management/screens/menu_management_screen.dart';
import 'package:fpteen/features/orders/canteen/screens/canteen_order_list_screen.dart';
import 'package:fpteen/features/orders/canteen/screens/qr_scanner_screen.dart';
import 'package:fpteen/features/orders/customer/screens/order_history_screen.dart';
import 'package:fpteen/features/analytics/screens/store_analytics_screen.dart';
import 'package:fpteen/features/reports/screens/my_reports_screen.dart';
import 'package:fpteen/features/reports/screens/report_screen.dart';

class _AuthChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthChangeNotifier();

  ref.listen<AuthAppState>(authNotifierProvider, (_, _) => notifier.notify());
  ref.onDispose(notifier.dispose);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/login',
    redirect: (context, state) {
      final auth = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;
      final fullUri = state.uri.toString();

      // Handle Supabase DeepLinks (Host is 'login-callback')
      final isLoginCallback = fullUri.contains('login-callback');

      // Trong lúc đang tải trạng thái Auth, nếu dính deeplink rỗng path thì chuyển hướng vô trang chờ
      if (auth.isLoading) {
        if (loc == '/' || isLoginCallback) return '/login-callback';
        return null;
      }

      final isAuthenticated = auth.isAuthenticated;

      // Handle Password Recovery Flow
      if (auth.isRecoveringPassword) {
        if (loc == '/reset-password') return null;
        return '/reset-password';
      }

      final isAuthRoute = loc == '/login' ||
          loc == '/register' ||
          loc == '/forgot-password' ||
          loc == '/reset-password' ||
          loc.startsWith('/login-callback') ||
          isLoginCallback;

      // Not authenticated → login
      if (!isAuthenticated && !isAuthRoute) return '/login';

      // Authenticated on auth route → redirect to role home
      if (isAuthenticated && isAuthRoute) {
        final user = auth.user!;
        if (user.isAdmin) return '/admin';
        if (user.isStoreOwner) return '/canteen';
        return '/home';
      }

      // Role-based route protection
      if (isAuthenticated) {
        final user = auth.user!;

        // Admin: only /admin routes
        if (user.isAdmin && !loc.startsWith('/admin')) return '/admin';

        // Customer: only /home routes
        if (user.isCustomer && loc.startsWith('/canteen')) return '/home';
        if (user.isCustomer && loc.startsWith('/admin')) return '/home';

        // Store owner: only /canteen routes
        if (user.isStoreOwner && loc.startsWith('/home')) return '/canteen';
        if (user.isStoreOwner && loc.startsWith('/admin')) return '/canteen';
      }

      // Nếu link là login-callback nhưng chưa auth thì trỏ về dummy route
      if (isLoginCallback && !isAuthenticated) {
        return '/login-callback';
      }

      return null;
    },
    routes: [
      // ── Root Fallback ─────────────────────────────────────────────────────
      GoRoute(
        path: '/',
        redirect: (context, state) => '/login',
      ),

      // ── Auth ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        pageBuilder: (ctx, state) =>
        const NoTransitionPage(child: LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        builder: (ctx, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (ctx, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (ctx, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/login-callback',
        builder: (ctx, state) => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),

      // ── Customer ──────────────────────────────────────────────────────────
      GoRoute(
        path: '/home',
        pageBuilder: (ctx, state) =>
        const NoTransitionPage(child: HomeScreen()),
        routes: [
          GoRoute(
            path: 'ai',
            builder: (ctx, state) => const AiAssistantScreen(),
          ),
          GoRoute(
            path: 'store/:storeId',
            builder: (ctx, state) =>
                StoreMenuScreen(storeId: state.pathParameters['storeId']!),
          ),
          GoRoute(
            path: 'store/:storeId/feedback',
            builder: (ctx, state) => StoreFeedbackScreen(
              storeId: state.pathParameters['storeId']!,
            ),
          ),

          GoRoute(
            path: 'cart',
            builder: (ctx, state) => const CartScreen(),
          ),
          GoRoute(
            path: 'checkout',
            builder: (ctx, state) => const CheckoutScreen(),
          ),
          GoRoute(
            path: 'payment',
            builder: (ctx, state) {
              final extra = state.extra as Map<String, String>;
              return PaymentWebViewScreen(
                orderId: extra['orderId']!,
                paymentUrl: extra['paymentUrl']!,
              );
            },
          ),
          GoRoute(
            path: 'invoice/:orderId',
            builder: (ctx, state) =>
                InvoiceScreen(orderId: state.pathParameters['orderId']!),
          ),
          GoRoute(
            path: 'orders',
            builder: (ctx, state) => const OrderHistoryScreen(),
          ),
          GoRoute(
            path: 'my-reports',
            builder: (ctx, state) => const MyReportsScreen(),
          ),
          GoRoute(
            path: 'order/:orderId/continue-payment',
            builder: (ctx, state) {
              final orderId = state.pathParameters['orderId']!;
              final order = state.extra;
              return ContinuePaymentScreen(
                orderId: orderId,
                order: order is OrderModel ? order : null,
              );
            },
          ),
          GoRoute(
            path: 'report/:storeId',
            builder: (ctx, state) {
              final extra = state.extra as Map<String, String>?;
              return ReportScreen(
                storeId: state.pathParameters['storeId']!,
                storeName: extra?['storeName'] ?? 'Canteen',
              );
            },
          ),
        ],
      ),

      // ── Canteen / Store owner ─────────────────────────────────────────────
      GoRoute(
        path: '/canteen',
        pageBuilder: (ctx, state) =>
        const NoTransitionPage(child: CanteenOrderListScreen()),
        routes: [
          GoRoute(
            path: 'analytics',
            builder: (ctx, state) => const StoreAnalyticsScreen(),
          ),
          GoRoute(
            path: 'scan',
            builder: (ctx, state) => const QRScannerScreen(),
          ),
          GoRoute(
            path: 'profile',
            builder: (ctx, state) => const StoreProfileScreen(),
          ),
          GoRoute(
            path: 'menu',
            builder: (ctx, state) => const MenuManagementScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (ctx, state) =>
                const AddEditMenuItemScreen(menuItem: null),
              ),
              GoRoute(
                path: 'edit',
                builder: (ctx, state) => AddEditMenuItemScreen(
                  menuItem: state.extra as MenuItemModel,
                ),
              ),
            ],
          ),
        ],
      ),

      // ── Admin ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/admin',
        pageBuilder: (ctx, state) =>
        const NoTransitionPage(child: AdminDashboardScreen()),
        routes: [
          GoRoute(
            path: 'stores',
            builder: (ctx, state) => const StoreManagementScreen(),
          ),
          GoRoute(
            path: 'reports',
            builder: (ctx, state) => const ReportsManagementScreen(),
          ),
          GoRoute(
            path: 'create-owner',
            builder: (ctx, state) => const CreateStoreOwnerScreen(),
          ),
        ],
      ),
    ],

    errorBuilder: (ctx, state) => Scaffold(
      appBar: AppBar(title: const Text('Trang không tồn tại')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Trang bạn tìm không tồn tại.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ctx.go('/login'),
              child: const Text('Về trang chủ'),
            ),
          ],
        ),
      ),
    ),
  );
});
