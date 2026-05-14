import { writable } from 'svelte/store';
import { browser } from '$app/environment';

export const isAuthenticated = writable(false);

export const userProfile = writable({});

export function login(userData) {
  isAuthenticated.set(true);
  if (userData) {
    userProfile.set(userData);
  }
}

export function logout() {
  isAuthenticated.set(false);
  userProfile.set({});
}

// Legacy compat export
export const auth = { login, logout, restore: () => {} };
