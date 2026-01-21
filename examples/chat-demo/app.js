/**
 * Ondes Chat Demo - E2EE Chat Simplifié
 * ======================================
 * Le chiffrement est 100% TRANSPARENT et géré par le Core.
 * Les développeurs n'ont PAS besoin de manipuler la crypto!
 */

// État de l'application
let currentConversation = null;
let currentUser = null;
let isTyping = false;
let typingTimeout = null;

// Éléments DOM
const DOM = {
    status: document.getElementById('status'),
    convList: document.getElementById('conversations-list'),
    chatArea: document.getElementById('chat-area'),
    messagesContainer: document.getElementById('messages-container'),
    messageInput: document.getElementById('message-input'),
    sendBtn: document.getElementById('send-btn'),
    convTitle: document.getElementById('conversation-title'),
    typingIndicator: document.getElementById('typing-indicator'),
    newChatBtn: document.getElementById('new-chat-btn'),
    newChatModal: document.getElementById('new-chat-modal'),
    friendsList: document.getElementById('friends-list'),
    cancelBtn: document.getElementById('cancel-btn')
};

// ========== INITIALISATION ==========

document.addEventListener('OndesReady', async () => {
    console.log('🚀 Ondes Chat Demo');
    await initChat();
});

async function initChat() {
    try {
        DOM.status.textContent = 'Connexion...';
        
        // Récupérer l'utilisateur courant
        currentUser = await Ondes.User.getProfile();
        
        // ✨ UNE SEULE LIGNE pour initialiser tout le E2EE!
        await Ondes.Chat.init();
        
        DOM.status.textContent = '🔒 Connecté (E2EE)';
        DOM.status.className = 'status connected';
        
        // Charger les conversations
        await loadConversations();
        
        // Écouter les nouveaux messages
        setupEventListeners();
        
    } catch (error) {
        console.error('Erreur init:', error);
        DOM.status.textContent = '❌ Erreur de connexion';
        DOM.status.className = 'status error';
    }
}

// ========== CONVERSATIONS ==========

async function loadConversations() {
    const conversations = await Ondes.Chat.getConversations();
    
    DOM.convList.innerHTML = '';
    
    if (conversations.length === 0) {
        DOM.convList.innerHTML = '<p class="empty">Aucune conversation. Commencez par créer une discussion!</p>';
        return;
    }
    
    for (const conv of conversations) {
        const div = document.createElement('div');
        div.className = 'conversation-item';
        div.onclick = () => selectConversation(conv);
        
        const preview = conv.lastMessage?.content || 'Nouvelle conversation';
        const badge = conv.unreadCount > 0 ? `<span class="unread-badge">${conv.unreadCount}</span>` : '';
        
        div.innerHTML = `
            <div class="conv-name">${conv.name}</div>
            <div class="conv-preview">${preview}</div>
            ${badge}
        `;
        
        DOM.convList.appendChild(div);
    }
}

async function selectConversation(conv) {
    currentConversation = conv;
    
    // Mettre à jour l'UI
    DOM.chatArea.classList.add('active');
    DOM.convTitle.textContent = conv.name;
    
    // Charger les messages
    await loadMessages(conv.id);
}

async function loadMessages(conversationId) {
    // ✨ Les messages sont DÉJÀ DÉCHIFFRÉS par le Core!
    const messages = await Ondes.Chat.getMessages(conversationId);
    
    DOM.messagesContainer.innerHTML = '';
    
    for (const msg of messages) {
        appendMessage(msg);
    }
    
    scrollToBottom();
}

// ========== MESSAGES ==========

function appendMessage(msg) {
    const div = document.createElement('div');
    const isMe = msg.senderId === currentUser?.id;
    div.className = `message ${isMe ? 'sent' : 'received'}`;
    
    div.innerHTML = `
        <div class="message-sender">${msg.sender}</div>
        <div class="message-content">${escapeHtml(msg.content)}</div>
        <div class="message-time">${formatTime(msg.createdAt)}</div>
    `;
    
    DOM.messagesContainer.appendChild(div);
}

async function sendMessage() {
    const text = DOM.messageInput.value.trim();
    if (!text || !currentConversation) return;
    
    DOM.messageInput.value = '';
    
    try {
        // ✨ Envoyer le message - le chiffrement est AUTOMATIQUE!
        await Ondes.Chat.send(currentConversation.id, text);
    } catch (error) {
        console.error('Erreur envoi:', error);
        alert('Erreur lors de l\'envoi du message');
    }
}

// ========== NOUVELLE CONVERSATION ==========

async function openNewChatModal() {
    DOM.newChatModal.classList.add('active');
    DOM.friendsList.innerHTML = '<p class="loading">Chargement des amis...</p>';
    
    try {
        // ✨ Récupérer la liste des amis avec Ondes.Friends
        const friends = await Ondes.Friends.list();
        
        if (!friends || friends.length === 0) {
            DOM.friendsList.innerHTML = '<p class="empty">Aucun ami. Ajoutez des amis pour commencer à discuter!</p>';
            return;
        }
        
        DOM.friendsList.innerHTML = '';
        
        for (const friend of friends) {
            const div = document.createElement('div');
            div.className = 'friend-item';
            div.onclick = () => startChatWithFriend(friend);
            
            div.innerHTML = `
                <div class="friend-avatar">${getInitials(friend.username)}</div>
                <div class="friend-info">
                    <div class="friend-name">${escapeHtml(friend.username)}</div>
                    <div class="friend-status">${friend.isOnline ? '🟢 En ligne' : '⚫ Hors ligne'}</div>
                </div>
            `;
            
            DOM.friendsList.appendChild(div);
        }
        
    } catch (error) {
        console.error('Erreur chargement amis:', error);
        DOM.friendsList.innerHTML = '<p class="error">Erreur lors du chargement des amis</p>';
    }
}

async function startChatWithFriend(friend) {
    try {
        // ✨ Démarrer une conversation privée - E2EE automatique!
        const conv = await Ondes.Chat.startChat(friend.username);
        
        closeModal();
        await loadConversations();
        await selectConversation(conv);
        
    } catch (error) {
        console.error('Erreur nouvelle conv:', error);
        alert('Erreur lors de la création de la conversation');
    }
}

function getInitials(name) {
    return name.substring(0, 2).toUpperCase();
}

// ========== EVENT LISTENERS ==========

function setupEventListeners() {
    // ✨ Nouveaux messages (DÉJÀ déchiffrés par le Core!)
    Ondes.Chat.onMessage((msg) => {
        console.log('📩 Nouveau message:', msg);
        
        if (currentConversation && msg.conversationId === currentConversation.id) {
            appendMessage(msg);
            scrollToBottom();
        }
        
        // Recharger la liste pour mettre à jour les previews
        loadConversations();
    });
    
    // Indicateurs de frappe
    Ondes.Chat.onTyping((data) => {
        if (currentConversation && data.conversationId === currentConversation.id) {
            if (data.isTyping) {
                DOM.typingIndicator.textContent = `${data.username} écrit...`;
                DOM.typingIndicator.style.display = 'block';
            } else {
                DOM.typingIndicator.style.display = 'none';
            }
        }
    });
    
    // Bouton envoi
    DOM.sendBtn.onclick = sendMessage;
    
    // Entrée clavier
    DOM.messageInput.onkeypress = (e) => {
        if (e.key === 'Enter') sendMessage();
    };
    
    // Indicateur de frappe sortant
    DOM.messageInput.oninput = () => {
        if (!currentConversation) return;
        
        if (!isTyping) {
            isTyping = true;
            Ondes.Chat.setTyping(currentConversation.id, true);
        }
        
        clearTimeout(typingTimeout);
        typingTimeout = setTimeout(() => {
            isTyping = false;
            Ondes.Chat.setTyping(currentConversation.id, false);
        }, 2000);
    };
    
    // Modal nouvelle conversation
    DOM.newChatBtn.onclick = openNewChatModal;
    DOM.cancelBtn.onclick = closeModal;
}

// ========== UTILITAIRES ==========

function closeModal() {
    DOM.newChatModal.classList.remove('active');
}

function scrollToBottom() {
    DOM.messagesContainer.scrollTop = DOM.messagesContainer.scrollHeight;
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function formatTime(isoString) {
    const date = new Date(isoString);
    return date.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
}
