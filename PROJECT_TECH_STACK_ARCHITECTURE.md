# FPTeen - Tech stack & Kiến trúc dự án

## 1) Tổng quan
`fpteen` là một ứng dụng mobile (Flutter) dùng để đặt đồ online tại căng tin trường FPT. Hệ thống backend chạy trên **Supabase** (Postgres + RLS + RPC + Edge Functions) và app truy cập thông qua **Supabase Flutter SDK**.

## 2) Tech stack

### Frontend (Flutter)
- Ngôn ngữ: **Dart** (SDK `^3.10.4`)
- UI framework: **Flutter**
- State management: **Riverpod** (`flutter_riverpod`)
- Navigation: **GoRouter** (`go_router`)
- Backend client: **Supabase Flutter** (`supabase_flutter`)
- Thanh toán: gọi **Supabase Edge Functions** + hiển thị trang thanh toán bằng **WebView** (`webview_flutter`)
- Auth: **Google Sign-In** (`google_sign_in`)
- Media/UI:
  - Ảnh: `cached_network_image`
  - QR: `qr_flutter`, `mobile_scanner`
- HTTP/Integration: **Dio** (`dio`) (được dùng cho các luồng gọi server/thanh toán)
- Tiện ích:
  - Định dạng tiền & thời gian: `intl`
  - Camera / upload ảnh menu: `image_picker`
  - Screenshot/ảnh: `screenshot`, `gal`
  - Quyền truy cập: `permission_handler`

Nguồn chính: `pubspec.yaml`, `lib/main.dart`, `lib/core/router/app_router.dart`.

### Backend (Supabase)
- CSDL: **PostgreSQL** (trong Supabase)
- Auth & RLS: dùng RLS policies (thể hiện qua các migration `*_rls_*.sql`)
- RPC (SQL functions):
  - Ví dụ: `public.get_store_rating_stats(p_store_id uuid)` trong `supabase/migrations/20260304000011_store_analytics.sql`
- Edge Functions (Deno + TypeScript):
  - `create-payment`
  - `payment-webhook`
  - `confirm-order`
  - `cancel-order`
  - `create-store-owner`
  - Cấu hình `supabase/config.toml` cho biết các function đang `verify_jwt = false`

### Tích hợp “Realtime”
- App sử dụng **Supabase Realtime** (Postgres changes) để cập nhật danh sách đơn theo thời gian thực (ví dụ trong `CanteenOrdersNotifier`).

## 3) Kiến trúc & mô hình tổ chức mã

### Feature-first (module hóa theo nghiệp vụ)
`lib/features/*` chia theo domain/luồng nghiệp vụ, ví dụ:
- `lib/features/auth/*`
- `lib/features/home/*`
- `lib/features/menu/*`, `lib/features/menu_management/*`
- `lib/features/orders/*`
- `lib/features/checkout/*`
- `lib/features/feedback/*`
- `lib/features/analytics/*`
- `lib/features/reports/*`
- `lib/features/admin/*`

### Phân lớp cơ bản
- Presentation (UI):
  - `lib/features/**/screens/*`
  - Widget đọc dữ liệu qua Riverpod (`ConsumerWidget`, `ConsumerStatefulWidget`)
- State / Orchestration:
  - `lib/features/**/providers/*`
  - Dùng `Provider`, `FutureProvider`, `StateNotifierProvider`, `StateNotifier`
- Data access (Repository):
  - `lib/data/repositories/*`
  - Repository gọi Supabase qua `supabaseClientProvider` (RPC, select/update, storage, realtime trigger)
- Core:
  - `lib/core/router/app_router.dart`: routing & role redirect
  - `lib/core/theme/app_theme.dart`: theme
  - `lib/core/errors/*`: các exception chuẩn hóa
  - `lib/core/constants/*`: config app
- Shared:
  - `lib/shared/widgets/*`: component dùng chung (loading/error/empty state)

### State management cụ thể (Riverpod)
- `Provider` / `FutureProvider` gắn logic gọi repo (ví dụ: fetch store, fetch reviews, fetch stats)
- `StateNotifierProvider` dùng cho các màn có state chuyển trạng thái (ví dụ checkout, canteen orders)
- Realtime subscriptions thường được setup trong notifier (và được cleanup khi dispose)

### Navigation cụ thể (GoRouter)
- `routerProvider` trong `lib/core/router/app_router.dart`
- Có redirect theo role:
  - Admin: route bắt đầu `/admin`
  - Store owner: route bắt đầu `/canteen`
  - Customer: route bắt đầu `/home`
- Nested routes cho `/home`:
  - `store/:storeId`
  - `store/:storeId/feedback`
  - `cart`, `checkout`, `orders`, `my-reports`, ...

### Data access cụ thể (Supabase)
- RPC: gọi qua `supabase.rpc('function_name', params: {...})`
- Query bảng:
  - `supabase.from('table').select(...).eq(...).order(...).limit(...)`
- Supabase Auth:
  - lấy `supabase.auth.currentUser?.id` để gắn reviewer/customer khi cần
- Edge Functions:
  - `supabase.functions.invoke('create-payment', body: {...})`

## 4) Luồng nghiệp vụ tiêu biểu

### Luồng thanh toán (Checkout)
1. `CheckoutNotifier.placeOrder()`:
   - tạo order (thường qua RPC trong `OrderRepository.createOrder`)
   - gọi Edge Function `create-payment` với `{order_id, gateway}`
2. `PaymentWebViewScreen`:
   - nhúng `payment_url` trong WebView
   - intercept return/callback URL để quyết định success/fail
3. Khi success:
   - refresh `orderHistoryProvider`, clear `cartProvider`, reset `checkoutProvider`
   - điều hướng tới `'/home/invoice/:orderId'`

Nguồn tham chiếu: `lib/features/checkout/providers/checkout_provider.dart`, `lib/features/checkout/screens/payment_webview_screen.dart`.

### Luồng canteen xác nhận/hủy
- Xác nhận qua Edge Function `confirm-order`
- Hủy qua Edge Function `cancel-order` (đảm bảo chỉ các trạng thái cho phép mới được hủy theo nghiệp vụ)
- UI cập nhật theo realtime và/hoặc optimistic update trong notifier

## 5) Các điểm cần lưu ý khi mở rộng
- Giữ nguyên mô hình Riverpod + Repository để tránh “đẩy logic” vào UI.
- Các call tới Supabase nên nằm trong `data/repositories/*` hoặc provider; UI chỉ render + điều khiển state.
- Với các thay đổi status đơn (hủy/xác nhận), cần kiểm tra:
  - điều kiện cho phép thao tác trên UI
  - logic RPC/analytics (ví dụ revenue chỉ tính `paid/confirmed`)
  - RLS policies để customer/store owner nhìn đúng dữ liệu

