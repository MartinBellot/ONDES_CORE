/**
 * Ondes Chat - Application de messagerie E2EE moderne
 * =====================================================
 * Utilise les composants natifs Ondes.UI pour une expérience optimale
 * Chiffrement de bout en bout 100% automatique et transparent
 */

// ============================================
// ÉTAT DE L'APPLICATION
// ============================================

const State = {
    user: null,
    conversations: [],
    currentConversation: null,
    isTyping: false,
    typingTimeout: null,
    messageUnsubscribe: null,
    typingUnsubscribe: null,
};

// ============================================
// ÉLÉMENTS DOM
// ============================================

const DOM = {
    app: document.getElementById('app'),
    viewConversations: document.getElementById('view-conversations'),
    viewChat: document.getElementById('view-chat'),
    conversationsList: document.getElementById('conversations-list'),
    emptyState: document.getElementById('empty-state'),
    emptyNewChatBtn: document.getElementById('empty-new-chat-btn'),
    messagesContainer: document.getElementById('messages-container'),
    typingIndicator: document.getElementById('typing-indicator'),
    typingUser: document.getElementById('typing-user'),
    inputArea: document.querySelector('.input-area'),
    messageInput: document.getElementById('message-input'),
    sendBtn: document.getElementById('send-btn'),
};

// ============================================
// INITIALISATION
// ============================================

document.addEventListener('OndesReady', async () => {
    console.log('🚀 Ondes Chat - Initialisation');
    await initializeApp();
});

async function initializeApp() {
    try {
        // Afficher le loading natif
        Ondes.UI.showLoading({
            message: "Connexion sécurisée...",
            spinnerColor: "#007AFF"
        });

        // Récupérer l'utilisateur
        State.user = await Ondes.User.getProfile();
        
        // Initialiser le chat E2EE
        await Ondes.Chat.init();

        // Configurer l'AppBar pour la vue conversations
        configureConversationsAppBar();

        // Charger les conversations
        await loadConversations();

        // Configurer les événements
        setupEventListeners();

        // Cacher le loading
        Ondes.UI.hideLoading();

        // Afficher le toast de connexion
        await Ondes.UI.showToast({
            message: "Chat sécurisé activé",
            type: "success",
            duration: 1000,
            position: "bottom"
        });

    } catch (error) {
        console.error('Erreur initialisation:', error);
        Ondes.UI.hideLoading();
        
        await Ondes.UI.showAlert({
            title: "Erreur de connexion",
            message: "Impossible de se connecter au service de chat. Veuillez réessayer.",
            icon: "error",
            iconColor: "#FF453A",
            buttonText: "Réessayer",
            buttonColor: "#007AFF"
        });
        
        // Réessayer
        await initializeApp();
    }
}

// ============================================
// CONFIGURATION APPBAR
// ============================================

function configureConversationsAppBar() {
    Ondes.UI.configureAppBar({
        title: "Messages",
        visible: true,
        backgroundColor: "#000000",
        foregroundColor: "#ffffff",
        titleBold: true,
        titleSize: 28,
        centerTitle: false,
        elevation: 0,
        actions: [
            { 
                type: "icon", 
                icon: "edit", 
                value: "new_chat"
            }
        ]
    });

    // Écouter les actions de l'AppBar
    Ondes.UI.onAppBarAction((data) => {
        if (data.value === 'new_chat') {
            openNewChatSheet();
        }
    });
}

function configureChatAppBar(conversation) {
    const otherMember = getOtherMember(conversation);
    const isOnline = otherMember?.isOnline || false;
    
    Ondes.UI.configureAppBar({
        title: conversation.name,
        visible: true,
        backgroundColor: "#000000",
        foregroundColor: "#ffffff",
        titleBold: true,
        titleSize: 18,
        centerTitle: true,
        elevation: 0,
        showBackButton: true,
        actions: [
            { 
                type: "icon", 
                icon: "call", 
                value: "call"
            },
            { 
                type: "icon", 
                icon: "more", 
                value: "more"
            }
        ]
    });

    // Écouter le retour
    Ondes.UI.onAppBarLeading(() => {
        goBackToConversations();
    });

    // Écouter les actions
    Ondes.UI.onAppBarAction(async (data) => {
        if (data.value === 'more') {
            await showChatOptions(conversation);
        } else if (data.value === 'call') {
            await Ondes.UI.showToast({
                message: "Appels bientôt disponibles",
                type: "info",
                duration: 2000
            });
        }
    });
}

// ============================================
// CHARGEMENT DES CONVERSATIONS
// ============================================

async function loadConversations() {
    const conversations = await Ondes.Chat.getConversations();
    State.conversations = conversations;

    DOM.conversationsList.innerHTML = '';

    if (conversations.length === 0) {
        DOM.conversationsList.style.display = 'none';
        DOM.emptyState.style.display = 'flex';
        return;
    }

    DOM.conversationsList.style.display = 'block';
    DOM.emptyState.style.display = 'none';

    // Trier par date de dernière mise à jour
    conversations.sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt));

    for (const conv of conversations) {
        const element = createConversationElement(conv);
        DOM.conversationsList.appendChild(element);
    }
}

function createConversationElement(conv) {
    const div = document.createElement('div');
    div.className = 'conversation-item fade-in';
    div.onclick = () => selectConversation(conv);

    const otherMember = getOtherMember(conv);
    const avatar = createAvatarHTML(otherMember, conv.type === 'group' ? conv.members : null);
    const preview = conv.lastMessage?.content || 'Nouvelle conversation';
    const time = conv.lastMessage ? formatRelativeTime(conv.lastMessage.createdAt) : '';
    const hasUnread = conv.unreadCount > 0;

    div.innerHTML = `
        <div class="avatar">
            ${avatar}
            ${otherMember?.isOnline ? '<div class="avatar-status"></div>' : ''}
        </div>
        <div class="conversation-content">
            <div class="conversation-header">
                <span class="conversation-name">${escapeHtml(conv.name)}</span>
                <span class="conversation-time">${time}</span>
            </div>
            <div class="conversation-preview-row">
                <span class="conversation-preview ${hasUnread ? 'unread' : ''}">${escapeHtml(truncate(preview, 45))}</span>
                ${hasUnread ? `<span class="conversation-badge">${conv.unreadCount > 99 ? '99+' : conv.unreadCount}</span>` : ''}
            </div>
        </div>
    `;

    return div;
}

function createAvatarHTML(member, groupMembers = null) {
    // Avatar de groupe
    if (groupMembers && groupMembers.length > 1) {
        const visibleMembers = groupMembers.slice(0, 4);
        const items = visibleMembers.map(m => {
            if (m.avatar) {
                return `<div class="avatar-group-item"><img src="${m.avatar}" alt="${m.username}"></div>`;
            }
            return `<div class="avatar-group-item">${getInitials(m.username)}</div>`;
        }).join('');
        return `<div class="avatar-group">${items}</div>`;
    }

    // Avatar individuel
    if (member?.avatar) {
        return `<img class="avatar-img" src="${member.avatar}" alt="${member.username}">`;
    }

    // Initiales
    const name = member?.username || 'U';
    return `<div class="avatar-initials">${getInitials(name)}</div>`;
}

// ============================================
// SÉLECTION DE CONVERSATION
// ============================================

async function selectConversation(conv) {
    State.currentConversation = conv;

    // Configurer l'AppBar du chat
    configureChatAppBar(conv);

    // Charger les messages
    await loadMessages(conv.id);

    // Changer de vue
    showView('chat');

    // Focus sur l'input
    setTimeout(() => DOM.messageInput.focus(), 300);
}

async function loadMessages(conversationId) {
    const messages = await Ondes.Chat.getMessages(conversationId);
    
    DOM.messagesContainer.innerHTML = '';

    let lastDate = null;
    let lastSenderId = null;

    for (let i = 0; i < messages.length; i++) {
        const msg = messages[i];
        const msgDate = new Date(msg.createdAt).toDateString();

        // Séparateur de date
        if (msgDate !== lastDate) {
            const separator = createDateSeparator(msg.createdAt);
            DOM.messagesContainer.appendChild(separator);
            lastDate = msgDate;
            lastSenderId = null;
        }

        // Grouper les messages du même expéditeur
        const isGrouped = lastSenderId === msg.senderId;
        const element = createMessageElement(msg, isGrouped);
        DOM.messagesContainer.appendChild(element);
        
        lastSenderId = msg.senderId;
    }

    scrollToBottom();
}

function createMessageElement(msg, isGrouped = false) {
    const div = document.createElement('div');
    const isMe = msg.senderId === State.user?.id;
    div.className = `message ${isMe ? 'sent' : 'received'} ${isGrouped ? 'grouped' : ''}`;

    const senderHTML = !isMe && !isGrouped && State.currentConversation?.type === 'group' 
        ? `<div class="message-sender">${escapeHtml(msg.sender)}</div>` 
        : '';

    div.innerHTML = `
        ${senderHTML}
        <div class="message-bubble">
            <div class="message-content">${escapeHtml(msg.content)}</div>
            <div class="message-meta">
                <span class="message-time">${formatTime(msg.createdAt)}</span>
                ${isMe ? '<span class="message-status">✓</span>' : ''}
            </div>
        </div>
    `;

    return div;
}

function createDateSeparator(dateString) {
    const div = document.createElement('div');
    div.className = 'date-separator';
    div.innerHTML = `<span>${formatDateSeparator(dateString)}</span>`;
    return div;
}

// ============================================
// ENVOI DE MESSAGES
// ============================================

async function sendMessage() {
    const text = DOM.messageInput.value.trim();
    if (!text || !State.currentConversation) return;

    // Désactiver temporairement
    DOM.sendBtn.disabled = true;
    DOM.messageInput.value = '';
    updateSendButton();

    try {
        // Envoyer le message (chiffrement automatique)
        await Ondes.Chat.send(State.currentConversation.id, text);
        
        // Arrêter l'indicateur de frappe
        if (State.isTyping) {
            State.isTyping = false;
            Ondes.Chat.setTyping(State.currentConversation.id, false);
        }
        
    } catch (error) {
        console.error('Erreur envoi:', error);
        
        // Remettre le texte
        DOM.messageInput.value = text;
        updateSendButton();
        
        await Ondes.UI.showToast({
            message: "Échec de l'envoi",
            type: "error",
            duration: 3000
        });
    }

    DOM.sendBtn.disabled = false;
}

// ============================================
// NOUVELLE CONVERSATION
// ============================================

async function openNewChatSheet() {
    Ondes.UI.showLoading({
        message: "Chargement...",
        spinnerColor: "#007AFF"
    });

    try {
        const friends = await Ondes.Friends.list();
        Ondes.UI.hideLoading();

        if (!friends || friends.length === 0) {
            await Ondes.UI.showAlert({
                title: "Aucun ami",
                message: "Ajoutez des amis pour commencer à discuter avec eux.",
                icon: "people",
                iconColor: "#007AFF",
                buttonText: "OK"
            });
            return;
        }

        // Créer les items pour le bottom sheet
        const items = friends.map(friend => ({
            icon: friend.isOnline ? "person" : "person",
            label: friend.username,
            subtitle: friend.isOnline ? "En ligne" : "Hors ligne",
            value: friend.username,
            iconColor: friend.isOnline ? "#30D158" : "#8E8E93"
        }));

        // Afficher le bottom sheet natif
        const selectedUsername = await Ondes.UI.showBottomSheet({
            title: "Nouvelle conversation",
            subtitle: "Choisissez un ami pour discuter",
            showDragHandle: true,
            borderRadius: 24,
            backgroundColor: "#1C1C1E",
            scrollable: true,
            titleStyle: {
                bold: true,
                fontSize: 20
            },
            items: items
        });

        if (selectedUsername) {
            await startChatWithUser(selectedUsername);
        }

    } catch (error) {
        console.error('Erreur chargement amis:', error);
        Ondes.UI.hideLoading();
        
        await Ondes.UI.showToast({
            message: "Erreur lors du chargement",
            type: "error",
            duration: 3000
        });
    }
}

async function startChatWithUser(username) {
    Ondes.UI.showLoading({
        message: "Création de la conversation...",
        spinnerColor: "#007AFF"
    });

    try {
        const conv = await Ondes.Chat.startChat(username);
        Ondes.UI.hideLoading();

        // Recharger les conversations
        await loadConversations();

        // Sélectionner la nouvelle conversation
        await selectConversation(conv);

        await Ondes.UI.showToast({
            message: `Discussion avec ${username} créée`,
            type: "success",
            duration: 2000
        });

    } catch (error) {
        console.error('Erreur création conversation:', error);
        Ondes.UI.hideLoading();

        await Ondes.UI.showAlert({
            title: "Erreur",
            message: "Impossible de créer la conversation. Veuillez réessayer.",
            icon: "error",
            iconColor: "#FF453A",
            buttonText: "OK"
        });
    }
}

// ============================================
// OPTIONS DU CHAT
// ============================================

async function showChatOptions(conversation) {
    const action = await Ondes.UI.showActionSheet({
        title: conversation.name,
        message: "Options de la conversation",
        actions: [
            { label: "Voir le profil", value: "profile" },
            { label: "Rechercher dans la conversation", value: "search" },
            { label: "Notifications", value: "notifications" },
            { label: "Bloquer", value: "block", destructive: true }
        ],
        cancelText: "Annuler"
    });

    if (action === 'profile') {
        await Ondes.UI.showToast({
            message: "Profil bientôt disponible",
            type: "info",
            duration: 2000
        });
    } else if (action === 'block') {
        await confirmBlockUser(conversation);
    }
}

async function confirmBlockUser(conversation) {
    const confirmed = await Ondes.UI.showConfirm({
        title: "Bloquer l'utilisateur ?",
        message: `Vous ne recevrez plus de messages de ${conversation.name}. Cette action est réversible.`,
        confirmText: "Bloquer",
        cancelText: "Annuler",
        confirmColor: "#FF453A",
        icon: "block",
        iconColor: "#FF453A"
    });

    if (confirmed) {
        await Ondes.UI.showToast({
            message: "Utilisateur bloqué",
            type: "warning",
            duration: 3000
        });
    }
}

// ============================================
// NAVIGATION
// ============================================

function showView(viewName) {
    DOM.viewConversations.classList.remove('active');
    DOM.viewChat.classList.remove('active');

    if (viewName === 'conversations') {
        DOM.viewConversations.classList.add('active');
    } else if (viewName === 'chat') {
        DOM.viewChat.classList.add('active');
    }
}

function goBackToConversations() {
    State.currentConversation = null;
    showView('conversations');
    configureConversationsAppBar();
    loadConversations();
}

// ============================================
// ÉVÉNEMENTS
// ============================================

function setupEventListeners() {
    // Nouveaux messages en temps réel
    State.messageUnsubscribe = Ondes.Chat.onMessage((msg) => {
        console.log('📩 Nouveau message reçu');
        
        if (State.currentConversation && msg.conversationId === State.currentConversation.id) {
            // Ajouter le message à la vue actuelle
            const element = createMessageElement(msg);
            DOM.messagesContainer.appendChild(element);
            scrollToBottom();
        }

        // Rafraîchir la liste des conversations
        loadConversations();
    });

    // Indicateurs de frappe
    State.typingUnsubscribe = Ondes.Chat.onTyping((data) => {
        if (State.currentConversation && data.conversationId === State.currentConversation.id) {
            if (data.isTyping && data.userId !== State.user?.id) {
                DOM.typingUser.textContent = data.username;
                DOM.typingIndicator.classList.add('active');
            } else {
                DOM.typingIndicator.classList.remove('active');
            }
        }
    });

    // Bouton d'envoi
    DOM.sendBtn.onclick = sendMessage;

    // Input message
    DOM.messageInput.onkeypress = (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendMessage();
        }
    };

    DOM.messageInput.oninput = () => {
        updateSendButton();
        handleTypingIndicator();
    };

    // Bouton nouvelle conversation (état vide)
    if (DOM.emptyNewChatBtn) {
        DOM.emptyNewChatBtn.onclick = openNewChatSheet;
    }

    // Changements de connexion
    Ondes.Chat.onConnectionChange(async (status) => {
        if (status === 'disconnected') {
            await Ondes.UI.showToast({
                message: "Connexion perdue. Reconnexion...",
                type: "warning",
                duration: 3000
            });
        } else if (status === 'connected') {
            await Ondes.UI.showToast({
                message: "Reconnecté",
                type: "success",
                duration: 2000
            });
        }
    });
}

function updateSendButton() {
    const hasText = DOM.messageInput.value.trim().length > 0;
    DOM.sendBtn.disabled = !hasText;
}

function handleTypingIndicator() {
    if (!State.currentConversation) return;

    if (!State.isTyping) {
        State.isTyping = true;
        Ondes.Chat.setTyping(State.currentConversation.id, true);
    }

    clearTimeout(State.typingTimeout);
    State.typingTimeout = setTimeout(() => {
        State.isTyping = false;
        Ondes.Chat.setTyping(State.currentConversation.id, false);
    }, 2000);
}

// ============================================
// UTILITAIRES
// ============================================

function scrollToBottom() {
    requestAnimationFrame(() => {
        DOM.messagesContainer.scrollTop = DOM.messagesContainer.scrollHeight;
    });
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function getInitials(name) {
    if (!name) return 'U';
    const parts = name.split(/[\s_-]+/);
    if (parts.length >= 2) {
        return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
}

function truncate(text, maxLength) {
    if (!text) return '';
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength) + '...';
}

function getOtherMember(conversation) {
    if (!conversation.members || !State.user) return null;
    return conversation.members.find(m => m.id !== State.user.id);
}

function formatTime(isoString) {
    const date = new Date(isoString);
    return date.toLocaleTimeString('fr-FR', { 
        hour: '2-digit', 
        minute: '2-digit' 
    });
}

function formatRelativeTime(isoString) {
    const date = new Date(isoString);
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) return "À l'instant";
    if (diffMins < 60) return `${diffMins}min`;
    if (diffHours < 24) return `${diffHours}h`;
    if (diffDays < 7) {
        return date.toLocaleDateString('fr-FR', { weekday: 'short' });
    }
    return date.toLocaleDateString('fr-FR', { 
        day: 'numeric', 
        month: 'short' 
    });
}

function formatDateSeparator(isoString) {
    const date = new Date(isoString);
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const yesterday = new Date(today.getTime() - 86400000);
    const msgDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());

    if (msgDate.getTime() === today.getTime()) {
        return "Aujourd'hui";
    }
    if (msgDate.getTime() === yesterday.getTime()) {
        return "Hier";
    }
    
    return date.toLocaleDateString('fr-FR', {
        weekday: 'long',
        day: 'numeric',
        month: 'long'
    });
}
