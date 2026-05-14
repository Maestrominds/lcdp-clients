<script>
    import Sidebar from "$lib/components/shared/Sidebar.svelte";
    import TopBar from "$lib/components/shared/TopBar.svelte";
    import { goto } from "$app/navigation";
    import { page } from "$app/state";
    import { isAuthenticated, logout, userProfile } from "$lib/stores/auth.js";
    import { onDestroy } from "svelte";
    import { api } from "$lib/api.js";

    let { children } = $props();

    let user = $state({});
    const unsubscribeUser = userProfile.subscribe((v) => (user = v));

    let isAuthed = $state(false);
    const unsubscribeAuth = isAuthenticated.subscribe((value) => {
        isAuthed = value;
    });
    onDestroy(() => {
        unsubscribeAuth();
        unsubscribeUser();
    });

    const ALERTS_REFRESH_MS = 60000;
    let alerts = $state([]);
    let alertsLoading = $state(false);
    let lastAlertsFetch = $state(0);
    const loadAlerts = async () => {
        const now = Date.now();
        if (lastAlertsFetch > 0) return;
        alertsLoading = true;
        lastAlertsFetch = now;
        try {
            alerts = (await api.getAlerts()) || [];
        } catch (e) {
            if (e?.message === "Unauthorized") logout();
            console.error("Failed to load alerts:", e);
        } finally {
            alertsLoading = false;
        }
    };

    const navItems = [
        {
            id: "overview",
            label: "Overview",
            path: "/owner/overview",
            icon: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></svg>',
        },
        {
            id: "revenue",
            label: "Revenue",
            path: "/owner/revenue",
            icon: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>',
        },
        {
            id: "sales",
            label: "Sales Performance",
            path: "/owner/sales-performance",
            icon: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 3v18h18"/><path d="m19 9-5 5-4-4-3 3"/></svg>',
        },
        {
            id: "inv-insights",
            label: "Inventory Insights",
            path: "/owner/inventory-insights",
            icon: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/></svg>',
        },
        {
            id: "reports",
            label: "Reports",
            path: "/owner/reports",
            icon: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>',
        },
        {
            id: "alerts",
            label: "Alerts",
            path: "/owner/alerts",
            icon: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>',
        },
        { divider: true },
        {
            id: "signout",
            label: "Sign Out",
            path: "/owner/login",
            icon: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>',
        },
    ];

    const currentPath = $derived(page.url?.pathname || "");
    const activeItem = $derived(
        navItems.find((n) => n.path && currentPath.startsWith(n.path))?.id ||
            "overview",
    );
    const isLoginPage = $derived(currentPath === "/owner/login");
    const pageTitle = $derived(
        navItems.find((n) => n.id === activeItem)?.label || "Overview",
    );

    $effect(() => {
        if (!isAuthed || isLoginPage) {
            lastAlertsFetch = 0;
            return;
        }
        loadAlerts();
    });

    function handleNavigate(id, path) {
        if (id === "signout") {
            logout();
            goto("/owner/login");
        } else goto(path);
    }

    const initials = $derived(() => {
        if (!user.name) return "OW";
        return user.name
            .split(" ")
            .map((n) => n[0])
            .join("")
            .toUpperCase()
            .slice(0, 2);
    });
</script>

{#if isLoginPage}
    {@render children()}
{:else}
    <div class="owner-layout">
        <Sidebar
            items={navItems}
            {activeItem}
            role="owner"
            onNavigate={handleNavigate}
        />
        <div class="main-area">
            <TopBar
                title={pageTitle}
                notificationCount={alerts.length}
                onNotifications={() => goto("/owner/alerts")}
                userName={user.name || "Owner"}
                avatarInitials={initials()}
            />
            <main class="content">{@render children()}</main>
        </div>
    </div>
{/if}

<style>
    .owner-layout {
        display: flex;
        min-height: 100vh;
    }
    .main-area {
        margin-left: var(--sidebar-width, 220px);
        flex: 1;
        display: flex;
        flex-direction: column;
    }
    .content {
        flex: 1;
        padding: 24px 32px;
        overflow-y: auto;
    }
</style>
