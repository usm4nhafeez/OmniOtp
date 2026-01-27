/**
 * Cross-platform encryption service using PBKDF2 + AES-256-GCM
 * Must match Flutter's SyncEncryptionService parameters exactly
 */
export class SyncEncryptionService {
  // Must match Flutter's parameters exactly
  static FIXED_SALT = 'OmniOTP_Sync_Salt_v1';
  static ITERATIONS = 100000;
  static KEY_LENGTH = 32; // 256 bits
  static IV_LENGTH = 12;  // 96 bits for GCM

  constructor() {
    this.derivedKey = null;
    this.userEmail = null;
  }

  /**
   * Derive encryption key from user's email and password
   * Uses PBKDF2-SHA256 - must match Flutter implementation
   */
  async deriveKey(email, password) {
    this.userEmail = email;
    
    // Create salt from fixed salt + email (same as Flutter)
    const saltString = `${SyncEncryptionService.FIXED_SALT}:${email}`;
    const saltBytes = new TextEncoder().encode(saltString);
    
    // Import password as key material
    const passwordBytes = new TextEncoder().encode(password);
    const keyMaterial = await crypto.subtle.importKey(
      'raw',
      passwordBytes,
      'PBKDF2',
      false,
      ['deriveBits', 'deriveKey']
    );
    
    // Derive the actual encryption key using PBKDF2
    this.derivedKey = await crypto.subtle.deriveKey(
      {
        name: 'PBKDF2',
        salt: saltBytes,
        iterations: SyncEncryptionService.ITERATIONS,
        hash: 'SHA-256'
      },
      keyMaterial,
      { name: 'AES-GCM', length: 256 },
      true, // extractable for debugging
      ['encrypt', 'decrypt']
    );
    
    return true;
  }

  /**
   * Check if key is derived
   */
  get isInitialized() {
    return this.derivedKey !== null;
  }

  /**
   * Clear the derived key (on logout)
   */
  clearKey() {
    this.derivedKey = null;
    this.userEmail = null;
  }

  /**
   * Encrypt data using AES-256-GCM
   * Returns base64 encoded: IV (12 bytes) + ciphertext + auth tag (16 bytes)
   */
  async encrypt(plainText) {
    if (!this.derivedKey) {
      throw new Error('Encryption key not derived. Call deriveKey() first.');
    }

    // Generate random IV
    const iv = crypto.getRandomValues(new Uint8Array(SyncEncryptionService.IV_LENGTH));
    
    // Encrypt
    const plaintextBytes = new TextEncoder().encode(plainText);
    const ciphertext = await crypto.subtle.encrypt(
      { name: 'AES-GCM', iv: iv },
      this.derivedKey,
      plaintextBytes
    );

    // Combine IV + ciphertext (includes auth tag)
    const combined = new Uint8Array(iv.length + ciphertext.byteLength);
    combined.set(iv);
    combined.set(new Uint8Array(ciphertext), iv.length);

    // Return base64 encoded
    return btoa(String.fromCharCode(...combined));
  }

  /**
   * Decrypt data
   * Expects base64 encoded: IV (12 bytes) + ciphertext + auth tag
   */
  async decrypt(encryptedBase64) {
    if (!this.derivedKey) {
      throw new Error('Encryption key not derived. Call deriveKey() first.');
    }

    // Decode base64
    const combined = Uint8Array.from(atob(encryptedBase64), c => c.charCodeAt(0));
    
    // Split IV and ciphertext
    const iv = combined.slice(0, SyncEncryptionService.IV_LENGTH);
    const ciphertext = combined.slice(SyncEncryptionService.IV_LENGTH);

    // Decrypt
    const decrypted = await crypto.subtle.decrypt(
      { name: 'AES-GCM', iv: iv },
      this.derivedKey,
      ciphertext
    );

    return new TextDecoder().decode(decrypted);
  }

  /**
   * Encrypt accounts list for cloud sync
   */
  async encryptAccounts(accounts) {
    const data = {
      version: 2, // Version 2 = password-derived encryption
      accounts: accounts,
      timestamp: Date.now(),
      email: this.userEmail
    };
    return this.encrypt(JSON.stringify(data));
  }

  /**
   * Decrypt accounts list from cloud
   */
  async decryptAccounts(encryptedBase64) {
    const jsonStr = await this.decrypt(encryptedBase64);
    const data = JSON.parse(jsonStr);
    
    // Verify version
    if (data.version !== 2) {
      throw new Error(`Incompatible vault version: ${data.version}. Expected version 2.`);
    }
    
    return data.accounts || [];
  }
}
