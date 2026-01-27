/**
 * TOTP Service - RFC 6238 compliant
 * Generates Time-based One-Time Passwords
 * FIXED: Matches Android app implementation exactly
 */
export class TotpService {
  /**
   * Generate TOTP code for an account
   * This is the primary method that should be used
   */
  static generateCode(account) {
    const { secret, digits = 6, period = 30, algorithm = 'SHA1' } = account;
    
    if (!secret) {
      throw new Error('Secret is required');
    }
    
    // Get current time step
    const timeStep = Math.floor(Date.now() / 1000 / period);
    
    // Generate HMAC based on algorithm (case-insensitive)
    const algo = (algorithm || 'SHA1').toUpperCase().trim();
    let hmac;
    
    switch (algo) {
      case 'SHA256':
      case 'SHA-256':
        hmac = this.hmacSha256Sync(secret, timeStep);
        break;
      case 'SHA512':
      case 'SHA-512':
        hmac = this.hmacSha512Sync(secret, timeStep);
        break;
      case 'SHA1':
      case 'SHA-1':
      default:
        hmac = this.hmacSha1Sync(secret, timeStep);
        break;
    }
    
    // Dynamic truncation (RFC 6238)
    const code = this.dynamicTruncate(hmac, digits);
    
    return code.padStart(digits, '0');
  }

  /**
   * Async version - calls sync version for compatibility
   */
  static async generateCodeAsync(account) {
    return this.generateCode(account);
  }

  /**
   * HMAC-SHA1 implementation
   */
  static hmacSha1Sync(secret, counter) {
    const key = this.base32Decode(secret);
    const message = this.counterToBytes(counter);
    
    const blockSize = 64;
    let keyBytes = key;
    
    // Hash key if longer than block size
    if (keyBytes.length > blockSize) {
      keyBytes = this.sha1Sync(keyBytes);
    }
    
    // Pad key to block size
    const paddedKey = new Uint8Array(blockSize);
    paddedKey.set(keyBytes);
    
    // Create inner and outer padded keys
    const ipad = new Uint8Array(blockSize);
    const opad = new Uint8Array(blockSize);
    
    for (let i = 0; i < blockSize; i++) {
      ipad[i] = paddedKey[i] ^ 0x36;
      opad[i] = paddedKey[i] ^ 0x5c;
    }
    
    // HMAC(key, message) = H(opad || H(ipad || message))
    const innerData = new Uint8Array(blockSize + message.length);
    innerData.set(ipad);
    innerData.set(message, blockSize);
    const innerHash = this.sha1Sync(innerData);
    
    const outerData = new Uint8Array(blockSize + innerHash.length);
    outerData.set(opad);
    outerData.set(innerHash, blockSize);
    
    return this.sha1Sync(outerData);
  }

  /**
   * HMAC-SHA256 implementation
   */
  static hmacSha256Sync(secret, counter) {
    const key = this.base32Decode(secret);
    const message = this.counterToBytes(counter);
    
    const blockSize = 64;
    let keyBytes = key;
    
    if (keyBytes.length > blockSize) {
      keyBytes = this.sha256Sync(keyBytes);
    }
    
    const paddedKey = new Uint8Array(blockSize);
    paddedKey.set(keyBytes);
    
    const ipad = new Uint8Array(blockSize);
    const opad = new Uint8Array(blockSize);
    
    for (let i = 0; i < blockSize; i++) {
      ipad[i] = paddedKey[i] ^ 0x36;
      opad[i] = paddedKey[i] ^ 0x5c;
    }
    
    const innerData = new Uint8Array(blockSize + message.length);
    innerData.set(ipad);
    innerData.set(message, blockSize);
    const innerHash = this.sha256Sync(innerData);
    
    const outerData = new Uint8Array(blockSize + innerHash.length);
    outerData.set(opad);
    outerData.set(innerHash, blockSize);
    
    return this.sha256Sync(outerData);
  }

  /**
   * HMAC-SHA512 implementation
   */
  static hmacSha512Sync(secret, counter) {
    const key = this.base32Decode(secret);
    const message = this.counterToBytes(counter);
    
    const blockSize = 128; // SHA-512 uses 128-byte blocks
    let keyBytes = key;
    
    if (keyBytes.length > blockSize) {
      keyBytes = this.sha512Sync(keyBytes);
    }
    
    const paddedKey = new Uint8Array(blockSize);
    paddedKey.set(keyBytes);
    
    const ipad = new Uint8Array(blockSize);
    const opad = new Uint8Array(blockSize);
    
    for (let i = 0; i < blockSize; i++) {
      ipad[i] = paddedKey[i] ^ 0x36;
      opad[i] = paddedKey[i] ^ 0x5c;
    }
    
    const innerData = new Uint8Array(blockSize + message.length);
    innerData.set(ipad);
    innerData.set(message, blockSize);
    const innerHash = this.sha512Sync(innerData);
    
    const outerData = new Uint8Array(blockSize + innerHash.length);
    outerData.set(opad);
    outerData.set(innerHash, blockSize);
    
    return this.sha512Sync(outerData);
  }

  /**
   * Convert counter to 8-byte big-endian array
   */
  static counterToBytes(counter) {
    const buffer = new Uint8Array(8);
    const view = new DataView(buffer.buffer);
    // Big-endian 64-bit integer
    view.setUint32(0, Math.floor(counter / 0x100000000), false);
    view.setUint32(4, counter >>> 0, false);
    return buffer;
  }

  /**
   * SHA-1 implementation
   */
  static sha1Sync(data) {
    let h0 = 0x67452301;
    let h1 = 0xEFCDAB89;
    let h2 = 0x98BADCFE;
    let h3 = 0x10325476;
    let h4 = 0xC3D2E1F0;

    const ml = data.length * 8;
    const paddedLen = Math.ceil((data.length + 9) / 64) * 64;
    const padded = new Uint8Array(paddedLen);
    padded.set(data);
    padded[data.length] = 0x80;
    
    const view = new DataView(padded.buffer);
    view.setUint32(paddedLen - 8, Math.floor(ml / 0x100000000), false);
    view.setUint32(paddedLen - 4, ml >>> 0, false);

    for (let offset = 0; offset < paddedLen; offset += 64) {
      const w = new Uint32Array(80);
      
      for (let i = 0; i < 16; i++) {
        w[i] = view.getUint32(offset + i * 4, false);
      }
      
      for (let i = 16; i < 80; i++) {
        const temp = w[i-3] ^ w[i-8] ^ w[i-14] ^ w[i-16];
        w[i] = (temp << 1) | (temp >>> 31);
      }

      let a = h0, b = h1, c = h2, d = h3, e = h4;

      for (let i = 0; i < 80; i++) {
        let f, k;
        if (i < 20) {
          f = (b & c) | ((~b) & d);
          k = 0x5A827999;
        } else if (i < 40) {
          f = b ^ c ^ d;
          k = 0x6ED9EBA1;
        } else if (i < 60) {
          f = (b & c) | (b & d) | (c & d);
          k = 0x8F1BBCDC;
        } else {
          f = b ^ c ^ d;
          k = 0xCA62C1D6;
        }

        const temp = (((a << 5) | (a >>> 27)) + f + e + k + w[i]) >>> 0;
        e = d;
        d = c;
        c = ((b << 30) | (b >>> 2)) >>> 0;
        b = a;
        a = temp;
      }

      h0 = (h0 + a) >>> 0;
      h1 = (h1 + b) >>> 0;
      h2 = (h2 + c) >>> 0;
      h3 = (h3 + d) >>> 0;
      h4 = (h4 + e) >>> 0;
    }

    const hash = new Uint8Array(20);
    const hashView = new DataView(hash.buffer);
    hashView.setUint32(0, h0, false);
    hashView.setUint32(4, h1, false);
    hashView.setUint32(8, h2, false);
    hashView.setUint32(12, h3, false);
    hashView.setUint32(16, h4, false);
    
    return hash;
  }

  /**
   * SHA-256 implementation
   */
  static sha256Sync(data) {
    const K = [
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
      0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
      0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
      0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
      0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
      0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ];

    let h0 = 0x6a09e667, h1 = 0xbb67ae85, h2 = 0x3c6ef372, h3 = 0xa54ff53a;
    let h4 = 0x510e527f, h5 = 0x9b05688c, h6 = 0x1f83d9ab, h7 = 0x5be0cd19;

    const ml = data.length * 8;
    const paddedLen = Math.ceil((data.length + 9) / 64) * 64;
    const padded = new Uint8Array(paddedLen);
    padded.set(data);
    padded[data.length] = 0x80;
    
    const view = new DataView(padded.buffer);
    view.setUint32(paddedLen - 8, Math.floor(ml / 0x100000000), false);
    view.setUint32(paddedLen - 4, ml >>> 0, false);

    for (let offset = 0; offset < paddedLen; offset += 64) {
      const w = new Uint32Array(64);
      
      for (let i = 0; i < 16; i++) {
        w[i] = view.getUint32(offset + i * 4, false);
      }
      
      for (let i = 16; i < 64; i++) {
        const s0 = this.rotr(w[i-15], 7) ^ this.rotr(w[i-15], 18) ^ (w[i-15] >>> 3);
        const s1 = this.rotr(w[i-2], 17) ^ this.rotr(w[i-2], 19) ^ (w[i-2] >>> 10);
        w[i] = (w[i-16] + s0 + w[i-7] + s1) >>> 0;
      }

      let a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;

      for (let i = 0; i < 64; i++) {
        const S1 = this.rotr(e, 6) ^ this.rotr(e, 11) ^ this.rotr(e, 25);
        const ch = (e & f) ^ ((~e) & g);
        const temp1 = (h + S1 + ch + K[i] + w[i]) >>> 0;
        const S0 = this.rotr(a, 2) ^ this.rotr(a, 13) ^ this.rotr(a, 22);
        const maj = (a & b) ^ (a & c) ^ (b & c);
        const temp2 = (S0 + maj) >>> 0;

        h = g; g = f; f = e;
        e = (d + temp1) >>> 0;
        d = c; c = b; b = a;
        a = (temp1 + temp2) >>> 0;
      }

      h0 = (h0 + a) >>> 0; h1 = (h1 + b) >>> 0; h2 = (h2 + c) >>> 0; h3 = (h3 + d) >>> 0;
      h4 = (h4 + e) >>> 0; h5 = (h5 + f) >>> 0; h6 = (h6 + g) >>> 0; h7 = (h7 + h) >>> 0;
    }

    const hash = new Uint8Array(32);
    const hashView = new DataView(hash.buffer);
    hashView.setUint32(0, h0, false);
    hashView.setUint32(4, h1, false);
    hashView.setUint32(8, h2, false);
    hashView.setUint32(12, h3, false);
    hashView.setUint32(16, h4, false);
    hashView.setUint32(20, h5, false);
    hashView.setUint32(24, h6, false);
    hashView.setUint32(28, h7, false);
    
    return hash;
  }

  /**
   * SHA-512 implementation (using 64-bit operations via two 32-bit integers)
   */
  static sha512Sync(data) {
    const K = [
      [0x428a2f98, 0xd728ae22], [0x71374491, 0x23ef65cd], [0xb5c0fbcf, 0xec4d3b2f], [0xe9b5dba5, 0x8189dbbc],
      [0x3956c25b, 0xf348b538], [0x59f111f1, 0xb605d019], [0x923f82a4, 0xaf194f9b], [0xab1c5ed5, 0xda6d8118],
      [0xd807aa98, 0xa3030242], [0x12835b01, 0x45706fbe], [0x243185be, 0x4ee4b28c], [0x550c7dc3, 0xd5ffb4e2],
      [0x72be5d74, 0xf27b896f], [0x80deb1fe, 0x3b1696b1], [0x9bdc06a7, 0x25c71235], [0xc19bf174, 0xcf692694],
      [0xe49b69c1, 0x9ef14ad2], [0xefbe4786, 0x384f25e3], [0x0fc19dc6, 0x8b8cd5b5], [0x240ca1cc, 0x77ac9c65],
      [0x2de92c6f, 0x592b0275], [0x4a7484aa, 0x6ea6e483], [0x5cb0a9dc, 0xbd41fbd4], [0x76f988da, 0x831153b5],
      [0x983e5152, 0xee66dfab], [0xa831c66d, 0x2db43210], [0xb00327c8, 0x98fb213f], [0xbf597fc7, 0xbeef0ee4],
      [0xc6e00bf3, 0x3da88fc2], [0xd5a79147, 0x930aa725], [0x06ca6351, 0xe003826f], [0x14292967, 0x0a0e6e70],
      [0x27b70a85, 0x46d22ffc], [0x2e1b2138, 0x5c26c926], [0x4d2c6dfc, 0x5ac42aed], [0x53380d13, 0x9d95b3df],
      [0x650a7354, 0x8baf63de], [0x766a0abb, 0x3c77b2a8], [0x81c2c92e, 0x47edaee6], [0x92722c85, 0x1482353b],
      [0xa2bfe8a1, 0x4cf10364], [0xa81a664b, 0xbc423001], [0xc24b8b70, 0xd0f89791], [0xc76c51a3, 0x0654be30],
      [0xd192e819, 0xd6ef5218], [0xd6990624, 0x5565a910], [0xf40e3585, 0x5771202a], [0x106aa070, 0x32bbd1b8],
      [0x19a4c116, 0xb8d2d0c8], [0x1e376c08, 0x5141ab53], [0x2748774c, 0xdf8eeb99], [0x34b0bcb5, 0xe19b48a8],
      [0x391c0cb3, 0xc5c95a63], [0x4ed8aa4a, 0xe3418acb], [0x5b9cca4f, 0x7763e373], [0x682e6ff3, 0xd6b2b8a3],
      [0x748f82ee, 0x5defb2fc], [0x78a5636f, 0x43172f60], [0x84c87814, 0xa1f0ab72], [0x8cc70208, 0x1a6439ec],
      [0x90befffa, 0x23631e28], [0xa4506ceb, 0xde82bde9], [0xbef9a3f7, 0xb2c67915], [0xc67178f2, 0xe372532b],
      [0xca273ece, 0xea26619c], [0xd186b8c7, 0x21c0c207], [0xeada7dd6, 0xcde0eb1e], [0xf57d4f7f, 0xee6ed178],
      [0x06f067aa, 0x72176fba], [0x0a637dc5, 0xa2c898a6], [0x113f9804, 0xbef90dae], [0x1b710b35, 0x131c471b],
      [0x28db77f5, 0x23047d84], [0x32caab7b, 0x40c72493], [0x3c9ebe0a, 0x15c9bebc], [0x431d67c4, 0x9c100d4c],
      [0x4cc5d4be, 0xcb3e42b6], [0x597f299c, 0xfc657e2a], [0x5fcb6fab, 0x3ad6faec], [0x6c44198c, 0x4a475817]
    ];

    let h = [
      [0x6a09e667, 0xf3bcc908], [0xbb67ae85, 0x84caa73b], [0x3c6ef372, 0xfe94f82b], [0xa54ff53a, 0x5f1d36f1],
      [0x510e527f, 0xade682d1], [0x9b05688c, 0x2b3e6c1f], [0x1f83d9ab, 0xfb41bd6b], [0x5be0cd19, 0x137e2179]
    ];

    const ml = data.length * 8;
    const paddedLen = Math.ceil((data.length + 17) / 128) * 128;
    const padded = new Uint8Array(paddedLen);
    padded.set(data);
    padded[data.length] = 0x80;
    
    const view = new DataView(padded.buffer);
    view.setUint32(paddedLen - 16, 0, false);
    view.setUint32(paddedLen - 12, 0, false);
    view.setUint32(paddedLen - 8, Math.floor(ml / 0x100000000), false);
    view.setUint32(paddedLen - 4, ml >>> 0, false);

    for (let offset = 0; offset < paddedLen; offset += 128) {
      const w = Array(80).fill(0).map(() => [0, 0]);
      
      for (let i = 0; i < 16; i++) {
        w[i][0] = view.getUint32(offset + i * 8, false);
        w[i][1] = view.getUint32(offset + i * 8 + 4, false);
      }
      
      for (let i = 16; i < 80; i++) {
        const s0 = this.xor64(this.xor64(this.rotr64(w[i-15], 1), this.rotr64(w[i-15], 8)), this.shr64(w[i-15], 7));
        const s1 = this.xor64(this.xor64(this.rotr64(w[i-2], 19), this.rotr64(w[i-2], 61)), this.shr64(w[i-2], 6));
        w[i] = this.add64(this.add64(this.add64(w[i-16], s0), w[i-7]), s1);
      }

      let [a, b, c, d, e, f, g, hh] = h.map(x => [...x]);

      for (let i = 0; i < 80; i++) {
        const S1 = this.xor64(this.xor64(this.rotr64(e, 14), this.rotr64(e, 18)), this.rotr64(e, 41));
        const ch = this.xor64(this.and64(e, f), this.and64(this.not64(e), g));
        const temp1 = this.add64(this.add64(this.add64(this.add64(hh, S1), ch), K[i]), w[i]);
        const S0 = this.xor64(this.xor64(this.rotr64(a, 28), this.rotr64(a, 34)), this.rotr64(a, 39));
        const maj = this.xor64(this.xor64(this.and64(a, b), this.and64(a, c)), this.and64(b, c));
        const temp2 = this.add64(S0, maj);

        hh = g; g = f; f = e;
        e = this.add64(d, temp1);
        d = c; c = b; b = a;
        a = this.add64(temp1, temp2);
      }

      h[0] = this.add64(h[0], a); h[1] = this.add64(h[1], b); h[2] = this.add64(h[2], c); h[3] = this.add64(h[3], d);
      h[4] = this.add64(h[4], e); h[5] = this.add64(h[5], f); h[6] = this.add64(h[6], g); h[7] = this.add64(h[7], hh);
    }

    const hash = new Uint8Array(64);
    const hashView = new DataView(hash.buffer);
    for (let i = 0; i < 8; i++) {
      hashView.setUint32(i * 8, h[i][0], false);
      hashView.setUint32(i * 8 + 4, h[i][1], false);
    }
    
    return hash;
  }

  // Helper for SHA-256
  static rotr(n, b) {
    return (n >>> b) | (n << (32 - b));
  }

  // Helpers for SHA-512 (64-bit ops using [hi, lo] pairs)
  static rotr64(n, b) {
    if (b === 0) return n;
    if (b < 32) {
      return [(n[0] >>> b) | (n[1] << (32 - b)), (n[1] >>> b) | (n[0] << (32 - b))];
    }
    b -= 32;
    return [(n[1] >>> b) | (n[0] << (32 - b)), (n[0] >>> b) | (n[1] << (32 - b))];
  }

  static shr64(n, b) {
    if (b === 0) return n;
    if (b < 32) return [(n[0] >>> b) | (n[1] << (32 - b)), n[1] >>> b];
    return [n[1] >>> (b - 32), 0];
  }

  static add64(...nums) {
    let lo = 0, hi = 0;
    for (const n of nums) {
      const newLo = (lo + n[1]) >>> 0;
      hi = (hi + n[0] + (newLo < lo ? 1 : 0)) >>> 0;
      lo = newLo;
    }
    return [hi, lo];
  }

  static xor64(a, b) {
    return [a[0] ^ b[0], a[1] ^ b[1]];
  }

  static and64(a, b) {
    return [a[0] & b[0], a[1] & b[1]];
  }

  static not64(a) {
    return [~a[0] >>> 0, ~a[1] >>> 0];
  }

  /**
   * Dynamic truncation per RFC 6238
   */
  static dynamicTruncate(hmac, digits) {
    const offset = hmac[hmac.length - 1] & 0x0f;
    const code = ((hmac[offset] & 0x7f) << 24) |
                 ((hmac[offset + 1] & 0xff) << 16) |
                 ((hmac[offset + 2] & 0xff) << 8) |
                 (hmac[offset + 3] & 0xff);
    return (code % Math.pow(10, digits)).toString();
  }

  /**
   * Base32 decoder (RFC 4648)
   */
  static base32Decode(base32) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    // Clean input: uppercase, remove padding, remove spaces/dashes
    base32 = base32.toUpperCase().replace(/[=\s-]/g, '');
    
    let bits = '';
    for (let i = 0; i < base32.length; i++) {
      const val = alphabet.indexOf(base32[i]);
      if (val === -1) {
        console.warn(`Invalid base32 character '${base32[i]}' at position ${i}`);
        continue; // Skip invalid characters
      }
      bits += val.toString(2).padStart(5, '0');
    }
    
    const bytes = [];
    for (let i = 0; i + 8 <= bits.length; i += 8) {
      bytes.push(parseInt(bits.substring(i, i + 8), 2));
    }
    
    return new Uint8Array(bytes);
  }

  /**
   * Get remaining seconds in current period
   */
  static getRemainingSeconds(period = 30) {
    const now = Math.floor(Date.now() / 1000);
    return period - (now % period);
  }
}
