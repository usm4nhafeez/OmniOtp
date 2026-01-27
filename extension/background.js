// Background service worker for Chrome extension
// Handles alarms, notifications, and background sync

// Set up alarm for OTP refresh
chrome.runtime.onInstalled.addListener(() => {
  // Create alarm to fire every 30 seconds (TOTP period)
  chrome.alarms.create('otpRefresh', { periodInMinutes: 0.5 });
});

// Handle alarm
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === 'otpRefresh') {
    // Notify popup to refresh OTPs if open
    chrome.runtime.sendMessage({ type: 'REFRESH_OTPS' });
  }
});

// Handle messages from popup
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'SYNC_REQUEST') {
    // Handle background sync
    handleBackgroundSync()
      .then(() => sendResponse({ success: true }))
      .catch((error) => sendResponse({ success: false, error: error.message }));
    return true; // Keep channel open for async response
  }
});

async function handleBackgroundSync() {
  // TODO: Implement background sync with Firebase
  console.log('Background sync triggered');
}

// Handle extension updates
chrome.runtime.onUpdateAvailable.addListener(() => {
  // Notify user about available update
  chrome.runtime.reload();
});

console.log('OmniOTP background service worker initialized');
