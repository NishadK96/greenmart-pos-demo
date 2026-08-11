abstract final class Config {
  static const baseUrl = String.fromEnvironment(
    'EAZYERP_BASE_URL',
    defaultValue: 'https://eazyerp.co',
  );

  static const clientId = String.fromEnvironment(
    'EAZYERP_CLIENT_ID',
    defaultValue: '9',
  );

  static const clientSecret = String.fromEnvironment('EAZYERP_CLIENT_SECRET');
}
