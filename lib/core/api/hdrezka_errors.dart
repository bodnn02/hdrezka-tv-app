class LoginRequiredError implements Exception {
  final String message = 'Login is required to access this page.';
  @override
  String toString() => 'LoginRequiredError: $message';
}

class LoginFailed implements Exception {
  final String message;
  LoginFailed(this.message);
  @override
  String toString() => 'LoginFailed: $message';
}

class FetchFailed implements Exception {
  final String message = 'Failed to fetch stream!';
  @override
  String toString() => 'FetchFailed: $message';
}

class CaptchaError implements Exception {
  final String message = 'Failed to bypass captcha!';
  @override
  String toString() => 'CaptchaError: $message';
}

class HttpError implements Exception {
  final int code;
  final String reason;
  HttpError(this.code, [this.reason = '']);
  @override
  String toString() => 'HttpError: $code: $reason';
}
