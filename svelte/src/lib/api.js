/**
 * Cafe De Paris — API Abstraction Layer
 * All API calls go through this module.
 */

const BASE_URL = '/api';

const authHeaders = () => ({
  'Content-Type': 'application/json'
});

// Standard handler — redirects to login on 401 (for manager/owner pages)
const handle = async (res) => {
  if (res.status === 401) {
    if (typeof window !== 'undefined') window.location.href = '/manager/login';
    throw new Error('Unauthorized');
  }
  if (!res.ok) throw new Error(`${res.status}: ${await res.text()}`);
  const text = await res.text();
  return text ? JSON.parse(text) : null;
};

// Kitchen handler — does NOT redirect on 401, throws a typed error instead
const kitchenHandle = async (res) => {
  if (res.status === 401) {
    if (typeof window !== 'undefined') window.location.href = '/kitchen/login';
    const err = new Error('Unauthorized — redirecting to kitchen login');
    err.code = 'AUTH_REQUIRED';
    throw err;
  }
  if (!res.ok) throw new Error(`${res.status}: ${await res.text()}`);
  const text = await res.text();
  return text ? JSON.parse(text) : null;
};

const get      = (path) => fetch(`${BASE_URL}${path}`, { headers: authHeaders(), credentials: 'include' }).then(handle);
const post     = (path, body) => fetch(`${BASE_URL}${path}`, { method: 'POST',  headers: authHeaders(), body: JSON.stringify(body), credentials: 'include' }).then(handle);
const patch    = (path, body) => fetch(`${BASE_URL}${path}`, { method: 'PATCH', headers: authHeaders(), body: body ? JSON.stringify(body) : undefined, credentials: 'include' }).then(handle);
const del      = (path) => fetch(`${BASE_URL}${path}`, { method: 'DELETE', headers: authHeaders(), credentials: 'include' }).then(handle);
// Kitchen uses session cookie (staff logs in via /kitchen/login) but redirects to /kitchen/login on 401
const kitchenGet   = (path) => fetch(`${BASE_URL}${path}`, { headers: authHeaders(), credentials: 'include' }).then(kitchenHandle);
const kitchenPatch = (path, body) => fetch(`${BASE_URL}${path}`, { method: 'PATCH', headers: authHeaders(), body: body ? JSON.stringify(body) : undefined, credentials: 'include' }).then(kitchenHandle);
// Public (no-cookie) for OTP auth endpoints
const pub = (path, body) => fetch(`${BASE_URL}${path}`, { method: body ? 'POST' : 'GET', headers: authHeaders(), body: body ? JSON.stringify(body) : undefined }).then(async res => { if (!res.ok) throw new Error(`${res.status}: ${await res.text()}`); const t = await res.text(); return t ? JSON.parse(t) : null; });

export const api = {
  // Auth
  managerLogin:         (email, password) => post('/auth/manager/login', { email, password }),
  ownerLogin:           (email, password) => post('/auth/owner/login', { email, password }),
  logout:               () => { /* Browser handles cookies, but we could call a logout endpoint */ },

  // Tables (CRUD)
  getTables:            () => get('/dining-tables'),
  getTable:             (id) => get(`/dining-tables/${id}`),
  createTable:          (table) => post('/dining-tables', table),
  updateTable:          (id, data) => patch(`/dining-tables/${id}`, data),
  deleteTable:          (id) => del(`/dining-tables/${id}`),
  updateTableStatus:    (id, status) => patch(`/dining-tables/${id}/status`, { status }),

  // Menu
  getMenu:              (category) => get(`/menu-items${category ? '?category=' + category : ''}`),
  addDish:              (dish) => post('/menu-items', dish),
  updateDish:           (id, data) => patch(`/menu-items/${id}`, data),
  deleteDish:           (id) => del(`/menu-items/${id}`),

  // Orders
  getOrders:            () => get('/orders'),
  sendToKitchen:        (tableId, items) => post('/orders', { tableId, items }),
  markServed:           (id) => patch(`/orders/${encodeURIComponent(id)}/served`),

  // Inventory
  getInventory:         () => get('/inventory-items'),
  addInventoryItem:     (item) => post('/inventory-items', item),
  updateInventoryItem:  (id, data) => patch(`/inventory-items/${id}`, data),
  deleteInventoryItem:  (id) => del(`/inventory-items/${id}`),

  // Bills
  scanBill:             (imageBase64, mimeType) => post('/bills/scan', { image: imageBase64, mimeType }),
  confirmBill:          (billData) => post('/bills/confirm', billData),

  // Payables (Mapped to Bills in backend)
  getPayables:          () => get('/bills'),
  markPaid:             (id, billData) => patch(`/bills/${id}`, { ...billData, status: 'paid' }),

  // Vendors
  getVendors:           () => get('/vendors'),
  addVendor:            (vendor) => post('/vendors', vendor),
  updateVendor:         (id, data) => patch(`/vendors/${id}`, data),

  // Alerts
  getAlerts:            () => get('/alerts'),
  markAlertRead:        (id) => patch(`/alerts/${id}/read`),

  // Staff/Waiters (Mapped to /users in backend)
  getWaiters:           () => get('/users'),
  addWaiter:            (waiter) => post('/users', waiter),
  deleteWaiter:         (id) => del(`/users/${id}`),

  // Analytics (owner)
  getOverview:          (date) => get(`/analytics/overview${date ? '?date=' + date : ''}`),
  getRevenue:           (period) => get(`/analytics/revenue${period ? '?period=' + period : ''}`),
  getSales:             () => get('/analytics/sales'),
  getInventoryInsights: () => get('/analytics/inventory'),

  // Reports
  getReports:           () => get('/reports'),
  downloadReport:       (id) => get(`/reports/${id}/download`),

  // Kitchen Auth (uses existing /login & /login/verify — NO backend changes needed)
  kitchenRequestOTP: (phone, role) => {
    const params = new URLSearchParams({ phone, role });
    return fetch(`${BASE_URL}/login?${params}`, { headers: authHeaders() })
      .then(async res => { if (!res.ok) throw new Error(`${res.status}: ${await res.text()}`); return res.json(); });
  },
  kitchenVerifyOTP: (phone, otp) =>
    fetch(`${BASE_URL}/login/verify`, {
      method: 'POST', headers: authHeaders(),
      body: JSON.stringify({ phone, otp }),
      credentials: 'include'  // receive session cookie
    }).then(async res => {
      if (!res.ok) throw new Error(`${res.status}: ${await res.text()}`);
      localStorage.setItem('kitchen_logged_in', 'true');
      return res.json();
    }),
  kitchenLogout: () => {
    localStorage.removeItem('kitchen_logged_in');
    if (typeof window !== 'undefined') window.location.href = '/kitchen/login';
  },

  // Kitchen Display (protected by session cookie after login above)
  getKitchenOrders:     () => kitchenGet('/orders'),
  getKitchenTables:     () => kitchenGet('/dining-tables'),
  kitchenStartPreparing:(tableId) => kitchenPatch(`/dining-tables/${tableId}/status`, { status: 'preparing' }),
  kitchenMarkReady:     (tableId) => kitchenPatch(`/dining-tables/${tableId}/status`, { status: 'eating' }),

  // Settings & Actions
  updateProfile:        (data) => patch('/settings/profile', data),
  updateNotifications:  (data) => patch('/settings/notifications', data),
};
