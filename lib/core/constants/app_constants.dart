class AppConstants {
  AppConstants._();

  static const String appName = 'FPTeen';

  // ── Supabase ──────────────────────────────────────────────
  // Replace these with your actual Supabase project values.
  // Go to: Supabase Dashboard → Project Settings → API
  static const String supabaseUrl = 'https://cfsazspmdabmmesydunl.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_ZnvZ8uP_uKbcw4_ngwrmIw_DhEIP7uU';

  // ── Payment ───────────────────────────────────────────────
  // The WebView intercepts navigation to this URL pattern to detect payment completion.
  // This must match the redirect URL set in the payment-webhook Edge Function.
  static const String paymentCallbackHost = 'fpteen.app';
  static const String paymentCallbackPath = '/payment/callback';

  // ── Order status ──────────────────────────────────────────
  static const int paymentTimeoutMinutes = 15;
  static const String statusPending = 'pending';
  static const String statusPaid = 'paid';
  static const String statusConfirmed = 'confirmed';
  static const String statusCancelled = 'cancelled';

  // ── User roles ────────────────────────────────────────────
  static const String roleAdmin = 'admin';
  static const String roleStoreOwner = 'store_owner';
  static const String roleCustomer = 'customer';

  // ── Payment methods ───────────────────────────────────────
  static const String gatewayVnpay = 'vnpay';
  static const String gatewayMomo = 'momo';
  static const String gatewayZalopay = 'zalopay';

  static const String googleWebClientId = '1001949644556-2lbr7i544mmrmctt0kb3jds97ub5jsnq.apps.googleusercontent.com';
}


