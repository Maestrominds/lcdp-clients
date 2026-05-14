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
            id: "dashboard",
            label: "Dashboard",
            path: "/manager/dashboard",
            icon: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></svg>',
        },
        {
            id: "dishes",
            label: "Dishes Management",
            path: "/manager/dishes",
            icon: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>',
        },
        {
            id: "inventory",
            label: "Inventory",
            path: "/manager/inventory",
            icon: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><polyline points="3.3 7 12 12 20.7 7"/><line x1="12" y1="22" x2="12" y2="12"/></svg>',
        },
        {
            id: "tables",
            label: "Tables & Staff",
            path: "/manager/tables",
            icon: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="7" width="20" height="4" rx="1"/><path d="M4 11v8"/><path d="M20 11v8"/><path d="M12 7V3"/></svg>',
        },
        {
            id: "scan-bills",
            label: "Scan Bills",
            path: "/manager/scan-bills",
            icon: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z"/><circle cx="12" cy="13" r="3"/></svg>',
        },
        {
            id: "payables",
            label: "Payables",
            path: "/manager/payables",
            icon: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="1" y="4" width="22" height="16" rx="2"/><line x1="1" y1="10" x2="23" y2="10"/></svg>',
        },
        {
            id: "alerts",
            label: "Alerts",
            path: "/manager/alerts",
            icon: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>',
        },
        {
            id: "vendors",
            label: "Vendors",
            path: "/manager/vendors",
            icon: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>',
        },
        { divider: true },
        {
            id: "signout",
            label: "Sign Out",
            path: "/manager/login",
            icon: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>',
        },
    ];

    const currentPath = $derived(page.url?.pathname || "");
    const activeItem = $derived(
        navItems.find((n) => n.path && currentPath.startsWith(n.path))?.id ||
            "dashboard",
    );
    const isLoginPage = $derived(currentPath === "/manager/login");
    const pageTitle = $derived(
        navItems.find((n) => n.id === activeItem)?.label || "Dashboard",
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
            goto("/manager/login");
        } else goto(path);
    }

    const initials = $derived(() => {
        if (!user.name) return "MG";
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
    <div class="manager-layout">
        <Sidebar
            items={navItems}
            {activeItem}
            role="manager"
            onNavigate={handleNavigate}
        />
        <div class="main-area">
            <TopBar
                title={pageTitle}
                showScanBtn={true}
                onScan={() => goto("/manager/scan-bills")}
                notificationCount={alerts.length}
                onNotifications={() => goto("/manager/alerts")}
                userName={user.name || "Manager"}
                avatarInitials={initials()}
            />
            <main class="content">{@render children()}</main>
        </div>
    </div>
{/if}

<style>
    .manager-layout {
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
