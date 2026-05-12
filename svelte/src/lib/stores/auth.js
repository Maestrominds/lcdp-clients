import { writable } from 'svelte/store';
import { browser } from '$app/environment';

// Since we use HTTP-only cookies, we can't check the cookie directly from JS.
// We'll use a simple "cdp_logged_in" flag in localStorage to track UI state.
export const isAuthenticated = writable(
  browser && localStorage.getItem('cdp_logged_in') === 'true'
);

export const userProfile = writable(
  browser ? JSON.parse(localStorage.getItem('cdp_user_profile') || '{}') : {}
);

export function login(userData) {
  if (browser) {
    localStorage.setItem('cdp_logged_in', 'true');
    if (userData) {
      localStorage.setItem('cdp_user_profile', JSON.stringify(userData));
      userProfile.set(userData);
    }
  }
  isAuthenticated.set(true);
}

export function logout() {
  if (browser) {
    localStorage.removeItem('cdp_logged_in');
    localStorage.removeItem('cdp_user_profile');
  }
  isAuthenticated.set(false);
  userProfile.set({});
}

// Legacy compat export
export const auth = { login, logout, restore: () => {} };
