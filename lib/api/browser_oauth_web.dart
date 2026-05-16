// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const _stateKey = 'tutorsim_42_oauth_state';

String? readOAuthState() => html.window.localStorage[_stateKey];

void writeOAuthState(String state) {
  html.window.localStorage[_stateKey] = state;
}

void clearOAuthState() {
  html.window.localStorage.remove(_stateKey);
}

void openOAuthUrl(String url) {
  html.window.location.assign(url);
}

void replaceBrowserUrl(String url) {
  html.window.history.replaceState(null, html.document.title, url);
}
