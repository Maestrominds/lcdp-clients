<script>
    import { onMount, onDestroy } from "svelte";
    import { api } from "$lib/api.js";

    let orders = $state([]);
    let tables = $state([]);
    let loading = $state(true);
    let now = $state(Date.now());
    let connected = $state(false);
    let errorMsg = $state("");
    let pollInterval;
    let clockInterval;

    onMount(async () => {
        await fetchData();
        pollInterval = setInterval(fetchData, 3000);
        clockInterval = setInterval(() => (now = Date.now()), 1000);
    });

    onDestroy(() => {
        clearInterval(pollInterval);
        clearInterval(clockInterval);
    });

    async function fetchData() {
        try {
            const [ordersData, tablesData] = await Promise.all([
                api.getKitchenOrders(),
                api.getKitchenTables(),
            ]);
            orders = Array.isArray(ordersData) ? ordersData : [];
            tables = Array.isArray(tablesData) ? tablesData : [];
            connected = true;
            errorMsg = "";
        } catch (e) {
            connected = false;
            errorMsg = e.message || "Connection failed";
            // kitchenHandle will redirect to /kitchen/login on 401 automatically
        } finally {
            loading = false;
        }
    }

    let dismissedIds = $state([]);

    onMount(() => {
        try {
            const stored = localStorage.getItem("kitchen_dismissed_ids");
            if (stored) dismissedIds = JSON.parse(stored);
        } catch (e) {}

        fetchData();
        const interval = setInterval(fetchData, 3000);
        clockInterval = setInterval(() => (now = Date.now()), 1000);
        return () => {
            clearInterval(interval);
            clearInterval(clockInterval);
        };
    });

    $effect(() => {
        if (browser) {
            // Keep only last 500 IDs to avoid localStorage bloat
            const toStore = dismissedIds.slice(-500);
            localStorage.setItem(
                "kitchen_dismissed_ids",
                JSON.stringify(toStore),
            );
        }

        // AUTO-DISMISS: If a table is marked as 'eating' (served),
        // we should treat those orders as finished even if the chef didn't click anything.
        const servedTables = tables.filter((t) => t.status === "eating");
        servedTables.forEach((table) => {
            const currentItems = orders.filter(
                (o) => Number(o.table_number) === Number(table.number),
            );
            if (currentItems.length > 0) {
                const ids = currentItems.map((i) => i.id);
                const newIds = ids.filter((id) => !dismissedIds.includes(id));
                if (newIds.length > 0) {
                    dismissedIds = [...dismissedIds, ...newIds];
                }
            }
        });
    });

    // Join tables + orders. Show active tables even if no matching orders yet.
    const groupedOrders = $derived.by(() => {
        const activeTables = tables.filter(
            (t) =>
                t.status === "ordered" ||
                t.status === "preparing" ||
                t.status === "eating",
        );

        return activeTables.map((table) => {
            // Logic: Only show orders created AFTER or AT the same time the table was seated.
            // We use table.updated_at as the 'Session Start' time.
            const sessionStart = new Date(table.updated_at).getTime();

            // Match orders by table_number AND ensure they are NOT dismissed AND from current session
            const tableOrders = orders.filter((o) => {
                const oTime = new Date(o.ordered_at).getTime();
                return (
                    Number(o.table_number) === Number(table.number) &&
                    !dismissedIds.includes(o.id) &&
                    (isNaN(oTime) || oTime >= sessionStart - 5000)
                ); // 5s buffer for server lag, not 60s
            });

            // Timer starts from the earliest order at this table, or table update time as fallback
            const startTime =
                tableOrders.length > 0
                    ? Math.min(
                          ...tableOrders.map((o) => {
                              const t = new Date(o.ordered_at).getTime();
                              return isNaN(t) ? now : t;
                          }),
                      )
                    : new Date(table.updated_at).getTime();

            return {
                tableId: table.id,
                tableNumber: table.number,
                status: table.status,
                items: tableOrders.map((o) => ({
                    id: o.id,
                    menu_item_id: o.menu_item_id,
                    name: o.menu_item || `Item #${o.menu_item_id}`,
                    quantity: o.quantity,
                })),
                startTime,
                hasItems: tableOrders.length > 0,
            };
        });
    });

    const newOrders = $derived(
        groupedOrders.filter((g) => g.status === "ordered"),
    );
    const preparingOrds = $derived(
        groupedOrders.filter((g) => g.status === "preparing"),
    );
    const readyOrds = $derived(
        groupedOrders.filter((g) => g.status === "eating"),
    );

    async function startPreparing(tableId) {
        try {
            await api.kitchenStartPreparing(tableId);
            await fetchData();
        } catch (e) {
            console.error("startPreparing error:", e);
        }
    }

    async function markReady(tableId) {
        try {
            // Find current orders for this table and dismiss them locally
            const tableObj = groupedOrders.find((g) => g.tableId === tableId);
            if (tableObj && tableObj.items.length > 0) {
                const idsToDismiss = tableObj.items.map((i) => i.id);
                dismissedIds = [...new Set([...dismissedIds, ...idsToDismiss])];
            }

            await api.kitchenMarkReady(tableId);
            await fetchData();
        } catch (e) {
            console.error("markReady error:", e);
        }
    }

    function elapsedStr(startTime) {
        const diff = Math.max(0, Math.floor((now - startTime) / 1000));
        const m = Math.floor(diff / 60);
        const s = diff % 60;
        return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
    }

    function urgencyColor(startTime) {
        const mins = (now - startTime) / 60000;
        if (mins > 15) return "#ef4444";
        if (mins > 8) return "#f59e0b";
        return "#10b981";
    }

    function clockStr() {
        return new Date(now).toLocaleTimeString([], {
            hour: "2-digit",
            minute: "2-digit",
            second: "2-digit",
            hour12: true,
        });
    }
</script>

<svelte:head>
    <title>Kitchen Display — Cafe De Paris</title>
    <link
        href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800&display=swap"
        rel="stylesheet"
    />
</svelte:head>

<div class="kds">
    <!-- ── TOP NAV ── -->
    <nav class="top-nav">
        <div class="brand">
            <div class="logo">
                <img src="/app_icon.png" alt="App Icon" />
            </div>
            <span>KITCHEN DISPLAY</span>
        </div>

        <div class="meta">
            <div class="dot-wrap" class:on={connected} class:off={!connected}>
                <div class="dot"></div>
                <span>{connected ? "Live" : "Offline"}</span>
            </div>
            <div class="clock">{clockStr()}</div>
            <button class="logout-btn" onclick={() => api.kitchenLogout()}>
                <svg
                    width="14"
                    height="14"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2.5"
                >
                    <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
                    <polyline points="16 17 21 12 16 7" />
                    <line x1="21" y1="12" x2="9" y2="12" />
                </svg>
                Logout
            </button>
        </div>
    </nav>

    <!-- ── BODY ── -->
    <div class="body">
        {#if loading}
            <!-- Loading -->
            <div class="center-state">
                <div class="spinner"></div>
                <p>Connecting to kitchen...</p>
            </div>
        {:else if errorMsg}
            <!-- Connection error -->
            <div class="center-state">
                <div class="auth-card">
                    <div class="auth-icon">⚠️</div>
                    <h2>Connection Error</h2>
                    <p>{errorMsg}</p>
                    <button class="retry-btn" onclick={fetchData}
                        >Retry Connection</button
                    >
                </div>
            </div>
        {:else}
            <!-- ── KANBAN ── -->
            <div class="kanban">
                <!-- NEW ORDERS -->
                <div class="col">
                    <div class="col-head blue-head">
                        <span>NEW ORDERS</span>
                        <span class="badge">{newOrders.length}</span>
                    </div>
                    <div class="col-body">
                        {#each newOrders as order (order.tableId)}
                            <div
                                class="card"
                                style="--accent:{urgencyColor(order.startTime)}"
                            >
                                <div class="card-top">
                                    <div class="tbl-info">
                                        <div class="tbl-label">TABLE</div>
                                        <div class="tbl-num">
                                            {order.tableNumber}
                                        </div>
                                    </div>
                                    <div
                                        class="timer"
                                        style="color:{urgencyColor(
                                            order.startTime,
                                        )}"
                                    >
                                        <svg
                                            width="13"
                                            height="13"
                                            viewBox="0 0 24 24"
                                            fill="none"
                                            stroke="currentColor"
                                            stroke-width="2"
                                        >
                                            <circle
                                                cx="12"
                                                cy="12"
                                                r="10"
                                            /><polyline
                                                points="12 6 12 12 16 14"
                                            />
                                        </svg>
                                        {elapsedStr(order.startTime)}
                                    </div>
                                </div>

                                <div class="items">
                                    {#if order.hasItems}
                                        {#each order.items as item}
                                            <div class="item">
                                                <span class="qty"
                                                    >{item.quantity}×</span
                                                >
                                                <div class="item-meta">
                                                    <span class="name"
                                                        >{item.name}</span
                                                    >
                                                    <span class="id-hint"
                                                        >ID: {item.menu_item_id}</span
                                                    >
                                                </div>
                                            </div>
                                        {/each}
                                    {:else}
                                        <div class="item muted">
                                            Table ordered — no items linked yet
                                        </div>
                                    {/if}
                                </div>

                                <button
                                    class="action-btn blue-btn"
                                    onclick={() =>
                                        startPreparing(order.tableId)}
                                >
                                    ▶ START PREPARING
                                </button>
                            </div>
                        {:else}
                            <div class="empty">No new orders</div>
                        {/each}
                    </div>
                </div>

                <!-- PREPARING -->
                <div class="col">
                    <div class="col-head amber-head">
                        <span>PREPARING</span>
                        <span class="badge">{preparingOrds.length}</span>
                    </div>
                    <div class="col-body">
                        {#each preparingOrds as order (order.tableId)}
                            <div
                                class="card"
                                style="--accent:{urgencyColor(order.startTime)}"
                            >
                                <div class="card-top">
                                    <div class="tbl-info">
                                        <div class="tbl-label">TABLE</div>
                                        <div class="tbl-num">
                                            {order.tableNumber}
                                        </div>
                                    </div>
                                    <div
                                        class="timer"
                                        style="color:{urgencyColor(
                                            order.startTime,
                                        )}"
                                    >
                                        <svg
                                            width="13"
                                            height="13"
                                            viewBox="0 0 24 24"
                                            fill="none"
                                            stroke="currentColor"
                                            stroke-width="2"
                                        >
                                            <circle
                                                cx="12"
                                                cy="12"
                                                r="10"
                                            /><polyline
                                                points="12 6 12 12 16 14"
                                            />
                                        </svg>
                                        {elapsedStr(order.startTime)}
                                    </div>
                                </div>

                                <div class="items">
                                    {#if order.hasItems}
                                        {#each order.items as item}
                                            <div class="item">
                                                <span class="qty"
                                                    >{item.quantity}×</span
                                                >
                                                <div class="item-meta">
                                                    <span class="name"
                                                        >{item.name}</span
                                                    >
                                                    <span class="id-hint"
                                                        >ID: {item.menu_item_id}</span
                                                    >
                                                </div>
                                            </div>
                                        {/each}
                                    {:else}
                                        <div class="item muted">
                                            Preparing — no items linked yet
                                        </div>
                                    {/if}
                                </div>

                                <button
                                    class="action-btn green-btn"
                                    onclick={() => markReady(order.tableId)}
                                >
                                    ✓ MARK READY
                                </button>
                            </div>
                        {:else}
                            <div class="empty">Nothing preparing</div>
                        {/each}
                    </div>
                </div>

                <!-- READY -->
                <div class="col">
                    <div class="col-head green-head">
                        <span>READY TO SERVE</span>
                        <span class="badge">{readyOrds.length}</span>
                    </div>
                    <div class="col-body">
                        {#each readyOrds as order (order.tableId)}
                            <div
                                class="card ready-card"
                                style="--accent:#10b981"
                            >
                                <div class="card-top">
                                    <div class="tbl-info">
                                        <div class="tbl-label">TABLE</div>
                                        <div class="tbl-num">
                                            {order.tableNumber}
                                        </div>
                                    </div>
                                    <div class="ready-badge">READY ✓</div>
                                </div>

                                <div class="items">
                                    {#if order.hasItems}
                                        {#each order.items as item}
                                            <div class="item">
                                                <span class="qty"
                                                    >{item.quantity}×</span
                                                >
                                                <div class="item-meta">
                                                    <span class="name"
                                                        >{item.name}</span
                                                    >
                                                    <span class="id-hint"
                                                        >ID: {item.menu_item_id}</span
                                                    >
                                                </div>
                                            </div>
                                        {/each}
                                    {:else}
                                        <div class="item muted">
                                            Waiting for waiter to collect
                                        </div>
                                    {/if}
                                </div>
                            </div>
                        {:else}
                            <div class="empty">No orders ready</div>
                        {/each}
                    </div>
                </div>
            </div>
        {/if}
    </div>
</div>

<style>
    /* ─── Reset & Base ─── */
    :global(body) {
        margin: 0;
        padding: 0;
        background: #0f172a;
        color: #f1f5f9;
        font-family: "Outfit", sans-serif;
        overflow: hidden;
    }

    .kds {
        display: flex;
        flex-direction: column;
        height: 100vh;
        width: 100vw;
    }

    /* ─── Top Nav ─── */
    .top-nav {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 0 1.75rem;
        height: 72px;
        flex-shrink: 0;
        background: #1e293b;
        border-bottom: 1px solid rgba(255, 255, 255, 0.06);
        box-shadow: 0 2px 16px rgba(0, 0, 0, 0.3);
    }

    .brand {
        display: flex;
        align-items: center;
        gap: 12px;
    }
    .logo {
        width: 38px;
        height: 38px;
        border-radius: 10px;
        background: #fff;
        display: flex;
        align-items: center;
        justify-content: center;
        overflow: hidden;
    }
    .logo img {
        width: 100%;
        height: 100%;
        object-fit: contain;
    }
    .brand span {
        font-size: 1.05rem;
        font-weight: 800;
        letter-spacing: 1.5px;
        color: #f8fafc;
    }

    .counters {
        display: flex;
        gap: 1rem;
    }
    .pill {
        display: flex;
        align-items: center;
        gap: 10px;
        padding: 6px 16px;
        border-radius: 999px;
        border: 1px solid rgba(255, 255, 255, 0.08);
    }
    .pill .n {
        font-size: 1.25rem;
        font-weight: 800;
    }
    .pill .l {
        font-size: 0.7rem;
        font-weight: 700;
        letter-spacing: 1px;
        opacity: 0.7;
    }
    .blue {
        background: rgba(59, 130, 246, 0.12);
        border-color: rgba(59, 130, 246, 0.25);
        color: #93c5fd;
    }
    .amber {
        background: rgba(245, 158, 11, 0.12);
        border-color: rgba(245, 158, 11, 0.25);
        color: #fcd34d;
    }
    .green {
        background: rgba(16, 185, 129, 0.12);
        border-color: rgba(16, 185, 129, 0.25);
        color: #6ee7b7;
    }

    .meta {
        display: flex;
        align-items: center;
        gap: 1.5rem;
    }
    .dot-wrap {
        display: flex;
        align-items: center;
        gap: 6px;
        font-size: 0.8rem;
        font-weight: 600;
    }
    .dot {
        width: 8px;
        height: 8px;
        border-radius: 50%;
        background: currentColor;
    }
    .dot-wrap.on {
        color: #10b981;
    }
    .dot-wrap.off {
        color: #ef4444;
    }
    .clock {
        font-size: 1.4rem;
        font-weight: 700;
        font-variant-numeric: tabular-nums;
        color: #f8fafc;
    }
    .logout-btn {
        display: flex;
        align-items: center;
        gap: 6px;
        padding: 6px 14px;
        border-radius: 8px;
        border: 1px solid rgba(239, 68, 68, 0.3);
        background: rgba(239, 68, 68, 0.08);
        color: #fca5a5;
        font-family: inherit;
        font-size: 0.8rem;
        font-weight: 600;
        cursor: pointer;
        transition: all 0.2s;
    }
    .logout-btn:hover {
        background: rgba(239, 68, 68, 0.15);
        border-color: rgba(239, 68, 68, 0.5);
    }

    /* ─── Body ─── */
    .body {
        flex: 1;
        overflow: hidden;
        display: flex;
        flex-direction: column;
    }

    /* ─── Center States ─── */
    .center-state {
        flex: 1;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        gap: 1rem;
        color: #64748b;
    }

    .spinner {
        width: 44px;
        height: 44px;
        border: 3px solid rgba(59, 130, 246, 0.15);
        border-top-color: #3b82f6;
        border-radius: 50%;
        animation: spin 0.9s linear infinite;
    }
    @keyframes spin {
        to {
            transform: rotate(360deg);
        }
    }

    /* ─── Auth Error Card ─── */
    .auth-card {
        background: #1e293b;
        border: 1px solid rgba(239, 68, 68, 0.3);
        border-radius: 20px;
        padding: 2.5rem;
        max-width: 640px;
        width: 90%;
        text-align: center;
    }
    .auth-icon {
        font-size: 3rem;
        margin-bottom: 1rem;
    }
    .auth-card h2 {
        margin: 0 0 0.75rem;
        font-size: 1.4rem;
        font-weight: 700;
        color: #f8fafc;
    }
    .auth-card p {
        color: #94a3b8;
        font-size: 0.9rem;
        margin: 0 0 0.5rem;
        line-height: 1.6;
    }
    .auth-card .note {
        color: #f59e0b;
        font-weight: 600;
        margin-top: 1.5rem;
    }
    .code-block {
        background: #0f172a;
        border-radius: 12px;
        padding: 1rem 1.25rem;
        text-align: left;
        margin: 1rem 0;
        border: 1px solid rgba(255, 255, 255, 0.06);
    }
    .code-title {
        font-size: 0.7rem;
        font-weight: 700;
        letter-spacing: 1px;
        color: #3b82f6;
        margin-bottom: 0.5rem;
    }
    .code-block pre {
        margin: 0;
        font-size: 0.8rem;
        color: #a5f3fc;
        white-space: pre-wrap;
        line-height: 1.7;
    }
    .retry-btn {
        margin-top: 1.5rem;
        padding: 0.75rem 2rem;
        background: #3b82f6;
        color: #fff;
        border: none;
        border-radius: 10px;
        font-size: 0.9rem;
        font-weight: 700;
        cursor: pointer;
        transition: background 0.2s;
    }
    .retry-btn:hover {
        background: #2563eb;
    }

    /* ─── Kanban ─── */
    .kanban {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 0;
        flex: 1;
        overflow: hidden;
        border-top: 1px solid rgba(255, 255, 255, 0.04);
    }

    .col {
        display: flex;
        flex-direction: column;
        overflow: hidden;
        border-right: 1px solid rgba(255, 255, 255, 0.05);
    }
    .col:last-child {
        border-right: none;
    }

    .col-head {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 1rem 1.25rem;
        font-size: 0.75rem;
        font-weight: 800;
        letter-spacing: 1.5px;
        border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    }
    .blue-head {
        color: #93c5fd;
        background: rgba(59, 130, 246, 0.06);
    }
    .amber-head {
        color: #fcd34d;
        background: rgba(245, 158, 11, 0.06);
    }
    .green-head {
        color: #6ee7b7;
        background: rgba(16, 185, 129, 0.06);
    }

    .badge {
        font-size: 1rem;
        font-weight: 800;
        background: rgba(255, 255, 255, 0.05);
        padding: 2px 10px;
        border-radius: 6px;
    }

    .col-body {
        flex: 1;
        overflow-y: auto;
        padding: 1rem;
        display: flex;
        flex-direction: column;
        gap: 0.85rem;
    }

    /* ─── Order Cards ─── */
    .card {
        background: #1e293b;
        border-radius: 14px;
        padding: 1.1rem 1.15rem;
        border: 1px solid rgba(255, 255, 255, 0.06);
        border-left: 4px solid var(--accent, #3b82f6);
        transition:
            transform 0.15s,
            box-shadow 0.15s;
    }
    .card:hover {
        transform: translateY(-2px);
        box-shadow: 0 8px 24px rgba(0, 0, 0, 0.25);
    }
    .ready-card {
        background: rgba(16, 185, 129, 0.06);
    }

    .card-top {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        margin-bottom: 1rem;
    }
    .tbl-info {
        display: flex;
        flex-direction: column;
    }
    .tbl-label {
        font-size: 0.6rem;
        font-weight: 800;
        color: #475569;
        letter-spacing: 1.5px;
    }
    .tbl-num {
        font-size: 2rem;
        font-weight: 800;
        color: #f8fafc;
        line-height: 1;
    }

    .timer {
        display: flex;
        align-items: center;
        gap: 5px;
        font-size: 0.875rem;
        font-weight: 700;
        font-variant-numeric: tabular-nums;
    }

    .ready-badge {
        background: rgba(16, 185, 129, 0.2);
        color: #10b981;
        padding: 4px 12px;
        border-radius: 99px;
        font-size: 0.75rem;
        font-weight: 700;
    }

    .items {
        display: flex;
        flex-direction: column;
        gap: 5px;
        margin-bottom: 1rem;
    }
    .item {
        display: flex;
        align-items: flex-start;
        gap: 10px;
        margin-bottom: 0.75rem;
    }
    .item:last-child {
        margin-bottom: 0;
    }
    .qty {
        font-size: 0.9rem;
        font-weight: 800;
        color: #60a5fa;
        background: rgba(59, 130, 246, 0.1);
        padding: 2px 6px;
        border-radius: 4px;
        min-width: 2.2rem;
        text-align: center;
    }
    .item-meta {
        display: flex;
        flex-direction: column;
        gap: 1px;
    }
    .name {
        font-size: 0.95rem;
        font-weight: 600;
        color: #e2e8f0;
        line-height: 1.3;
    }
    .id-hint {
        font-size: 0.7rem;
        font-weight: 600;
        color: #475569;
        letter-spacing: 0.5px;
    }
    .item.muted {
        color: #475569;
        font-style: italic;
        font-size: 0.8rem;
    }

    .action-btn {
        width: 100%;
        padding: 10px;
        border-radius: 10px;
        font-size: 0.75rem;
        font-weight: 800;
        letter-spacing: 0.5px;
        border: none;
        cursor: pointer;
        transition: all 0.15s;
    }
    .blue-btn {
        background: #3b82f6;
        color: #fff;
    }
    .blue-btn:hover {
        background: #2563eb;
        transform: scale(1.01);
    }
    .green-btn {
        background: #10b981;
        color: #fff;
    }
    .green-btn:hover {
        background: #059669;
        transform: scale(1.01);
    }

    .empty {
        flex: 1;
        display: flex;
        align-items: center;
        justify-content: center;
        color: #334155;
        font-size: 0.85rem;
        padding: 2rem;
        text-align: center;
    }

    /* ─── Scrollbar ─── */
    .col-body::-webkit-scrollbar {
        width: 4px;
    }
    .col-body::-webkit-scrollbar-track {
        background: transparent;
    }
    .col-body::-webkit-scrollbar-thumb {
        background: rgba(255, 255, 255, 0.06);
        border-radius: 4px;
    }
</style>
