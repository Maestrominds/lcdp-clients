<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { browser } from '$app/environment';

  let { children } = $props();

  onMount(() => {
    if (browser) {
      const currentPath = window.location.pathname;
      const isLoginPage = currentPath.endsWith('/kitchen/login');

      if (!isLoginPage) {
        const loggedIn = localStorage.getItem('kitchen_logged_in') === 'true';
        if (!loggedIn) {
          goto('/kitchen/login');
        }
      }
    }
  });
</script>

{@render children()}
