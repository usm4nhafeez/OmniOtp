# OmniOTP Sync & TOTP Debugging Guide

## Issue 1: Accounts Not Syncing from Android to Extension

### Root Cause
The encrypted data structure or field names might not match between Android and Extension.

### Debug Steps:

1. **Check Firebase Console**
   - Go to Firebase Console → Firestore Database
   - Navigate to `vaults/{your_uid}`
   - Check if the document exists and has `encryptedData` field
   - Copy the `encryptedData` value for inspection

2. **Check Account Structure from Android**
   The Android app might be using different field names. Common variations:
   - `issuer` vs `name`
   - `accountName` vs `account` vs `label`
   - `secret` vs `key`
   - `algorithm` vs `algo` vs `hashAlgorithm`

3. **Verify Encryption/Decryption**
   - Both apps must use the same:
     - Salt: `OmniOTP_Sync_Salt_v1:{email}`
     - Iterations: 100,000
     - Key length: 256 bits
     - IV length: 12 bytes

### Fix: Update sync-encryption.js to log decrypted data

```javascript
async decryptAccounts(encryptedBase64) {
  const jsonStr = await this.decrypt(encryptedBase64);
  const data = JSON.parse(jsonStr);
  
  console.log('Decrypted vault data:', data);
  console.log('Accounts from cloud:', data.accounts);
  
  // Verify version
  if (data.version !== 2) {
    throw new Error(`Incompatible vault version: ${data.version}. Expected version 2.`);
  }
  
  return data.accounts || [];
}
```

## Issue 2: Different TOTP Codes Between Android and Extension

### Root Cause
The TOTP algorithm implementation must match EXACTLY, including:
- Time synchronization
- Base32 decoding
- HMAC calculation
- Dynamic truncation

### Common Issues:

1. **Time Drift**
   - Both devices must use the same time
   - Check if your computer's time is synchronized
   - Run: `date` on computer and compare with Android phone

2. **Algorithm Field**
   - Android might store: `"SHA1"`, `"SHA-1"`, `"sha1"`
   - Extension must normalize: `.toUpperCase().trim()`

3. **Secret Format**
   - Secrets might have spaces or dashes: `"ABCD EFGH"` vs `"ABCDEFGH"`
   - Must be cleaned before decoding

4. **Digits and Period**
   - Default is 6 digits, 30 second period
   - But some accounts use 8 digits or 60 second period
   - These MUST match

### Debug: Add Logging to TOTP Generation

Update popup.js `generateOtp` method:

```javascript
async generateOtp(account) {
  try {
    const now = Math.floor(Date.now() / 1000);
    const timeStep = Math.floor(now / (account.period || 30));
    
    console.log('Generating TOTP:', {
      issuer: account.issuer,
      currentTime: now,
      timeStep: timeStep,
      algorithm: account.algorithm,
      digits: account.digits,
      period: account.period,
      secretLength: account.secret?.length
    });
    
    const code = TotpService.generateCode(account);
    console.log('Generated code:', code);
    
    return code;
  } catch (e) {
    console.error('TOTP generation failed:', e, account);
    throw e;
  }
}
```

## Issue 3: Firebase Path Structure

### CRITICAL: Must Use Flat Structure

❌ **WRONG** (creates subcollection):
```
vaults/{uid}/vault/data
```

✅ **CORRECT** (single document):
```
vaults/{uid}
```

### Verify in Firebase Console:
1. Go to Firestore Database
2. Click on `vaults` collection
3. Click on your user ID document
4. You should see fields directly:
   - `encryptedData`
   - `updatedAt`
   - `version`
   - `userId`
5. There should be NO subcollections

## Testing Procedure

### Step 1: Test TOTP with Known Secret

Use this test secret: `JBSWY3DPEHPK3PXP` (decodes to "Hello!")

1. Add this account in Android app:
   - Issuer: "Test"
   - Account: "test@test.com"
   - Secret: `JBSWY3DPEHPK3PXP`
   - Algorithm: SHA1
   - Digits: 6
   - Period: 30

2. Note the code shown in Android app

3. Add same account in Chrome extension

4. Compare codes - they MUST match

### Step 2: Test Sync

1. Sign in to both Android and Extension with same email/password
2. Add account in Android app
3. Click "Sync" in Android app
4. Wait 5 seconds
5. Click "Sync" in Extension
6. The account should appear in Extension
7. The TOTP codes should match

### Step 3: Verify Bidirectional Sync

1. Add account in Extension
2. Click "Sync" in Extension
3. Wait 5 seconds
4. Pull to refresh in Android app
5. Account should appear in Android
6. Delete account in Android
7. Sync Android
8. Sync Extension
9. Account should be deleted in Extension

## Quick Fixes Checklist

- [ ] Extension uses `vaults/{uid}` (not subcollection)
- [ ] Android uses `vaults/{uid}` (not subcollection)
- [ ] Both use version 2 encryption
- [ ] Both use same salt: `OmniOTP_Sync_Salt_v1:{email}`
- [ ] Algorithm field is normalized to uppercase
- [ ] Secrets are cleaned (no spaces/dashes)
- [ ] Time is synchronized between devices
- [ ] Base32 decoding matches RFC 4648
- [ ] HMAC calculation is RFC 2104 compliant
- [ ] Dynamic truncation is RFC 6238 compliant

## If Still Not Working

1. **Export raw encrypted data from Firebase:**
   ```javascript
   // In browser console after signing in
   const firebase = new FirebaseService();
   await firebase.restoreAuthState();
   const encrypted = await firebase.syncFromCloud();
   console.log('Encrypted length:', encrypted.length);
   console.log('First 50 chars:', encrypted.substring(0, 50));
   ```

2. **Try to decrypt manually:**
   ```javascript
   // In browser console
   const syncEnc = new SyncEncryptionService();
   await syncEnc.deriveKey('your@email.com', 'yourpassword');
   const accounts = await syncEnc.decryptAccounts(encrypted);
   console.log('Decrypted accounts:', accounts);
   ```

3. **Check account structure:**
   ```javascript
   console.log('First account fields:', Object.keys(accounts[0]));
   console.log('First account:', accounts[0]);
   ```

## Account Field Mapping

If Android uses different field names, add this mapping in popup.js:

```javascript
function normalizeAccount(account) {
  return {
    id: account.id,
    issuer: account.issuer || account.name || 'Unknown',
    accountName: account.accountName || account.account || account.label || '',
    secret: (account.secret || account.key || '').replace(/[\s-]/g, ''),
    algorithm: (account.algorithm || account.algo || 'SHA1').toUpperCase(),
    digits: account.digits || 6,
    period: account.period || 30,
    updatedAt: account.updatedAt || Date.now()
  };
}

// Use in syncFromCloudInternal:
async syncFromCloudInternal() {
  const encryptedData = await this.firebase.syncFromCloud();
  if (!encryptedData) return [];
  
  const accounts = await this.syncEncryption.decryptAccounts(encryptedData);
  return accounts.map(normalizeAccount); // ← ADD THIS
}
```
