import { TotpService } from './totp.js';
import { StorageService } from './storage.js';
import { FirebaseService } from './firebase.js';
import { SyncEncryptionService } from './sync-encryption.js';

class PopupApp {
  constructor() {
    this.storage = new StorageService();
    this.firebase = new FirebaseService();
    this.syncEncryption = new SyncEncryptionService();
    this.currentScreen = 'auth';
    this.accounts = [];
    this.timerInterval = null;
    this.userPassword = null; // Temporarily stored for key derivation
    
    this.init();
  }

  async init() {
    // Restore Firebase auth state
    const firebaseUser = await this.firebase.restoreAuthState();
    
    // Check if user is authenticated or has local data
    if (firebaseUser) {
      await this.storage.setCurrentUser(firebaseUser);
      // Note: Can't derive key without password - user needs to re-enter on sync
      await this.loadAccounts();
      this.showScreen('main');
    } else if (await this.storage.hasLocalData()) {
      await this.loadAccounts();
      this.showScreen('main');
    } else {
      this.showScreen('auth');
    }

    this.setupEventListeners();
    this.startTimer();
  }

  setupEventListeners() {
    // Auth - handle both sign in and sign up
    document.getElementById('auth-form').addEventListener('submit', (e) => this.handleAuth(e));
    document.getElementById('skip-auth-btn').addEventListener('click', () => this.skipAuth());
    document.getElementById('toggle-auth-mode')?.addEventListener('click', () => this.toggleAuthMode());
    document.getElementById('forgot-password-btn')?.addEventListener('click', () => this.handleForgotPassword());

    // Main screen
    document.getElementById('add-account-btn').addEventListener('click', () => this.showScreen('add-account'));
    document.getElementById('sync-btn').addEventListener('click', () => this.syncWithCloud());

    // Add account
    document.getElementById('back-btn').addEventListener('click', () => this.showScreen('main'));
    document.getElementById('add-account-form').addEventListener('submit', (e) => this.handleAddAccount(e));

    // Settings
    document.getElementById('settings-btn').addEventListener('click', () => this.showScreen('settings'));
    document.getElementById('settings-back-btn').addEventListener('click', () => this.showScreen('main'));
    const logoutBtn = document.getElementById('logout-btn');
    if (logoutBtn) logoutBtn.addEventListener('click', () => this.handleLogout());
    document.getElementById('delete-all-btn').addEventListener('click', () => this.handleDeleteAll());
    document.getElementById('download-cloud-btn')?.addEventListener('click', () => this.downloadFromCloud());
    document.getElementById('upload-cloud-btn')?.addEventListener('click', () => this.uploadToCloud());
  }

  showScreen(screen) {
    document.querySelectorAll('.screen').forEach(s => s.classList.add('hidden'));
    document.getElementById(`${screen}-screen`).classList.remove('hidden');
    
    this.currentScreen = screen;

    // Update settings screen
    if (screen === 'settings') {
      this.updateSettingsScreen();
    }

    // Show/hide timer
    document.getElementById('timer').style.display = screen === 'main' ? 'flex' : 'none';
  }

  async handleAuth(e) {
    e.preventDefault();
    const email = document.getElementById('email').value;
    const password = document.getElementById('password').value;
    const isSignUp = document.getElementById('auth-form').dataset.mode === 'signup';
    const submitBtn = document.getElementById('auth-submit-btn');

    try {
      submitBtn.disabled = true;
      submitBtn.textContent = isSignUp ? 'Creating account...' : 'Signing in...';
      
      let user;
      if (isSignUp) {
        user = await this.firebase.signUp(email, password);
      } else {
        user = await this.firebase.signIn(email, password);
      }
      
      await this.storage.setCurrentUser(user);
      
      // Derive encryption key from credentials for cross-platform sync
      await this.syncEncryption.deriveKey(email, password);
      this.userPassword = password; // Keep for re-derivation if needed
      
      await this.loadAccounts();
      
      // Sync from cloud on sign in (not sign up)
      if (!isSignUp) {
        try {
          const synced = await this.syncFromCloud();
          if (synced) {
            console.log('Synced accounts from cloud');
          }
        } catch (syncError) {
          console.log('No cloud data or sync error:', syncError);
        }
      }
      
      this.showScreen('main');
    } catch (error) {
      alert(error.message || 'Authentication failed');
    } finally {
      submitBtn.disabled = false;
      submitBtn.textContent = isSignUp ? 'Create Account' : 'Sign In';
    }
  }

  toggleAuthMode() {
    const form = document.getElementById('auth-form');
    const submitBtn = document.getElementById('auth-submit-btn');
    const toggleBtn = document.getElementById('toggle-auth-mode');
    const title = document.getElementById('auth-title');
    
    const isSignUp = form.dataset.mode !== 'signup';
    form.dataset.mode = isSignUp ? 'signup' : 'signin';
    
    submitBtn.textContent = isSignUp ? 'Create Account' : 'Sign In';
    toggleBtn.textContent = isSignUp ? 'Already have an account? Sign In' : 'Need an account? Sign Up';
    title.textContent = isSignUp ? 'Create Account' : 'Sign In';
  }

  async handleForgotPassword() {
    const email = document.getElementById('email').value;
    if (!email) {
      alert('Please enter your email address first');
      return;
    }
    
    try {
      await this.firebase.sendPasswordResetEmail(email);
      alert('Password reset email sent! Check your inbox.');
    } catch (error) {
      alert(error.message || 'Failed to send reset email');
    }
  }

  async skipAuth() {
    await this.loadAccounts();
    this.showScreen('main');
  }

  async loadAccounts() {
    this.accounts = await this.storage.getAccounts();
    this.renderAccounts();
  }

  renderAccounts() {
    const container = document.getElementById('accounts-list');
    const emptyState = document.getElementById('empty-state');

    if (this.accounts.length === 0) {
      emptyState.style.display = 'block';
      container.style.display = 'none';
      return;
    }

    emptyState.style.display = 'none';
    container.style.display = 'flex';
    
    // Render placeholder UI first, codes will be filled asynchronously
    container.innerHTML = this.accounts.map(account => `
      <div class="account-card" data-id="${account.id}">
        <div class="account-header">
          <div class="account-info">
            <h3>${this.escapeHtml(account.issuer)}</h3>
            <p>${this.escapeHtml(account.accountName)}</p>
          </div>
          <div class="account-actions">
            <button class="icon-btn delete-btn" data-id="${account.id}">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                <path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"/>
              </svg>
            </button>
          </div>
        </div>
        <div class="otp-display" data-id="${account.id}">...</div>
        <div class="copied-indicator" id="copied-${account.id}">Copied!</div>
      </div>
    `).join('');

    // Add click handlers
    container.querySelectorAll('.otp-display').forEach(el => {
      el.addEventListener('click', () => this.copyOtp(el.dataset.id));
    });

    container.querySelectorAll('.delete-btn').forEach(el => {
      el.addEventListener('click', (e) => {
        e.stopPropagation();
        this.deleteAccount(el.dataset.id);
      });
    });

    // Asynchronously compute and fill OTPs for each account (handles SHA1/SHA256/SHA512)
    for (const account of this.accounts) {
      const otpEl = container.querySelector(`.otp-display[data-id="${account.id}"]`);
      if (!otpEl) continue;
      // Generate and set code
      this.generateOtp(account).then(code => {
        otpEl.textContent = code;
      }).catch(err => {
        console.error('Failed to generate OTP for', account.id, err);
        otpEl.textContent = '-----';
      });
    }
  }

  // Asynchronously generate OTP for an account (uses Web Crypto when needed)
  async generateOtp(account) {
    try {
      return await TotpService.generateCodeAsync(account);
    } catch (e) {
      // Fallback to synchronous method if available
      try {
        return TotpService.generateCode(account);
      } catch (e2) {
        console.error('Failed to generate OTP:', e, e2);
        return '-----';
      }
    }
  }

  async copyOtp(accountId) {
    const account = this.accounts.find(a => a.id === accountId);
    if (!account) return;

    const otp = await this.generateOtp(account);
    await navigator.clipboard.writeText(otp);

    // Show copied indicator
    const indicator = document.getElementById(`copied-${accountId}`);
    indicator.classList.add('show');
    setTimeout(() => indicator.classList.remove('show'), 2000);
  }

  async handleAddAccount(e) {
    e.preventDefault();
    
    let secret = document.getElementById('secret').value.trim();
    const issuer = document.getElementById('issuer').value.trim();
    const accountName = document.getElementById('accountName').value.trim();

    // Parse otpauth:// URL if provided
    if (secret.startsWith('otpauth://')) {
      try {
        const parsed = this.parseOtpAuthUrl(secret);
        secret = parsed.secret;
      } catch (error) {
        alert('Invalid otpauth:// URL');
        return;
      }
    }

    // Remove spaces from secret
    secret = secret.replace(/\s/g, '');

    const account = {
      id: this.generateId(),
      issuer,
      accountName,
      secret,
      algorithm: 'SHA1',
      digits: 6,
      period: 30,
      createdAt: Date.now(),
      updatedAt: Date.now()
    };

    await this.storage.addAccount(account);
    await this.loadAccounts();
    
    // Reset form
    document.getElementById('add-account-form').reset();
    this.showScreen('main');

    // Sync if logged in
    const user = await this.storage.getCurrentUser();
    if (user) {
      await this.syncWithCloud();
    }
  }

  parseOtpAuthUrl(url) {
    const urlObj = new URL(url);
    const params = new URLSearchParams(urlObj.search);
    
    return {
      secret: params.get('secret'),
      issuer: params.get('issuer') || urlObj.pathname.split(':')[0].substring(1),
      accountName: decodeURIComponent(urlObj.pathname.split(':')[1] || ''),
      algorithm: params.get('algorithm') || 'SHA1',
      digits: parseInt(params.get('digits') || '6'),
      period: parseInt(params.get('period') || '30')
    };
  }

  async deleteAccount(accountId) {
    if (!confirm('Delete this account?')) return;

    await this.storage.deleteAccount(accountId);
    await this.loadAccounts();

    // Sync if logged in
    const user = await this.storage.getCurrentUser();
    if (user) {
      await this.syncWithCloud();
    }
  }

  async syncWithCloud() {
    const user = this.firebase.getCurrentUser();
    if (!user) {
      alert('Please sign in to sync with cloud');
      return;
    }

    // Check if encryption key is ready
    if (!this.syncEncryption.isInitialized) {
      // Need to re-derive key - prompt for password
      const password = prompt('Enter your password to enable sync:');
      if (!password) return;
      
      try {
        await this.syncEncryption.deriveKey(user.email, password);
        this.userPassword = password;
      } catch (e) {
        alert('Failed to initialize encryption. Please sign in again.');
        return;
      }
    }

    try {
      const syncBtn = document.getElementById('sync-btn');
      syncBtn.disabled = true;
      
      // Get local accounts
      const localAccounts = await this.storage.getAccounts();
      
      // Upload local accounts to cloud (this ensures deletions are synced)
      const encryptedData = await this.syncEncryption.encryptAccounts(localAccounts);
      await this.firebase.syncToCloud(encryptedData);
      
      await this.loadAccounts();
      alert(`Sync completed! ${localAccounts.length} account(s) uploaded.`);
    } catch (error) {
      console.error('Sync error:', error);
      alert('Sync failed: ' + error.message);
    } finally {
      document.getElementById('sync-btn').disabled = false;
    }
  }

  async syncFromCloud() {
    if (!this.syncEncryption.isInitialized) {
      return false;
    }
    
    try {
      const cloudAccounts = await this.syncFromCloudInternal();
      if (cloudAccounts.length > 0) {
        const localAccounts = await this.storage.getAccounts();
        const merged = this.mergeAccounts(localAccounts, cloudAccounts);
        await chrome.storage.local.set({ 'omniotp_accounts': merged });
        await this.loadAccounts();
        return true;
      }
    } catch (error) {
      console.error('Sync from cloud failed:', error);
      throw error;
    }
    return false;
  }

  async syncFromCloudInternal() {
    console.log('Fetching data from cloud...');
    const encryptedData = await this.firebase.syncFromCloud();
    
    if (!encryptedData) {
      console.log('No cloud data found');
      return [];
    }
    
    console.log('Cloud data received, length:', encryptedData.length);
    console.log('Decrypting with sync encryption...');
    
    try {
      // Decrypt using the password-derived key
      const accounts = await this.syncEncryption.decryptAccounts(encryptedData);
      console.log('Decrypted accounts:', accounts.length);
      return accounts;
    } catch (decryptError) {
      console.error('Decryption failed:', decryptError);
      // Check if it might be old format
      if (decryptError.message.includes('version')) {
        throw new Error('Cloud data uses incompatible format. Please sync from the mobile app first with the latest version.');
      }
      throw new Error('Failed to decrypt cloud data. Make sure you are using the same password as the mobile app.');
    }
  }

  mergeAccounts(local, cloud) {
    const accountMap = new Map();
    
    // Add local accounts
    for (const account of local) {
      accountMap.set(account.id, account);
    }
    
    // Merge cloud accounts (newer wins)
    for (const account of cloud) {
      const existing = accountMap.get(account.id);
      if (!existing || (account.updatedAt > existing.updatedAt)) {
        accountMap.set(account.id, account);
      }
    }
    
    return Array.from(accountMap.values());
  }

  async handleLogout() {
    if (!confirm('Sign out? Your local data will remain.')) return;

    await this.firebase.signOut();
    await this.storage.setCurrentUser(null);
    this.syncEncryption.clearKey();
    this.userPassword = null;
    this.showScreen('auth');
  }

  async downloadFromCloud() {
    const user = this.firebase.getCurrentUser();
    if (!user) {
      alert('Please sign in first to download from cloud');
      return;
    }

    // Check if encryption key is ready
    if (!this.syncEncryption.isInitialized) {
      const password = prompt('Enter your password to enable sync:');
      if (!password) return;
      
      try {
        await this.syncEncryption.deriveKey(user.email, password);
        this.userPassword = password;
      } catch (e) {
        alert('Failed to initialize encryption. Please sign in again.');
        return;
      }
    }

    try {
      const cloudAccounts = await this.syncFromCloudInternal();
      
      if (cloudAccounts.length === 0) {
        alert('No accounts found in cloud. Make sure you have synced from the mobile app first.');
        return;
      }

      // Replace local accounts with cloud accounts
      await chrome.storage.local.set({ 'omniotp_accounts': cloudAccounts });
      await this.loadAccounts();
      alert(`Downloaded ${cloudAccounts.length} account(s) from cloud!`);
    } catch (error) {
      console.error('Download error:', error);
      alert('Download failed: ' + error.message);
    }
  }

  async uploadToCloud() {
    const user = this.firebase.getCurrentUser();
    if (!user) {
      alert('Please sign in first to upload to cloud');
      return;
    }

    // Check if encryption key is ready
    if (!this.syncEncryption.isInitialized) {
      const password = prompt('Enter your password to enable sync:');
      if (!password) return;
      
      try {
        await this.syncEncryption.deriveKey(user.email, password);
        this.userPassword = password;
      } catch (e) {
        alert('Failed to initialize encryption. Please sign in again.');
        return;
      }
    }

    try {
      const localAccounts = await this.storage.getAccounts();
      
      if (localAccounts.length === 0) {
        alert('No local accounts to upload.');
        return;
      }

      const encryptedData = await this.syncEncryption.encryptAccounts(localAccounts);
      await this.firebase.syncToCloud(encryptedData);
      alert(`Uploaded ${localAccounts.length} account(s) to cloud!`);
    } catch (error) {
      console.error('Upload error:', error);
      alert('Upload failed: ' + error.message);
    }
  }

  async handleDeleteAll() {
    if (!confirm('Delete all accounts? This cannot be undone.')) return;

    await this.storage.clearAllAccounts();
    await this.loadAccounts();
  }

  updateSettingsScreen() {
    this.storage.getCurrentUser().then(user => {
      const accountSection = document.getElementById('account-section');
      if (user) {
        accountSection.classList.remove('hidden');
        document.getElementById('user-email').textContent = user.email || 'Unknown';
      } else {
        accountSection.classList.add('hidden');
      }
    });
  }

  startTimer() {
    this.updateTimer();
    this.timerInterval = setInterval(() => {
      this.updateTimer();
      
      // Refresh OTPs when timer resets
      if (this.getRemainingSeconds() === 30) {
        this.renderAccounts();
      }
    }, 1000);
  }

  updateTimer() {
    const seconds = this.getRemainingSeconds();
    const timerEl = document.getElementById('timer');
    const secondsEl = document.getElementById('timer-seconds');
    
    secondsEl.textContent = seconds;
    
    timerEl.classList.remove('warning', 'danger');
    if (seconds <= 5) {
      timerEl.classList.add('danger');
    } else if (seconds <= 10) {
      timerEl.classList.add('warning');
    }
  }

  getRemainingSeconds() {
    const now = Math.floor(Date.now() / 1000);
    return 30 - (now % 30);
  }

  generateId() {
    return Date.now().toString(36) + Math.random().toString(36).substring(2);
  }

  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
}

// Initialize app
new PopupApp();
