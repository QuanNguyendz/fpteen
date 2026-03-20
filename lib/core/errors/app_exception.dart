class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'AppException($code): $message';
}

class AppAuthException extends AppException {
  const AppAuthException(super.message, {super.code});
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.code});
}

class PaymentException extends AppException {
  const PaymentException(super.message, {super.code});
}

class OrderException extends AppException {
  const OrderException(super.message, {super.code});
}

class StoreException extends AppException {
  const StoreException(super.message, {super.code});
}

String parseSupabaseError(Object error) {
  final msg = error.toString();
  if (msg.contains('Invalid login credentials')) {
    return 'Email hoặc mật khẩu không đúng.';
  }
  if (msg.contains('Email not confirmed')) {
    return 'Email chưa được xác nhận. Vui lòng kiểm tra hộp thư.';
  }
  if (msg.contains('User already registered')) {
    return 'Email này đã được đăng ký.';
  }
  if (msg.contains('row-level security')) {
    return 'Bạn không có quyền thực hiện thao tác này.';
  }
  if (msg.contains('network') || msg.contains('SocketException')) {
    return 'Không có kết nối mạng. Vui lòng thử lại.';
  }
  if (msg.contains('No available pickup slots')) {
    return 'Quầy đang bận. Hệ thống sẽ dời giờ nhận cho đơn của bạn.';
  }
  if (msg.contains('Store not found or inactive')) {
    return 'Cửa hàng hiện không khả dụng. Vui lòng chọn cửa hàng khác.';
  }
  if (msg.contains('No valid available items')) {
    return 'Không thể tạo đơn do món trong giỏ hàng không còn khả dụng.';
  }
  return 'Đã xảy ra lỗi. Vui lòng thử lại.';
}


