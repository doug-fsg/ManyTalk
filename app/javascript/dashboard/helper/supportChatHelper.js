export function openSupportChat() {
  if (!window.$chatwoot) {
    return false;
  }

  // Open the chat window without revealing the floating launcher bubble.
  window.$chatwoot.toggle('open');
  return true;
}
