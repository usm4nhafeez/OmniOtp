/**
 * Firebase Service for Chrome Extension
 * Uses Firebase REST API for authentication and Firestore
 * FIXED: Stores data at vaults/{uid} to match Android app structure (NO subcollections)
 */
export class FirebaseService {
  constructor() {
    // Firebase configuration - MUST match Flutter app's firebase_options.dart (web config)
    this.config = {
      apiKey: "AIzaSyCt9iXr9nqNsJRInJ-dEj0EKy2SzmnMZLg",
      authDomain: "omniotp-84dba.firebaseapp.com",
      projectId: "omniotp-84dba",
      storageBucket: "omniotp-84dba.firebasestorage.app",
      messagingSenderId: "396184200838",
      appId: "1:396184200838:web:98a5a9ffd18da28f39d307"
    };
    
    this.currentUser = null;
    this.idToken = null;
  }

  /**
   * Sign in with email and password using Firebase Auth REST API
   */
  async signIn(email, password) {
    const url = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${this.config.apiKey}`;
    
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          email,
          password,
          returnSecureToken: true
        })
      });

      const data = await response.json();
      
      if (!response.ok) {
        throw new Error(this.getErrorMessage(data.error?.message));
      }

      this.currentUser = {
        uid: data.localId,
        email: data.email,
        displayName: data.displayName
      };
      this.idToken = data.idToken;
      this.refreshToken = data.refreshToken;
      
      // Store auth state
      await chrome.storage.local.set({
        firebaseUser: this.currentUser,
        firebaseIdToken: this.idToken,
        firebaseRefreshToken: this.refreshToken,
        tokenExpiry: Date.now() + (parseInt(data.expiresIn) * 1000)
      });

      return this.currentUser;
    } catch (error) {
      console.error('Sign in error:', error);
      throw error;
    }
  }

  /**
   * Sign up with email and password
   */
  async signUp(email, password) {
    const url = `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${this.config.apiKey}`;
    
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          email,
          password,
          returnSecureToken: true
        })
      });

      const data = await response.json();
      
      if (!response.ok) {
        throw new Error(this.getErrorMessage(data.error?.message));
      }

      this.currentUser = {
        uid: data.localId,
        email: data.email
      };
      this.idToken = data.idToken;
      this.refreshToken = data.refreshToken;
      
      await chrome.storage.local.set({
        firebaseUser: this.currentUser,
        firebaseIdToken: this.idToken,
        firebaseRefreshToken: this.refreshToken,
        tokenExpiry: Date.now() + (parseInt(data.expiresIn) * 1000)
      });

      return this.currentUser;
    } catch (error) {
      console.error('Sign up error:', error);
      throw error;
    }
  }

  /**
   * Sign out and clear stored auth state
   */
  async signOut() {
    this.currentUser = null;
    this.idToken = null;
    this.refreshToken = null;
    
    await chrome.storage.local.remove([
      'firebaseUser',
      'firebaseIdToken', 
      'firebaseRefreshToken',
      'tokenExpiry'
    ]);
  }

  /**
   * Restore auth state from storage
   */
  async restoreAuthState() {
    const stored = await chrome.storage.local.get([
      'firebaseUser',
      'firebaseIdToken',
      'firebaseRefreshToken',
      'tokenExpiry'
    ]);

    if (stored.firebaseUser && stored.firebaseIdToken) {
      // Check if token is expired
      if (stored.tokenExpiry && Date.now() < stored.tokenExpiry) {
        this.currentUser = stored.firebaseUser;
        this.idToken = stored.firebaseIdToken;
        this.refreshToken = stored.firebaseRefreshToken;
        return this.currentUser;
      } else if (stored.firebaseRefreshToken) {
        // Try to refresh the token
        return await this.refreshIdToken(stored.firebaseRefreshToken);
      }
    }
    return null;
  }

  /**
   * Refresh the ID token using refresh token
   */
  async refreshIdToken(refreshToken) {
    const url = `https://securetoken.googleapis.com/v1/token?key=${this.config.apiKey}`;
    
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: `grant_type=refresh_token&refresh_token=${refreshToken}`
      });

      const data = await response.json();
      
      if (!response.ok) {
        throw new Error('Token refresh failed');
      }

      this.idToken = data.id_token;
      this.refreshToken = data.refresh_token;
      
      // Restore user info
      const storedUser = await chrome.storage.local.get('firebaseUser');
      this.currentUser = storedUser.firebaseUser;

      await chrome.storage.local.set({
        firebaseIdToken: this.idToken,
        firebaseRefreshToken: this.refreshToken,
        tokenExpiry: Date.now() + (parseInt(data.expires_in) * 1000)
      });

      return this.currentUser;
    } catch (error) {
      console.error('Token refresh error:', error);
      await this.signOut();
      return null;
    }
  }

  /**
   * Sync encrypted accounts to Firestore
   * CRITICAL: Stores at vaults/{uid} (single document, NO subcollections)
   * This matches the Android app's Firestore structure exactly
   */
  async syncToCloud(encryptedData) {
    if (!this.currentUser || !this.idToken) {
      throw new Error('Not authenticated');
    }

    // CRITICAL: Use vaults/{uid} NOT vaults/{uid}/vault/data
    // This is a single document at the root vaults collection
    const url = `https://firestore.googleapis.com/v1/projects/${this.config.projectId}/databases/(default)/documents/vaults/${this.currentUser.uid}?updateMask.fieldPaths=encryptedData&updateMask.fieldPaths=updatedAt&updateMask.fieldPaths=version&updateMask.fieldPaths=userId`;
    
    try {
      console.log('Syncing to Firestore path: vaults/' + this.currentUser.uid);
      
      const response = await fetch(url, {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${this.idToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          fields: {
            encryptedData: { stringValue: encryptedData },
            updatedAt: { timestampValue: new Date().toISOString() },
            version: { integerValue: '2' },
            userId: { stringValue: this.currentUser.uid }
          }
        })
      });

      if (!response.ok) {
        const error = await response.json();
        console.error('Firestore PATCH error:', error);
        throw new Error(error.error?.message || 'Sync failed');
      }

      console.log('Successfully synced to vaults/' + this.currentUser.uid);
      return true;
    } catch (error) {
      console.error('Sync to cloud error:', error);
      throw error;
    }
  }

  /**
   * Get encrypted accounts from Firestore
   * CRITICAL: Reads from vaults/{uid} (single document, NO subcollections)
   * This matches the Android app's Firestore structure exactly
   */
  async syncFromCloud() {
    if (!this.currentUser || !this.idToken) {
      throw new Error('Not authenticated');
    }

    // CRITICAL: Use vaults/{uid} NOT vaults/{uid}/vault/data
    const url = `https://firestore.googleapis.com/v1/projects/${this.config.projectId}/databases/(default)/documents/vaults/${this.currentUser.uid}`;
    
    try {
      console.log('Fetching from Firestore path: vaults/' + this.currentUser.uid);
      
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${this.idToken}`
        }
      });

      if (response.status === 404) {
        // No vault exists yet
        console.log('No vault found at vaults/' + this.currentUser.uid);
        return null;
      }

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error?.message || 'Failed to fetch from cloud');
      }

      const data = await response.json();
      console.log('Successfully fetched from vaults/' + this.currentUser.uid);
      
      return data.fields?.encryptedData?.stringValue || null;
    } catch (error) {
      console.error('Sync from cloud error:', error);
      throw error;
    }
  }

  /**
   * Send password reset email
   */
  async sendPasswordResetEmail(email) {
    const url = `https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${this.config.apiKey}`;
    
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          requestType: 'PASSWORD_RESET',
          email
        })
      });

      const data = await response.json();
      
      if (!response.ok) {
        throw new Error(this.getErrorMessage(data.error?.message));
      }

      return true;
    } catch (error) {
      console.error('Password reset error:', error);
      throw error;
    }
  }

  /**
   * Get current user
   */
  getCurrentUser() {
    return this.currentUser;
  }

  /**
   * Check if user is signed in
   */
  isSignedIn() {
    return this.currentUser !== null && this.idToken !== null;
  }

  /**
   * Convert Firebase error codes to user-friendly messages
   */
  getErrorMessage(errorCode) {
    const errorMessages = {
      'EMAIL_NOT_FOUND': 'No account found with this email address.',
      'INVALID_PASSWORD': 'Incorrect password. Please try again.',
      'USER_DISABLED': 'This account has been disabled.',
      'EMAIL_EXISTS': 'An account already exists with this email address.',
      'OPERATION_NOT_ALLOWED': 'Email/password sign-in is not enabled.',
      'TOO_MANY_ATTEMPTS_TRY_LATER': 'Too many attempts. Please try again later.',
      'INVALID_EMAIL': 'Please enter a valid email address.',
      'WEAK_PASSWORD': 'Password must be at least 6 characters.',
      'INVALID_LOGIN_CREDENTIALS': 'Invalid email or password.'
    };

    return errorMessages[errorCode] || errorCode || 'An unknown error occurred.';
  }
}
