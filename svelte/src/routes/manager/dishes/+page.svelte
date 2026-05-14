<script>
    import { onMount } from "svelte";
    import { api } from "$lib/api.js";

    const createEmptyDish = () => ({
        name: "",
        description: "",
        price: 0,
        category: "mains",
        soldOut: false,
        ingredients: [],
    });

    const normalize = (value) => (value || "").toString().toLowerCase();

    const getErrorMessage = (err) =>
        err && typeof err === "object" && "message" in err
            ? err.message
            : "Failed to load dishes";

    const formatIngredientForEdit = (ing) => {
        const baseUnit = ing.inventory_item_unit || ing.unit || "";
        let quantity = Number(ing.quantity) || 0;
        let selectedUnit = baseUnit;

        if (baseUnit === "kg" && quantity < 1) {
            quantity *= 1000;
            selectedUnit = "g";
        }
        if (baseUnit === "L" && quantity < 1) {
            quantity *= 1000;
            selectedUnit = "ml";
        }

        return {
            inventoryId: ing.inventory_item_id ?? ing.inventoryId,
            quantity,
            unit: baseUnit,
            selectedUnit,
        };
    };

    const toBaseQuantity = (ing) => {
        let finalQty = Number(ing.quantity) || 0;
        if (ing.unit === "kg" && ing.selectedUnit === "g") finalQty /= 1000;
        if (ing.unit === "L" && ing.selectedUnit === "ml") finalQty /= 1000;
        return finalQty;
    };

    let dishes = $state([]);
    let inventory = $state([]);
    let loading = $state(true);
    let error = $state("");
    let search = $state("");

    let showAddModal = $state(false);
    let editingId = $state(null);
    let newItem = $state(createEmptyDish());

    onMount(loadData);

    async function loadData() {
        loading = true;
        error = "";
        try {
            const [m, inv, ing] = await Promise.all([
                api.getMenu(),
                api.getInventory(),
                api.getIngredients(),
            ]);
            const menu = Array.isArray(m) ? m : [];
            const inventoryList = Array.isArray(inv) ? inv : [];
            const ingredients = Array.isArray(ing) ? ing : [];

            const inventoryByName = new Map(
                inventoryList.map((item) => [normalize(item.name), item]),
            );
            const ingredientsByMenu = ingredients.reduce((map, item) => {
                const key = normalize(item.menu_item);
                if (!key) return map;
                const list = map.get(key) || [];
                list.push(item);
                map.set(key, list);
                return map;
            }, new Map());

            inventory = inventoryList;
            dishes = menu.map((dish) => {
                const key = normalize(dish.name);
                const dishIngredients = (ingredientsByMenu.get(key) || []).map(
                    (item) => {
                        const invItem = inventoryByName.get(
                            normalize(item.inventory_item),
                        );
                        return { ...item, unit: invItem?.unit || "" };
                    },
                );
                return { ...dish, ingredients: dishIngredients };
            });
        } catch (e) {
            error = getErrorMessage(e);
        } finally {
            loading = false;
        }
    }

    const inventoryById = $derived(
        new Map(inventory.map((item) => [item.id, item])),
    );
    const normalizedSearch = $derived(search.trim().toLowerCase());
    const filtered = $derived(
        normalizedSearch
            ? dishes.filter((item) =>
                  normalize(item.name).includes(normalizedSearch),
              )
            : dishes,
    );

    function addIngredient() {
        const firstItem = inventory[0];
        if (!firstItem) return;

        newItem.ingredients = [
            ...newItem.ingredients,
            {
                inventoryId: firstItem.id,
                quantity: 1,
                unit: firstItem.unit,
                selectedUnit: firstItem.unit,
            },
        ];
    }

    function removeIngredient(index) {
        newItem.ingredients = newItem.ingredients.filter((_, i) => i !== index);
    }

    function handleIngredientChange(index, newId) {
        const invItem = inventoryById.get(newId);
        if (!invItem) return;

        newItem.ingredients = newItem.ingredients.map((ing, i) =>
            i === index
                ? {
                      ...ing,
                      inventoryId: newId,
                      unit: invItem.unit,
                      selectedUnit: invItem.unit,
                  }
                : ing,
        );
    }

    function openAddModal() {
        editingId = null;
        newItem = createEmptyDish();
        showAddModal = true;
    }

    function editDish(dish) {
        editingId = dish.id;
        const formattedIngredients = (dish.ingredients || []).map(
            formatIngredientForEdit,
        );
        newItem = { ...dish, ingredients: formattedIngredients };
        showAddModal = true;
    }

    async function saveDish() {
        try {
            const dishToSave = {
                ...newItem,
                price: Number(newItem.price) || 0,
                ingredients: newItem.ingredients.map((ing) => ({
                    inventory_item_id: ing.inventoryId,
                    quantity: toBaseQuantity(ing),
                })),
            };

            if (editingId) {
                await api.updateDish(editingId, dishToSave);
            } else {
                await api.addDish(dishToSave);
            }
            showAddModal = false;
            await loadData();
        } catch (e) {
            error = getErrorMessage(e);
            alert("Failed to save dish: " + getErrorMessage(e));
        }
    }

    async function deleteDish(id) {
        if (confirm("Are you sure you want to delete this dish?")) {
            try {
                await api.deleteDish(id);
                await loadData();
            } catch (e) {
                error = getErrorMessage(e);
                alert("Failed to delete dish: " + getErrorMessage(e));
            }
        }
    }
</script>

<svelte:head
    ><title>Dishes Management — Manager — Cafe De Paris</title></svelte:head
>

<div class="dishes-page">
    <div class="page-header">
        <div>
            <h2>Dishes Management</h2>
            <p class="page-subtitle">
                Manage menu items and their recipe ingredients
            </p>
        </div>
        <button class="btn btn-primary" onclick={openAddModal}
            >+ Add Dish</button
        >
    </div>

    <div class="action-row">
        <input
            type="text"
            class="search-input"
            placeholder="Search dishes..."
            bind:value={search}
        />
    </div>

    {#if loading}
        <div class="loading-state">Loading dishes...</div>
    {:else if error}
        <div class="error-state">
            {error}
            <button class="btn btn-outline" onclick={loadData}>Retry</button>
        </div>
    {:else}
        <div class="card">
            <table>
                <thead
                    ><tr
                        ><th>DISH NAME</th><th>CATEGORY</th><th>PRICE</th><th
                            >INGREDIENTS</th
                        ><th>ACTIONS</th></tr
                    ></thead
                >
                <tbody>
                    {#each filtered as dish}
                        <tr>
                            <td class="fw500">
                                {dish.name}
                                {#if dish.soldOut}<span class="sold-out-badge"
                                        >Sold Out</span
                                    >{/if}
                            </td>
                            <td class="muted">{dish.category || "—"}</td>
                            <td class="fw500"
                                >₹{Number(dish.price || 0).toFixed(2)}</td
                            >
                            <td class="muted">
                                {#if dish.ingredients && dish.ingredients.length > 0}
                                    <ul class="ing-list">
                                        {#each dish.ingredients as ing}
                                            <li>
                                                {ing.inventory_item ||
                                                    ing.inventory_item_name} ({ing.quantity}
                                                {ing.inventory_item_unit ||
                                                    ing.unit ||
                                                    ""})
                                            </li>
                                        {/each}
                                    </ul>
                                {:else}
                                    No ingredients mapped
                                {/if}
                            </td>
                            <td>
                                <div class="action-buttons">
                                    <button
                                        class="icon-btn edit-btn"
                                        onclick={() => editDish(dish)}
                                    >
                                        <svg
                                            width="16"
                                            height="16"
                                            viewBox="0 0 24 24"
                                            fill="none"
                                            stroke="currentColor"
                                            stroke-width="2"
                                            ><path d="M12 20h9" /><path
                                                d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"
                                            /></svg
                                        >
                                    </button>
                                    <button
                                        class="icon-btn del-btn"
                                        onclick={() => deleteDish(dish.id)}
                                    >
                                        <svg
                                            width="16"
                                            height="16"
                                            viewBox="0 0 24 24"
                                            fill="none"
                                            stroke="currentColor"
                                            stroke-width="2"
                                            ><path d="M3 6h18" /><path
                                                d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"
                                            /><line
                                                x1="10"
                                                y1="11"
                                                x2="10"
                                                y2="17"
                                            /><line
                                                x1="14"
                                                y1="11"
                                                x2="14"
                                                y2="17"
                                            /></svg
                                        >
                                    </button>
                                </div>
                            </td>
                        </tr>
                    {:else}
                        <tr
                            ><td colspan="5" class="empty-cell"
                                >No dishes found</td
                            ></tr
                        >
                    {/each}
                </tbody>
            </table>
        </div>
    {/if}
</div>

{#if showAddModal}
    <div class="modal-overlay" onclick={() => (showAddModal = false)}>
        <div class="modal-card" onclick={(e) => e.stopPropagation()}>
            <h3>{editingId ? "Edit" : "Add"} Dish</h3>

            <label class="field-label">Dish Name</label>
            <input
                type="text"
                bind:value={newItem.name}
                placeholder="e.g. Chicken Biryani"
            />

            <label class="field-label">Description</label>
            <input
                type="text"
                bind:value={newItem.description}
                placeholder="Short description..."
            />

            <div class="form-row">
                <div>
                    <label class="field-label">Category</label><select
                        bind:value={newItem.category}
                        ><option>starters</option><option>mains</option><option
                            >sides</option
                        ><option>desserts</option><option>drinks</option
                        ></select
                    >
                </div>
                <div>
                    <label class="field-label">Price (₹)</label><input
                        type="number"
                        step="0.5"
                        bind:value={newItem.price}
                    />
                </div>
            </div>

            <div class="ingredients-section">
                <div class="ing-header">
                    <h4>Recipe Ingredients</h4>
                    <button
                        class="btn btn-outline small-btn"
                        onclick={addIngredient}>+ Add</button
                    >
                </div>

                {#if newItem.ingredients.length === 0}
                    <p class="muted small-txt">No ingredients added yet.</p>
                {:else}
                    <div class="ing-rows">
                        {#each newItem.ingredients as ing, idx}
                            <div class="ing-row">
                                <select
                                    value={ing.inventoryId}
                                    onchange={(e) =>
                                        handleIngredientChange(
                                            idx,
                                            parseInt(e.target.value),
                                        )}
                                >
                                    {#each inventory as invItem}
                                        <option value={invItem.id}
                                            >{invItem.name}</option
                                        >
                                    {/each}
                                </select>
                                <input
                                    type="number"
                                    step="0.01"
                                    bind:value={
                                        newItem.ingredients[idx].quantity
                                    }
                                    placeholder="Qty"
                                    class="qty-input"
                                />

                                <select
                                    class="unit-select"
                                    bind:value={
                                        newItem.ingredients[idx].selectedUnit
                                    }
                                >
                                    {#if ing.unit === "kg"}
                                        <option value="kg">kg</option>
                                        <option value="g">g</option>
                                    {:else if ing.unit === "L"}
                                        <option value="L">L</option>
                                        <option value="ml">ml</option>
                                    {:else}
                                        <option value={ing.unit}
                                            >{ing.unit}</option
                                        >
                                    {/if}
                                </select>

                                <button
                                    class="icon-btn del-btn"
                                    onclick={() => removeIngredient(idx)}
                                    >×</button
                                >
                            </div>
                        {/each}
                    </div>
                {/if}
            </div>

            <div class="modal-actions">
                <button
                    class="btn btn-outline"
                    onclick={() => (showAddModal = false)}>Cancel</button
                >
                <button class="btn btn-primary" onclick={saveDish}
                    >{editingId ? "Update" : "Save"} Dish</button
                >
            </div>
        </div>
    </div>
{/if}

<style>
    .dishes-page {
        display: flex;
        flex-direction: column;
        gap: 20px;
    }
    .page-header {
        display: flex;
        align-items: flex-start;
        justify-content: space-between;
    }
    .page-header h2 {
        font-family: var(--font-display);
        font-size: 22px;
    }
    .page-subtitle {
        font-size: 13px;
        color: var(--text-secondary);
        margin-top: 2px;
    }
    .action-row {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 16px;
    }
    .search-input {
        width: 300px;
    }
    .fw500 {
        font-weight: 500;
    }
    .muted {
        color: var(--text-secondary);
    }
    .small-txt {
        font-size: 13px;
    }

    .sold-out-badge {
        background: var(--critical-bg);
        color: var(--error-red);
        font-size: 11px;
        padding: 2px 6px;
        border-radius: 4px;
        margin-left: 8px;
        font-weight: 600;
    }
    .ing-list {
        margin: 0;
        padding-left: 16px;
        font-size: 13px;
    }
    .ing-list li {
        margin-bottom: 4px;
    }

    .action-buttons {
        display: flex;
        gap: 4px;
    }
    .icon-btn {
        background: none;
        border: none;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        width: 28px;
        height: 28px;
        border-radius: 4px;
        transition: 0.2s;
        color: var(--text-secondary);
    }
    .edit-btn:hover {
        background: var(--hover-bg);
        color: var(--primary-teal);
    }
    .del-btn:hover {
        background: var(--critical-bg);
        color: var(--error-red);
    }

    .loading-state,
    .error-state,
    .empty-cell {
        text-align: center;
        padding: 40px;
        color: var(--text-secondary);
    }

    .modal-overlay {
        position: fixed;
        inset: 0;
        background: rgba(0, 0, 0, 0.4);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 1000;
    }
    .modal-card {
        background: var(--card-surface);
        border-radius: 16px;
        padding: 32px;
        width: 500px;
        max-height: 90vh;
        overflow-y: auto;
    }
    .modal-card h3 {
        font-family: var(--font-display);
        font-size: 18px;
        margin-bottom: 16px;
    }
    .field-label {
        display: block;
        font-size: 13px;
        font-weight: 500;
        margin: 12px 0 4px;
    }
    .modal-card input,
    .modal-card select {
        width: 100%;
    }
    .form-row {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 12px;
    }

    .ingredients-section {
        margin-top: 24px;
        padding-top: 16px;
        border-top: 1px solid var(--border);
    }
    .ing-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 12px;
    }
    .ing-header h4 {
        font-size: 14px;
        font-weight: 600;
    }
    .small-btn {
        padding: 4px 12px;
        font-size: 12px;
    }

    .ing-rows {
        display: flex;
        flex-direction: column;
        gap: 10px;
    }
    .ing-row {
        display: flex;
        align-items: center;
        gap: 8px;
    }
    .ing-row select {
        flex: 1;
    }
    .qty-input {
        width: 80px !important;
    }
    .unit-select {
        width: 70px !important;
        font-size: 13px;
        padding: 4px;
    }

    .modal-actions {
        display: flex;
        gap: 12px;
        justify-content: flex-end;
        margin-top: 24px;
    }
</style>
