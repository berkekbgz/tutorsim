import 'package:web/web.dart' as web;

const _stateKey = 'tutorsim_42_oauth_state';

String? readOAuthState() => web.window.localStorage.getItem(_stateKey);

void writeOAuthState(String state) {
  web.window.localStorage.setItem(_stateKey, state);
}

void clearOAuthState() {
  web.window.localStorage.removeItem(_stateKey);
}

void openOAuthUrl(String url) {
  web.window.location.assign(url);
}

void replaceBrowserUrl(String url) {
  web.window.history.replaceState(null, web.document.title, url);
}
