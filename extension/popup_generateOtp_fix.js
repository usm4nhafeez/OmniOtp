  // Asynchronously generate OTP for an account (uses Web Crypto when needed)
  async generateOtp(account) {
    try {
      // Log account details for debugging
      console.log('Generating OTP for account:', {
        id: account.id,
        issuer: account.issuer,
        accountName: account.accountName,
        algorithm: account.algorithm,
        digits: account.digits,
        period: account.period,
        secretLength: account.secret?.length
      });
      
      // Ensure algorithm is properly set
      const normalizedAccount = {
        ...account,
        algorithm: (account.algorithm || 'SHA1').toUpperCase().trim(),
        digits: account.digits || 6,
        period: account.period || 30
      };
      
      return TotpService.generateCode(normalizedAccount);
    } catch (e) {
      console.error('Failed to generate OTP:', e, account);
      throw e;
    }
  }
