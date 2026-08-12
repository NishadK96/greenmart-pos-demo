abstract final class Config {
  static const baseUrl = String.fromEnvironment(
    'EAZYERP_BASE_URL',
    defaultValue: 'https://eazyerp.co',
  );
}
