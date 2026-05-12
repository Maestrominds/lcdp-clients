<script>
  import { goto } from '$app/navigation';
  import { api } from '$lib/api.js';

  let phone = $state('');
  let otp = $state('');
  let step = $state('phone'); // 'phone' | 'otp'
  let loading = $state(false);
  let error = $state('');
  let otpStatus = $state(''); // 'sent' | 'otp_unavailable'

  const ROLE = 'waiter';

  async function requestOTP() {
    const cleaned = phone.trim().replace(/\s/g, '');
    if (!cleaned) { error = 'Please enter your phone number'; return; }
    loading = true; error = '';
    try {
      const res = await api.kitchenRequestOTP(cleaned, ROLE);
      otpStatus = res?.status ?? 'sent';
      step = 'otp';
    } catch (e) {
      error = 'Kitchen access denied. Please ensure your number is registered as Kitchen Staff.';
    } finally {
      loading = false;
    }
  }

  async function verifyOTP() {
    const cleaned = phone.trim().replace(/\s/g, '');
    if (!otp.trim()) { error = 'Please enter the 6-digit OTP'; return; }
    loading = true; error = '';
    try {
      await api.kitchenVerifyOTP(cleaned, otp.trim());
      goto('/kitchen/display');
    } catch (e) {
      error = 'Invalid or expired OTP. Please try again.';
    } finally {
      loading = false;
    }
  }

  function handlePhoneKey(e) { if (e.key === 'Enter') requestOTP(); }
  function handleOTPKey(e)   { if (e.key === 'Enter') verifyOTP(); }
  function goBack() { step = 'phone'; otp = ''; error = ''; }
</script>

<svelte:head>
  <title>Kitchen Login — Cafe De Paris</title>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800&display=swap" rel="stylesheet">
</svelte:head>

<div class="login-page">
  <div class="login-left">
    <div class="brand-showcase">
      <div class="logo-box">
        <img src="/app_icon.png" alt="App Icon" />
      </div>
      <h1 class="brand-name">Cafe De Paris</h1>
      <p class="brand-tagline">Kitchen Display System</p>
      
      <div class="visual-features">
        <div class="v-feature">
          <div class="v-dot"></div>
          <span>Real-time Order Processing</span>
        </div>
        <div class="v-feature">
          <div class="v-dot"></div>
          <span>Live Order Timers</span>
        </div>
        <div class="v-feature">
          <div class="v-dot"></div>
          <span>Instant Status Updates</span>
        </div>
      </div>
    </div>
  </div>

  <div class="login-right">
    <div class="auth-card">
      {#if step === 'phone'}
        <div class="auth-header">
          <div class="portal-badge">KITCHEN ACCESS</div>
          <h2>Staff Login</h2>
          <p>Access the kitchen display board</p>
        </div>

        {#if error}
          <div class="error-msg">{error}</div>
        {/if}

        <div class="field-group">
          <label for="phone">Phone Number</label>
          <div class="input-wrapper">
            <span class="prefix">+91</span>
            <input 
              id="phone"
              type="tel" 
              bind:value={phone} 
              placeholder="98765 43210" 
              onkeydown={handlePhoneKey}
              autofocus 
            />
          </div>
        </div>

        <button class="primary-btn" onclick={requestOTP} disabled={loading}>
          {#if loading}
            <span class="loader"></span> Sending...
          {:else}
            Access Kitchen →
          {/if}
        </button>
      {:else}
        <div class="auth-header">
          <button class="mini-back" onclick={goBack}>← Change Number</button>
          <h2>Verify Code</h2>
          <p>Enter the 6-digit OTP sent to <strong>+91 {phone}</strong></p>
        </div>

        {#if error}
          <div class="error-msg">{error}</div>
        {/if}

        <div class="field-group">
          <label for="otp">One-Time Password</label>
          <input 
            id="otp"
            type="text" 
            inputmode="numeric"
            maxlength="6"
            bind:value={otp} 
            placeholder="000000" 
            class="otp-input"
            onkeydown={handleOTPKey}
            autofocus 
          />
          {#if otpStatus === 'otp_unavailable'}
            <p class="otp-hint">Debug Mode: Enter any code to continue</p>
          {/if}
        </div>

        <button class="primary-btn" onclick={verifyOTP} disabled={loading}>
          {#if loading}
            <span class="loader"></span> Verifying...
          {:else}
            Verify & Open Board
          {/if}
        </button>
      {/if}
      
      <p class="safety-note">Kitchen session expires in 24 hours.</p>
    </div>
  </div>
</div>

<style>
  :global(body) {
    margin: 0; padding: 0;
    font-family: 'Outfit', sans-serif;
    background: #f8fafc;
    color: #0f172a;
  }

  .login-page {
    display: flex;
    min-height: 100vh;
  }

  /* ── LEFT SIDE ── */
  .login-left {
    flex: 0 0 45%;
    background: #1e5f74;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 3rem;
    position: relative;
    overflow: hidden;
  }
  .login-left::before {
    content: '';
    position: absolute;
    inset: 0;
    background: radial-gradient(circle at 70% 30%, rgba(201,168,76,0.15), transparent 70%);
  }

  .brand-showcase {
    position: relative;
    z-index: 1;
    color: #fff;
    max-width: 400px;
  }

  .logo-box {
    width: 64px; height: 64px;
    background: #fff;
    border-radius: 16px;
    padding: 12px;
    margin-bottom: 2rem;
    display: flex; align-items: center; justify-content: center;
  }
  .logo-box img { width: 100%; height: 100%; object-fit: contain; }

  .brand-name { font-size: 2.5rem; font-weight: 800; margin: 0; letter-spacing: -0.5px; }
  .brand-tagline { font-size: 1.125rem; color: rgba(255,255,255,0.7); margin: 0.5rem 0 3rem; font-weight: 500; }

  .visual-features { display: flex; flex-direction: column; gap: 1.5rem; }
  .v-feature { display: flex; align-items: center; gap: 1rem; font-size: 0.95rem; color: rgba(255,255,255,0.9); }
  .v-dot { width: 8px; height: 8px; background: #c9a84c; border-radius: 50%; }

  /* ── RIGHT SIDE ── */
  .login-right {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 2rem;
    background: #f8fafc;
  }

  .auth-card {
    width: 100%;
    max-width: 420px;
    padding: 3rem;
    background: #fff;
    border-radius: 24px;
    box-shadow: 0 20px 50px rgba(0,0,0,0.05);
    border: 1px solid #e2e8f0;
  }

  .auth-header { margin-bottom: 2.5rem; text-align: center; position: relative; }
  .portal-badge {
    display: inline-block;
    background: rgba(30,95,116,0.1);
    color: #1e5f74;
    padding: 4px 12px;
    border-radius: 99px;
    font-size: 0.75rem;
    font-weight: 700;
    margin-bottom: 1rem;
    letter-spacing: 0.5px;
  }
  .auth-header h2 { font-size: 1.75rem; font-weight: 800; margin: 0 0 0.5rem; color: #0f172a; }
  .auth-header p { font-size: 0.95rem; color: #64748b; margin: 0; line-height: 1.5; }
  .auth-header p strong { color: #1e5f74; font-weight: 600; }

  .mini-back {
    background: none; border: none; color: #1e5f74; font-size: 0.85rem; font-weight: 600;
    cursor: pointer; margin-bottom: 1.5rem; padding: 0; opacity: 0.7; transition: 0.2s;
  }
  .mini-back:hover { opacity: 1; }

  .error-msg {
    background: #fef2f2; border: 1px solid #fee2e2; color: #991b1b;
    padding: 1rem; border-radius: 12px; font-size: 0.875rem; margin-bottom: 1.5rem;
    line-height: 1.4;
  }

  .field-group { margin-bottom: 1.5rem; }
  .field-group label { display: block; font-size: 0.85rem; font-weight: 700; color: #475569; margin-bottom: 0.5rem; }

  .input-wrapper {
    display: flex; align-items: center; gap: 0.75rem;
    background: #f1f5f9; border: 1.5px solid #e2e8f0; border-radius: 12px;
    padding: 0 1rem; transition: all 0.2s;
  }
  .input-wrapper:focus-within { border-color: #1e5f74; background: #fff; box-shadow: 0 0 0 4px rgba(30,95,116,0.1); }
  .prefix { font-weight: 700; color: #64748b; font-size: 0.95rem; }

  input {
    width: 100%; padding: 1rem 0; border: none; background: transparent;
    font-family: inherit; font-size: 1rem; font-weight: 600; color: #0f172a; outline: none;
  }
  input::placeholder { color: #94a3b8; font-weight: 400; }

  .otp-input {
    background: #f1f5f9; border: 1.5px solid #e2e8f0; border-radius: 12px;
    padding: 1rem; text-align: center; letter-spacing: 0.5rem; font-size: 1.5rem;
    font-weight: 800; color: #1e5f74;
  }
  .otp-input:focus { border-color: #1e5f74; background: #fff; box-shadow: 0 0 0 4px rgba(30,95,116,0.1); }
  .otp-hint { font-size: 0.75rem; color: #f59e0b; margin-top: 0.5rem; text-align: center; font-weight: 500; }

  .primary-btn {
    width: 100%; padding: 1rem; border-radius: 12px; border: none;
    background: #1e5f74; color: #fff; font-size: 1rem; font-weight: 700;
    cursor: pointer; transition: all 0.2s; box-shadow: 0 4px 12px rgba(30,95,116,0.2);
    display: flex; align-items: center; justify-content: center; gap: 0.75rem;
  }
  .primary-btn:hover:not(:disabled) { background: #164a5c; transform: translateY(-1px); box-shadow: 0 8px 20px rgba(30,95,116,0.3); }
  .primary-btn:disabled { opacity: 0.7; cursor: not-allowed; }

  .loader {
    width: 18px; height: 18px; border: 2.5px solid rgba(255,255,255,0.3);
    border-top-color: #fff; border-radius: 50%; animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  .safety-note { text-align: center; font-size: 0.75rem; color: #94a3b8; margin-top: 2rem; }

  @media (max-width: 900px) {
    .login-left { display: none; }
  }
</style>
