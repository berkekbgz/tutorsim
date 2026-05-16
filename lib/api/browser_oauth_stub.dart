String? readOAuthState() => null;

void writeOAuthState(String state) {}

void clearOAuthState() {}

void openOAuthUrl(String url) {
  throw UnsupportedError('42 OAuth login is only available in a browser.');
}

void replaceBrowserUrl(String url) {}
