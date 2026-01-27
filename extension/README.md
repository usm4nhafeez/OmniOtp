# OmniOTP Chrome Extension

A Chrome extension that provides the same TOTP (Time-based One-Time Password) functionality as the OmniOTP mobile app.

## Features

- ✅ Generate TOTP codes (6-digit, 30-second period)
- ✅ Local storage of accounts
- ✅ Firebase Authentication (email/password)
- ✅ Cloud sync with mobile app (planned)
- ✅ Copy codes to clipboard
- ✅ Auto-refresh every 30 seconds
- ✅ Clean, modern UI

## Installation

### Development Mode

1. Open Chrome and navigate to `chrome://extensions/`
2. Enable "Developer mode" (toggle in top-right)
3. Click "Load unpacked"
4. Select the `extension` folder from this project

### Production

The extension is not yet published to the Chrome Web Store.

## Usage

### First Time Setup

1. Click the OmniOTP icon in your Chrome toolbar
2. Choose one of the following:
   - **Sign In**: Use the same email/password as your mobile app to sync accounts
   - **Use Locally Only**: Store accounts only in this browser (no sync)

### Adding Accounts

1. Click the '+' button
2. Enter one of the following:
   - The secret key (e.g., `JBSWY3DPEHPK3PXP`)
   - An `otpauth://` URL (from QR codes)
3. Fill in the issuer (e.g., "Google") and account name (e.g., "user@gmail.com")
4. Click "Add Account"

### Using Codes

1. Click on any 6-digit code to copy it to your clipboard
2. Paste into the website requesting the code
3. Codes auto-refresh every 30 seconds (watch the timer)

### Settings

- **Sync**: Manually sync with Firebase cloud storage
- **Sign Out**: Log out of your account (local data remains)
- **Delete All Data**: Remove all accounts from this browser

## Architecture

### Files

- `manifest.json` - Extension configuration
- `popup.html` - Main UI
- `popup.js` - UI logic and app controller
- `styles.css` - Styling
- `totp.js` - TOTP generation (RFC 6238)
- `storage.js` - Chrome Storage API wrapper
- `firebase.js` - Firebase integration (placeholder)
- `background.js` - Background service worker

### How It Works

1. **TOTP Generation**: Uses the same algorithm as the mobile app (HMAC-SHA1, 6 digits, 30-second period)
2. **Storage**: Accounts stored locally using Chrome Storage API
3. **Encryption**: Secrets stored in plain text locally (browser's built-in security)
4. **Sync**: Can connect to same Firebase backend as mobile app

### Security Notes

⚠️ **Important**: 
- Secrets are stored unencrypted in Chrome's local storage
- Chrome's built-in extension sandboxing provides some protection
- For production, implement additional encryption layer
- Only install from trusted sources

## Firebase Integration

To enable cloud sync:

1. Open `firebase.js`
2. Replace the Firebase config with your project's config:
```javascript
this.config = {
  apiKey: "your-api-key",
  authDomain: "your-project.firebaseapp.com",
  projectId: "your-project-id",
  storageBucket: "your-project.appspot.com",
  messagingSenderId: "123456789",
  appId: "your-app-id"
};
```
3. Install Firebase SDK (add to manifest or use CDN)
4. Uncomment Firebase initialization and methods

## Development

### Requirements

- Chrome browser (version 88+)
- Basic knowledge of JavaScript, HTML, CSS

### Testing

1. Make changes to extension files
2. Go to `chrome://extensions/`
3. Click reload icon on OmniOTP card
4. Open extension popup to test changes

### Debugging

- Right-click extension popup → "Inspect" to open DevTools
- View console logs, inspect HTML, debug JavaScript
- Background service worker: Click "service worker" link in extension details

## Compatibility with Mobile App

The extension uses the same:
- TOTP algorithm (RFC 6238)
- Firebase Authentication
- Firestore database structure (`/vaults/{userId}`)
- Encryption format (when implemented)

This means accounts can be synced between:
- Flutter mobile app (Android/iOS)
- Chrome extension
- Any device with your credentials

## Roadmap

- [ ] Full Firebase integration with encryption
- [ ] QR code scanner (using webcam)
- [ ] Export/import accounts
- [ ] Password protection/master password
- [ ] Biometric lock (if browser supports Web Authentication API)
- [ ] Dark mode
- [ ] Account icons/logos
- [ ] Search/filter accounts

## License

Same as main OmniOTP project

## Support

For issues or questions, please check the main project README or open an issue on GitHub.
