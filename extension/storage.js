/**
 * Storage Service - Chrome Storage API wrapper
 * Stores encrypted account data locally
 */
export class StorageService {
  constructor() {
    this.ACCOUNTS_KEY = 'omniotp_accounts';
    this.USER_KEY = 'omniotp_user';
    this.SETTINGS_KEY = 'omniotp_settings';
  }

  /**
   * Get all accounts
   */
  async getAccounts() {
    const result = await chrome.storage.local.get(this.ACCOUNTS_KEY);
    return result[this.ACCOUNTS_KEY] || [];
  }

  /**
   * Add an account
   */
  async addAccount(account) {
    const accounts = await this.getAccounts();
    accounts.push(account);
    await chrome.storage.local.set({ [this.ACCOUNTS_KEY]: accounts });
  }

  /**
   * Delete an account
   */
  async deleteAccount(accountId) {
    const accounts = await this.getAccounts();
    const filtered = accounts.filter(a => a.id !== accountId);
    await chrome.storage.local.set({ [this.ACCOUNTS_KEY]: filtered });
  }

  /**
   * Clear all accounts
   */
  async clearAllAccounts() {
    await chrome.storage.local.set({ [this.ACCOUNTS_KEY]: [] });
  }

  /**
   * Check if has local data
   */
  async hasLocalData() {
    const accounts = await this.getAccounts();
    return accounts.length > 0;
  }

  /**
   * Get current user
   */
  async getCurrentUser() {
    const result = await chrome.storage.local.get(this.USER_KEY);
    return result[this.USER_KEY] || null;
  }

  /**
   * Set current user
   */
  async setCurrentUser(user) {
    if (user) {
      await chrome.storage.local.set({ [this.USER_KEY]: user });
    } else {
      await chrome.storage.local.remove(this.USER_KEY);
    }
  }

  /**
   * Get settings
   */
  async getSettings() {
    const result = await chrome.storage.local.get(this.SETTINGS_KEY);
    return result[this.SETTINGS_KEY] || {};
  }

  /**
   * Save settings
   */
  async saveSettings(settings) {
    await chrome.storage.local.set({ [this.SETTINGS_KEY]: settings });
  }
}
