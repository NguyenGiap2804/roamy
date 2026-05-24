class ApiEndpoints {
  const ApiEndpoints._();

  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    return 'https://roamy-backend-wyfp.onrender.com/api/v1';
  }

  static const categories = '/categories';
  static const places = '/places';
  static const schedules = '/schedules';
  static const events = '/events';
  static const authRegister = '/auth/register';
  static const authLogin = '/auth/login';
  static const authGoogle = '/auth/google';
  static const authRefresh = '/auth/refresh';
  static const authLogout = '/auth/logout';
  static const authResendEmail = '/auth/email/resend';
  static const authVerifyEmail = '/auth/email/verify';
  static const authForgotPassword = '/auth/password/forgot';
  static const authResetPassword = '/auth/password/reset';
  static const me = '/me';

  static String placeById(String id) => '$places/$id';
  static String scheduleById(String id) => '$schedules/$id';
}
