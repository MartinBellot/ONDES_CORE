// Friends Demo - Ondes.Friends API Complete Example
// Demonstrates ALL features of the Friends API

let currentTab = 'friends';
let currentUser = null;
let selectedUser = null;

// ============== Initialize App ==============

document.addEventListener('OndesReady', async () => {
    console.log("✅ Friends Demo Ready");
    
    // Get current user
    currentUser = await Ondes.User.getProfile();
    
    // Configure app bar
    await Ondes.UI.configureAppBar({
        title: "Amis",
        visible: true,
        backgroundColor: "#0a0a0a",
        foregroundColor: "#ffffff"
    });

    // Setup event listeners
    setupTabs();
    setupSearch();
    setupMenu();
    
    // Load initial data
    await loadFriends();
    await updatePendingBadge();
    
    // Show welcome toast
    if (currentUser) {
        await Ondes.UI.showToast({ 
            message: `Bienvenue ${currentUser.username} !`, 
            type: 'info' 
        });
    }
});

// ============== Tab Navigation ==============

function setupTabs() {
    document.querySelectorAll('.tab').forEach(tab => {
        tab.addEventListener('click', () => {
            switchTab(tab.dataset.tab);
        });
    });

    document.getElementById('pendingBtn').addEventListener('click', () => {
        switchTab('pending');
    });
}

function switchTab(tabName) {
    currentTab = tabName;
    
    // Haptic feedback
    Ondes.Device.hapticFeedback('light');
    
    // Update tab buttons
    document.querySelectorAll('.tab').forEach(t => {
        t.classList.toggle('active', t.dataset.tab === tabName);
    });
    
    // Update content visibility
    document.querySelectorAll('.tab-content').forEach(c => {
        c.classList.remove('active');
    });
    document.getElementById(`${tabName}-tab`).classList.add('active');
    
    // Load data for tab
    switch(tabName) {
        case 'friends': loadFriends(); break;
        case 'pending': loadPendingRequests(); break;
        case 'blocked': loadBlockedUsers(); break;
    }
}

// ============== Menu ==============

function setupMenu() {
    document.getElementById('menuBtn').addEventListener('click', showMainMenu);
}

async function showMainMenu() {
    await Ondes.Device.hapticFeedback('light');
    
    const items = [
        { icon: '🔄', label: 'Actualiser', action: refreshCurrentTab },
        { icon: '📊', label: 'Statistiques', action: showStats },
        { icon: '❓', label: 'Aide API', action: showApiHelp },
    ];
    
    showActionSheet(items);
}

async function refreshCurrentTab() {
    closeActionSheet();
    await Ondes.UI.showToast({ message: 'Actualisation...', type: 'info' });
    
    switch(currentTab) {
        case 'friends': await loadFriends(); break;
        case 'pending': await loadPendingRequests(); break;
        case 'blocked': await loadBlockedUsers(); break;
    }
    
    await updatePendingBadge();
    await Ondes.Device.hapticFeedback('success');
}

async function showStats() {
    closeActionSheet();
    
    try {
        const [friends, pending, sent, blocked] = await Promise.all([
            Ondes.Friends.list(),
            Ondes.Friends.getPendingRequests(),
            Ondes.Friends.getSentRequests(),
            Ondes.Friends.getBlocked()
        ]);
        
        await Ondes.UI.showAlert({
            title: '📊 Vos statistiques',
            message: `👥 Amis: ${friends.length}\n📥 Demandes reçues: ${pending.length}\n📤 Demandes envoyées: ${sent.length}\n🚫 Bloqués: ${blocked.length}`,
            buttonText: 'OK'
        });
    } catch (error) {
        await Ondes.UI.showToast({ message: 'Erreur de chargement', type: 'error' });
    }
}

async function showApiHelp() {
    closeActionSheet();
    
    await Ondes.UI.showAlert({
        title: '🔧 API Ondes.Friends',
        message: 'Méthodes disponibles:\n\n• list() - Liste des amis\n• request({username}) - Demande\n• accept(id) - Accepter\n• reject(id) - Refuser\n• remove(id) - Supprimer\n• block({userId}) - Bloquer\n• unblock(id) - Débloquer\n• search(query) - Rechercher\n• getPendingCount() - Badge',
        buttonText: 'Compris'
    });
}

// ============== Friends List ==============

async function loadFriends() {
    const list = document.getElementById('friendsList');
    const empty = document.getElementById('noFriends');
    
    list.innerHTML = '<div class="loading">Chargement...</div>';
    
    try {
        const friends = await Ondes.Friends.list();
        
        if (friends.length === 0) {
            list.innerHTML = '';
            empty.classList.remove('hidden');
        } else {
            empty.classList.add('hidden');
            list.innerHTML = friends.map(friend => `
                <div class="list-item" onclick="showFriendProfile(${JSON.stringify(friend).replace(/"/g, '&quot;')})">
                    <img src="${friend.avatar}" alt="${friend.username}" class="avatar">
                    <div class="user-info">
                        <div class="username">${friend.username}</div>
                        ${friend.bio ? `<div class="bio">${escapeHtml(friend.bio)}</div>` : '<div class="bio">Ami</div>'}
                        <div class="friends-since">Ami depuis ${formatDate(friend.friendsSince)}</div>
                    </div>
                    <button class="btn btn-secondary btn-icon" onclick="event.stopPropagation(); showFriendActions(${JSON.stringify(friend).replace(/"/g, '&quot;')})">⋯</button>
                </div>
            `).join('');
        }
    } catch (error) {
        list.innerHTML = '<div class="empty-state"><span class="emoji">❌</span><p>Erreur de chargement</p></div>';
        console.error('Load friends error:', error);
    }
}

function showFriendProfile(friend) {
    selectedUser = friend;
    
    document.getElementById('modalAvatar').src = friend.avatar;
    document.getElementById('modalUsername').textContent = friend.username;
    document.getElementById('modalBio').textContent = friend.bio || 'Aucune bio';
    document.getElementById('modalStatus').textContent = `✓ Ami depuis ${formatDate(friend.friendsSince)}`;
    document.getElementById('modalStatus').className = 'modal-status status accepted';
    
    document.getElementById('modalActions').innerHTML = `
        <button class="btn btn-danger" onclick="removeFriend(${friend.friendshipId}, '${friend.username}')">
            🗑️ Supprimer des amis
        </button>
        <button class="btn btn-secondary" onclick="blockFromProfile(${JSON.stringify(friend).replace(/"/g, '&quot;')})">
            🚫 Bloquer
        </button>
    `;
    
    document.getElementById('profileModal').classList.remove('hidden');
    Ondes.Device.hapticFeedback('light');
}

function showFriendActions(friend) {
    Ondes.Device.hapticFeedback('light');
    
    const items = [
        { icon: '👤', label: 'Voir le profil', action: () => { closeActionSheet(); showFriendProfile(friend); } },
        { icon: '🗑️', label: 'Supprimer', danger: true, action: () => { closeActionSheet(); removeFriend(friend.friendshipId, friend.username); } },
        { icon: '🚫', label: 'Bloquer', danger: true, action: () => { closeActionSheet(); blockUser(friend.id, friend.username); } },
    ];
    
    showActionSheet(items);
}

async function removeFriend(friendshipId, username) {
    closeProfileModal();
    
    const confirmed = await Ondes.UI.showConfirm({
        title: "Supprimer l'ami",
        message: `Voulez-vous vraiment supprimer ${username} de vos amis ? Cette action est réversible.`,
        confirmText: "Supprimer",
        cancelText: "Annuler"
    });
    
    if (confirmed) {
        try {
            await Ondes.Friends.remove(friendshipId);
            await Ondes.Device.hapticFeedback('success');
            await Ondes.UI.showToast({ message: `${username} supprimé de vos amis`, type: 'info' });
            await loadFriends();
        } catch (error) {
            await Ondes.UI.showToast({ message: 'Erreur lors de la suppression', type: 'error' });
        }
    }
}

// ============== Pending Requests ==============

async function loadPendingRequests() {
    await loadReceivedRequests();
    await loadSentRequests();
}

async function loadReceivedRequests() {
    const list = document.getElementById('pendingList');
    const empty = document.getElementById('noPending');
    
    list.innerHTML = '<div class="loading">Chargement...</div>';
    
    try {
        const requests = await Ondes.Friends.getPendingRequests();
        
        if (requests.length === 0) {
            list.innerHTML = '';
            empty.classList.remove('hidden');
        } else {
            empty.classList.add('hidden');
            list.innerHTML = requests.map(req => `
                <div class="list-item" onclick="showRequestProfile(${JSON.stringify(req).replace(/"/g, '&quot;')}, 'received')">
                    <img src="${req.fromUser.avatar}" alt="${req.fromUser.username}" class="avatar">
                    <div class="user-info">
                        <div class="username">${req.fromUser.username}</div>
                        <div class="bio">${req.fromUser.bio || 'Veut être votre ami'}</div>
                        <div class="friends-since">Reçue ${formatDate(req.createdAt)}</div>
                    </div>
                    <div class="actions">
                        <button class="btn btn-success btn-icon" onclick="event.stopPropagation(); acceptRequest(${req.id})" title="Accepter">✓</button>
                        <button class="btn btn-danger btn-icon" onclick="event.stopPropagation(); rejectRequest(${req.id})" title="Refuser">✕</button>
                    </div>
                </div>
            `).join('');
        }
    } catch (error) {
        console.error('Load pending error:', error);
        list.innerHTML = '<div class="empty-state"><p>Erreur</p></div>';
    }
}

async function loadSentRequests() {
    const list = document.getElementById('sentList');
    const empty = document.getElementById('noSent');
    
    try {
        const requests = await Ondes.Friends.getSentRequests();
        
        if (requests.length === 0) {
            list.innerHTML = '';
            empty.classList.remove('hidden');
        } else {
            empty.classList.add('hidden');
            list.innerHTML = requests.map(req => `
                <div class="list-item" onclick="showRequestProfile(${JSON.stringify(req).replace(/"/g, '&quot;')}, 'sent')">
                    <img src="${req.toUser.avatar}" alt="${req.toUser.username}" class="avatar">
                    <div class="user-info">
                        <div class="username">${req.toUser.username}</div>
                        <div class="bio">${req.toUser.bio || ''}</div>
                        <div class="friends-since">Envoyée ${formatDate(req.createdAt)}</div>
                    </div>
                    <span class="status pending">⏳ En attente</span>
                </div>
            `).join('');
        }
    } catch (error) {
        console.error('Load sent error:', error);
    }
}

function showRequestProfile(request, type) {
    const user = type === 'received' ? request.fromUser : request.toUser;
    selectedUser = { ...user, requestId: request.id, requestType: type };
    
    document.getElementById('modalAvatar').src = user.avatar;
    document.getElementById('modalUsername').textContent = user.username;
    document.getElementById('modalBio').textContent = user.bio || 'Aucune bio';
    document.getElementById('modalStatus').textContent = type === 'received' ? '📥 Demande reçue' : '📤 Demande envoyée';
    document.getElementById('modalStatus').className = 'modal-status status pending';
    
    let actionsHtml = '';
    if (type === 'received') {
        actionsHtml = `
            <button class="btn btn-success" onclick="acceptRequest(${request.id})">
                ✓ Accepter la demande
            </button>
            <button class="btn btn-danger" onclick="rejectRequest(${request.id})">
                ✕ Refuser
            </button>
            <button class="btn btn-secondary" onclick="blockFromRequest(${user.id}, '${user.username}')">
                🚫 Bloquer cet utilisateur
            </button>
        `;
    } else {
        actionsHtml = `
            <p style="color: #8e8e93; text-align: center; padding: 8px;">
                En attente de réponse...
            </p>
        `;
    }
    
    document.getElementById('modalActions').innerHTML = actionsHtml;
    document.getElementById('profileModal').classList.remove('hidden');
    Ondes.Device.hapticFeedback('light');
}

async function acceptRequest(friendshipId) {
    closeProfileModal();
    
    try {
        await Ondes.Friends.accept(friendshipId);
        await Ondes.Device.hapticFeedback('success');
        await Ondes.UI.showToast({ message: '🎉 Nouvel ami ajouté !', type: 'success' });
        await loadPendingRequests();
        await updatePendingBadge();
    } catch (error) {
        await Ondes.UI.showToast({ message: 'Erreur', type: 'error' });
    }
}

async function rejectRequest(friendshipId) {
    closeProfileModal();
    
    const confirmed = await Ondes.UI.showConfirm({
        title: "Refuser la demande",
        message: "Voulez-vous refuser cette demande d'amitié ?",
        confirmText: "Refuser",
        cancelText: "Annuler"
    });
    
    if (confirmed) {
        try {
            await Ondes.Friends.reject(friendshipId);
            await Ondes.Device.hapticFeedback('light');
            await Ondes.UI.showToast({ message: 'Demande refusée', type: 'info' });
            await loadPendingRequests();
            await updatePendingBadge();
        } catch (error) {
            await Ondes.UI.showToast({ message: 'Erreur', type: 'error' });
        }
    }
}

async function blockFromRequest(userId, username) {
    closeProfileModal();
    await blockUser(userId, username);
    await loadPendingRequests();
}

async function blockFromProfile(friend) {
    closeProfileModal();
    await blockUser(friend.id, friend.username);
}

// ============== Blocked Users ==============

async function loadBlockedUsers() {
    const list = document.getElementById('blockedList');
    const empty = document.getElementById('noBlocked');
    
    list.innerHTML = '<div class="loading">Chargement...</div>';
    
    try {
        const blocked = await Ondes.Friends.getBlocked();
        
        if (blocked.length === 0) {
            list.innerHTML = '';
            empty.classList.remove('hidden');
        } else {
            empty.classList.add('hidden');
            list.innerHTML = blocked.map(item => `
                <div class="list-item">
                    <img src="${item.user.avatar}" alt="${item.user.username}" class="avatar">
                    <div class="user-info">
                        <div class="username">${item.user.username}</div>
                        <div class="bio">Bloqué ${formatDate(item.blockedAt)}</div>
                    </div>
                    <button class="btn btn-secondary btn-small" onclick="unblockUser(${item.user.id}, '${item.user.username}')">
                        Débloquer
                    </button>
                </div>
            `).join('');
        }
    } catch (error) {
        console.error('Load blocked error:', error);
        list.innerHTML = '<div class="empty-state"><p>Erreur de chargement</p></div>';
    }
}

async function blockUser(userId, username) {
    const confirmed = await Ondes.UI.showConfirm({
        title: "Bloquer l'utilisateur",
        message: `Voulez-vous bloquer ${username} ? Cette personne ne pourra plus vous envoyer de demandes d'amitié.`,
        confirmText: "Bloquer",
        cancelText: "Annuler"
    });
    
    if (confirmed) {
        try {
            await Ondes.Friends.block({ userId });
            await Ondes.Device.hapticFeedback('warning');
            await Ondes.UI.showToast({ message: `${username} a été bloqué`, type: 'warning' });
            
            // Refresh all relevant lists
            if (currentTab === 'friends') await loadFriends();
            if (currentTab === 'blocked') await loadBlockedUsers();
        } catch (error) {
            await Ondes.UI.showToast({ message: 'Erreur lors du blocage', type: 'error' });
        }
    }
}

async function unblockUser(userId, username) {
    const confirmed = await Ondes.UI.showConfirm({
        title: "Débloquer l'utilisateur",
        message: `Voulez-vous débloquer ${username} ?`,
        confirmText: "Débloquer",
        cancelText: "Annuler"
    });
    
    if (confirmed) {
        try {
            await Ondes.Friends.unblock(userId);
            await Ondes.Device.hapticFeedback('success');
            await Ondes.UI.showToast({ message: `${username} a été débloqué`, type: 'success' });
            await loadBlockedUsers();
        } catch (error) {
            await Ondes.UI.showToast({ message: 'Erreur lors du déblocage', type: 'error' });
        }
    }
}

// ============== Search ==============

function setupSearch() {
    const input = document.getElementById('searchInput');
    const btn = document.getElementById('searchBtn');
    
    btn.addEventListener('click', () => performSearch());
    input.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') performSearch();
    });
    
    // Real-time search with debounce
    let timeout;
    input.addEventListener('input', () => {
        clearTimeout(timeout);
        timeout = setTimeout(() => {
            if (input.value.length >= 2) {
                performSearch();
            } else if (input.value.length === 0) {
                document.getElementById('searchResults').innerHTML = '';
                document.getElementById('searchEmpty').classList.remove('hidden');
            }
        }, 300);
    });
}

async function performSearch() {
    const query = document.getElementById('searchInput').value.trim();
    const results = document.getElementById('searchResults');
    const empty = document.getElementById('searchEmpty');
    
    if (query.length < 2) {
        results.innerHTML = '';
        empty.classList.remove('hidden');
        empty.innerHTML = '<span class="emoji">🔎</span><p>Tapez au moins 2 caractères</p>';
        return;
    }
    
    results.innerHTML = '<div class="loading">Recherche...</div>';
    empty.classList.add('hidden');
    
    try {
        const users = await Ondes.Friends.search(query);
        
        if (users.length === 0) {
            results.innerHTML = '';
            empty.classList.remove('hidden');
            empty.innerHTML = '<span class="emoji">🔍</span><p>Aucun résultat pour "' + escapeHtml(query) + '"</p>';
        } else {
            results.innerHTML = users.map(user => {
                let actionBtn = '';
                let statusBadge = '';
                
                switch(user.friendshipStatus) {
                    case 'accepted':
                        statusBadge = '<span class="status accepted">✓ Ami</span>';
                        actionBtn = `<button class="btn btn-secondary btn-icon" onclick="event.stopPropagation(); showSearchUserActions(${JSON.stringify(user).replace(/"/g, '&quot;')})">⋯</button>`;
                        break;
                    case 'pending':
                        statusBadge = '<span class="status pending">⏳ En attente</span>';
                        break;
                    case 'blocked':
                        statusBadge = '<span class="status blocked">🚫 Bloqué</span>';
                        actionBtn = `<button class="btn btn-secondary btn-small" onclick="event.stopPropagation(); unblockUser(${user.id}, '${user.username}')">Débloquer</button>`;
                        break;
                    default:
                        actionBtn = `<button class="btn btn-primary btn-small" onclick="event.stopPropagation(); sendRequest('${user.username}', ${user.id})">+ Ajouter</button>`;
                }
                
                return `
                    <div class="list-item" onclick="showSearchUserProfile(${JSON.stringify(user).replace(/"/g, '&quot;')})">
                        <img src="${user.avatar}" alt="${user.username}" class="avatar">
                        <div class="user-info">
                            <div class="username">${user.username}</div>
                            ${user.bio ? `<div class="bio">${escapeHtml(user.bio)}</div>` : ''}
                            ${statusBadge}
                        </div>
                        <div class="actions">
                            ${actionBtn}
                        </div>
                    </div>
                `;
            }).join('');
        }
    } catch (error) {
        results.innerHTML = '';
        empty.classList.remove('hidden');
        empty.innerHTML = '<span class="emoji">❌</span><p>Erreur de recherche</p>';
        console.error('Search error:', error);
    }
}

function showSearchUserProfile(user) {
    selectedUser = user;
    
    document.getElementById('modalAvatar').src = user.avatar;
    document.getElementById('modalUsername').textContent = user.username;
    document.getElementById('modalBio').textContent = user.bio || 'Aucune bio';
    
    let statusText = '';
    let statusClass = '';
    let actionsHtml = '';
    
    switch(user.friendshipStatus) {
        case 'accepted':
            statusText = '✓ Déjà ami';
            statusClass = 'status accepted';
            actionsHtml = `
                <button class="btn btn-danger" onclick="removeFriend(${user.friendshipId}, '${user.username}')">
                    🗑️ Supprimer des amis
                </button>
                <button class="btn btn-secondary" onclick="blockFromSearch(${user.id}, '${user.username}')">
                    🚫 Bloquer
                </button>
            `;
            break;
        case 'pending':
            statusText = '⏳ Demande en attente';
            statusClass = 'status pending';
            actionsHtml = `<p style="color: #8e8e93; text-align: center;">En attente de réponse...</p>`;
            break;
        case 'blocked':
            statusText = '🚫 Bloqué';
            statusClass = 'status blocked';
            actionsHtml = `
                <button class="btn btn-primary" onclick="unblockFromSearch(${user.id}, '${user.username}')">
                    Débloquer
                </button>
            `;
            break;
        default:
            statusText = '👤 Non ami';
            statusClass = '';
            actionsHtml = `
                <button class="btn btn-primary" onclick="sendRequestFromProfile('${user.username}', ${user.id})">
                    + Envoyer une demande d'amitié
                </button>
                <button class="btn btn-secondary" onclick="blockFromSearch(${user.id}, '${user.username}')">
                    🚫 Bloquer
                </button>
            `;
    }
    
    document.getElementById('modalStatus').textContent = statusText;
    document.getElementById('modalStatus').className = 'modal-status ' + statusClass;
    document.getElementById('modalActions').innerHTML = actionsHtml;
    
    document.getElementById('profileModal').classList.remove('hidden');
    Ondes.Device.hapticFeedback('light');
}

function showSearchUserActions(user) {
    Ondes.Device.hapticFeedback('light');
    
    const items = [
        { icon: '👤', label: 'Voir le profil', action: () => { closeActionSheet(); showSearchUserProfile(user); } },
    ];
    
    if (user.friendshipStatus === 'accepted') {
        items.push({ icon: '🗑️', label: 'Supprimer des amis', danger: true, action: () => { closeActionSheet(); removeFriend(user.friendshipId, user.username); } });
    }
    
    items.push({ icon: '🚫', label: 'Bloquer', danger: true, action: () => { closeActionSheet(); blockFromSearch(user.id, user.username); } });
    
    showActionSheet(items);
}

async function sendRequest(username, userId) {
    try {
        await Ondes.Friends.request({ username, userId });
        await Ondes.Device.hapticFeedback('success');
        await Ondes.UI.showToast({ message: `Demande envoyée à ${username} !`, type: 'success' });
        await performSearch(); // Refresh results
    } catch (error) {
        const message = error.message || 'Erreur lors de l\'envoi';
        await Ondes.UI.showToast({ message, type: 'error' });
    }
}

async function sendRequestFromProfile(username, userId) {
    closeProfileModal();
    await sendRequest(username, userId);
}

async function blockFromSearch(userId, username) {
    closeProfileModal();
    await blockUser(userId, username);
    await performSearch();
}

async function unblockFromSearch(userId, username) {
    closeProfileModal();
    
    try {
        await Ondes.Friends.unblock(userId);
        await Ondes.Device.hapticFeedback('success');
        await Ondes.UI.showToast({ message: `${username} débloqué`, type: 'success' });
        await performSearch();
    } catch (error) {
        await Ondes.UI.showToast({ message: 'Erreur', type: 'error' });
    }
}

// ============== Badge ==============

async function updatePendingBadge() {
    try {
        const count = await Ondes.Friends.getPendingCount();
        const badge = document.getElementById('pendingBadge');
        
        if (count > 0) {
            badge.textContent = count > 99 ? '99+' : count;
            badge.classList.remove('hidden');
        } else {
            badge.classList.add('hidden');
        }
    } catch (error) {
        console.error('Badge update error:', error);
    }
}

// ============== Modal ==============

function closeProfileModal() {
    document.getElementById('profileModal').classList.add('hidden');
    selectedUser = null;
}

// ============== Action Sheet ==============

function showActionSheet(items) {
    const container = document.getElementById('actionSheetItems');
    
    container.innerHTML = items.map(item => `
        <button class="action-sheet-item ${item.danger ? 'danger' : ''}" onclick="(${item.action.toString()})()">
            <span class="icon">${item.icon}</span>
            <span>${item.label}</span>
        </button>
    `).join('');
    
    document.getElementById('actionSheet').classList.remove('hidden');
}

function closeActionSheet() {
    document.getElementById('actionSheet').classList.add('hidden');
}

// ============== Helpers ==============

function formatDate(isoString) {
    if (!isoString) return 'récemment';
    
    const date = new Date(isoString);
    const now = new Date();
    const diff = now - date;
    
    const minutes = Math.floor(diff / (1000 * 60));
    const hours = Math.floor(diff / (1000 * 60 * 60));
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    
    if (minutes < 1) return "à l'instant";
    if (minutes < 60) return `il y a ${minutes} min`;
    if (hours < 24) return `il y a ${hours}h`;
    if (days === 0) return "aujourd'hui";
    if (days === 1) return "hier";
    if (days < 7) return `il y a ${days} jours`;
    if (days < 30) return `il y a ${Math.floor(days / 7)} sem.`;
    if (days < 365) return `il y a ${Math.floor(days / 30)} mois`;
    
    return date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'short', year: 'numeric' });
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}
