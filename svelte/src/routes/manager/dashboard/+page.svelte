<script>
    import { onDestroy, onMount, tick } from "svelte";
    import KpiCard from "$lib/components/shared/KpiCard.svelte";
    import StatusBadge from "$lib/components/shared/StatusBadge.svelte";
    import Chart from "chart.js/auto";
    import { api } from "$lib/api.js";

    const allowedCategories = new Set([
        "pantry",
        "dairy",
        "beverages",
        "produce",
        "meat",
    ]);

    const stockColor = (status) =>
        status === "critical"
            ? "#EF4444"
            : status === "low"
              ? "#F59E0B"
              : "#1E5F74";

    const severityColor = (severity) =>
        severity === "critical" ? "var(--error-red)" : "var(--warning-orange)";

    const alertColor = (type) =>
        type === "critical" ? "var(--error-red)" : "var(--warning-orange)";

    const getErrorMessage = (err) =>
        err && typeof err === "object" && "message" in err
            ? err.message
            : "Failed to load dashboard";

    let inventory = $state([]);
    let inventoryStats = $state({});
    let payables = $state([]);
    let alerts = $state([]);
    let loading = $state(true);
    let error = $state("");
    let inventoryCanvas;
    let inventoryChart;

    onMount(async () => {
        try {
            const [inv, invStats, pay, al] = await Promise.all([
                api.getInventory(),
                api.getInventoryInsights(),
                api.getPayables(),
                api.getAlerts(),
            ]);
            inventory = (inv || []).filter((item) => {
                const category = (item.category || "").toLowerCase();
                return allowedCategories.has(category);
            });
            inventoryStats = invStats || {};
            payables = Array.isArray(pay) ? pay : [];
            alerts = Array.isArray(al) ? al : [];
        } catch (e) {
            error = getErrorMessage(e);
        } finally {
            loading = false;
        }

        await tick();

        if (inventoryCanvas && inventory.length > 0) {
            const chartItems = inventory.slice(0, 8);
            const chartLabels = chartItems.map((item) => item.name);
            const chartData = chartItems.map((item) => item.quantity || 0);
            const chartColors = chartItems.map((item) =>
                stockColor(item.status),
            );

            if (inventoryChart) {
                inventoryChart.destroy();
            }

            inventoryChart = new Chart(inventoryCanvas, {
                type: "bar",
                data: {
                    labels: chartLabels,
                    datasets: [
                        {
                            label: "Current Stock",
                            data: chartData,
                            backgroundColor: chartColors,
                            borderRadius: 4,
                        },
                    ],
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: { legend: { display: false } },
                    scales: {
                        y: { beginAtZero: true },
                        x: { grid: { display: false } },
                    },
                },
            });
        }
    });

    onDestroy(() => {
        if (inventoryChart) {
            inventoryChart.destroy();
        }
    });

    const pendingPay = $derived(payables.filter((b) => b.status === "pending"));
    const overduePay = $derived(payables.filter((b) => b.status === "overdue"));
    const invoiceCount = $derived(pendingPay.length + overduePay.length);
    const totalOutstanding = $derived(
        [...pendingPay, ...overduePay].reduce((s, b) => s + (b.amount || 0), 0),
    );
    const lowStockItems = $derived((inventoryStats?.items ?? []).slice(0, 6));
    const recentAlerts = $derived(alerts.slice(0, 5));
</script>

<svelte:head><title>Dashboard — Manager — Cafe De Paris</title></svelte:head>

<div class="dashboard">
    {#if loading}
        <div class="skeleton-row">
            {#each [1, 2, 3, 4] as _}<div class="skeleton-card"></div>{/each}
        </div>
    {:else if error}
        <div class="error-banner">
            {error}
            <button class="btn btn-outline" onclick={() => location.reload()}
                >Retry</button
            >
        </div>
    {:else}
        <div class="kpi-row">
            <KpiCard
                label="CRITICAL STOCK"
                value={String(inventoryStats.criticalItems ?? 0)}
                color="var(--error-red)"
                subtitle="items need reorder"
            />
            <KpiCard
                label="LOW STOCK"
                value={String(inventoryStats.lowStockItems ?? 0)}
                color="var(--warning-orange)"
                subtitle="items running low"
            />
            <KpiCard
                label="PENDING PAYABLES"
                value={`₹${totalOutstanding.toFixed(2)}`}
                color="var(--primary-teal)"
                subtitle={`${invoiceCount} invoices`}
            />
            <KpiCard
                label="UNREAD ALERTS"
                value={String(alerts.length)}
                subtitle="need attention"
            />
        </div>

        <div class="card chart-section-card">
            <div class="card-header"><h3>Inventory Levels</h3></div>
            <div class="chart-box">
                <canvas bind:this={inventoryCanvas}></canvas>
            </div>
        </div>

        <div class="two-col">
            <div class="card table-card">
                <div class="card-header">
                    <h3>Low Stock Items</h3>
                    <a href="/manager/inventory">View All →</a>
                </div>
                <table>
                    <thead>
                        <tr>
                            <th>ITEM</th>
                            <th>QTY</th>
                            <th>STATUS</th>
                            <th>MIN. STOCK</th>
                        </tr>
                    </thead>
                    <tbody>
                        {#each lowStockItems as item}
                            <tr>
                                <td class="fw500">{item.name}</td>
                                <td
                                    style="color: {severityColor(
                                        item.severity,
                                    )}; font-weight:600"
                                    >{item.current} {item.unit}</td
                                >
                                <td><StatusBadge status={item.severity} /></td>
                                <td class="muted">{item.threshold || "—"}</td>
                            </tr>
                        {:else}
                            <tr
                                ><td colspan="5" class="empty-cell"
                                    >All items are well stocked ✓</td
                                ></tr
                            >
                        {/each}
                    </tbody>
                </table>
            </div>

            <div class="card alerts-card">
                <div class="card-header">
                    <h3>Recent Alerts</h3>
                    <a href="/manager/alerts">View All →</a>
                </div>
                <div class="alerts-list">
                    {#each recentAlerts as alert}
                        <div class="alert-row">
                            <span
                                class="alert-dot"
                                style="background: {alertColor(alert.type)}"
                            ></span>
                            <div class="alert-info">
                                <p class="alert-title">
                                    {alert.title || alert.message || "Alert"}
                                </p>
                                <p class="alert-desc">
                                    {alert.description || ""}
                                </p>
                            </div>
                        </div>
                    {:else}
                        <p class="empty-cell">No alerts</p>
                    {/each}
                </div>
            </div>
        </div>
    {/if}
</div>

<style>
    .dashboard {
        display: flex;
        flex-direction: column;
        gap: 24px;
    }
    .skeleton-row {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 16px;
    }
    .skeleton-card {
        height: 100px;
        background: var(--border);
        border-radius: var(--card-radius);
        animation: pulse 1.5s infinite;
    }
    @keyframes pulse {
        0%,
        100% {
            opacity: 1;
        }
        50% {
            opacity: 0.5;
        }
    }
    .error-banner {
        background: var(--critical-bg);
        color: var(--critical-text);
        padding: 14px 20px;
        border-radius: var(--card-radius);
        font-size: 14px;
        display: flex;
        align-items: center;
        gap: 12px;
    }
    .alert-banner {
        display: flex;
        align-items: center;
        justify-content: space-between;
        background: #fef2f2;
        border: 1px solid #fca5a5;
        border-radius: var(--card-radius);
        padding: 16px 20px;
    }
    .alert-banner-content {
        display: flex;
        align-items: center;
        gap: 12px;
        color: var(--critical-text);
        font-size: 14px;
    }
    .alert-icon-circle {
        width: 36px;
        height: 36px;
        background: #fee2e2;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        color: var(--error-red);
        flex-shrink: 0;
    }
    .alert-sub {
        font-size: 13px;
        color: var(--critical-text);
        opacity: 0.8;
    }
    .alert-action-btn {
        background: var(--error-red);
        color: #fff;
        font-size: 13px;
        padding: 8px 16px;
        border-radius: var(--button-radius);
        text-decoration: none;
    }
    .kpi-row {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 16px;
    }
    .chart-section-card {
        padding-bottom: 20px;
    }
    .chart-box {
        height: 240px;
        padding: 0 20px;
        position: relative;
    }
    .two-col {
        display: grid;
        grid-template-columns: 1fr 360px;
        gap: 20px;
    }
    .card-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 18px 20px 12px;
    }
    .card-header h3 {
        font-family: var(--font-display);
        font-size: 16px;
        font-weight: 600;
    }
    .card-header a {
        font-size: 13px;
        color: var(--primary-teal);
        text-decoration: none;
    }
    .fw500 {
        font-weight: 500;
    }
    .muted {
        color: var(--text-secondary);
    }
    .empty-cell {
        text-align: center;
        padding: 24px;
        color: var(--text-secondary);
        font-size: 13px;
    }
    .alerts-list {
        padding: 0 20px 16px;
        display: flex;
        flex-direction: column;
        gap: 2px;
    }
    .alert-row {
        display: flex;
        align-items: flex-start;
        gap: 12px;
        padding: 12px 0;
        border-bottom: 1px solid var(--border);
    }
    .alert-row:last-child {
        border-bottom: none;
    }
    .alert-dot {
        width: 8px;
        height: 8px;
        border-radius: 50%;
        margin-top: 6px;
        flex-shrink: 0;
    }
    .alert-info {
        flex: 1;
    }
    .alert-title {
        font-size: 14px;
        font-weight: 500;
        color: var(--text-primary);
    }
    .alert-desc {
        font-size: 12px;
        color: var(--text-secondary);
        margin-top: 2px;
    }
</style>
