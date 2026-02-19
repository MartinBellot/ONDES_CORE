/**
 * AI ChatBot — WebLLM + Ondes Mini-App
 * ======================================
 * Modèle IA local via WebGPU (WebLLM)
 * Interface style ChatGPT, 100% privé
 *
 * Architecture :
 *   - WebLLM (CDN ESM) pour l'inférence locale
 *   - Ondes.Storage pour persister les conversations
 *   - Ondes.UI pour les toasts et overlays natifs
 *   - Streaming token par token avec cursor animé
 */

import * as webllm from "https://esm.run/@mlc-ai/web-llm";

// ═══════════════════════════════════════════════════════
// CONSTANTES
// ═══════════════════════════════════════════════════════

const STORAGE_KEY_CONVERSATIONS = "chatbot_conversations";
const STORAGE_KEY_ACTIVE         = "chatbot_active_conv";
const STORAGE_KEY_MODEL          = "chatbot_model";
const MAX_CONTEXT_MESSAGES       = 20;  // Limite de contexte envoyé au modèle
const MAX_CONVERSATIONS          = 50;  // Limite de sauvegarde

const MODELS = [
    {
        id:    "Llama-3.2-1B-Instruct-q4f16_1-MLC",
        label: "Llama 3.2 · 1B",
        badge: "Rapide",
        size:  "~750 MB",
    },
    {
        id:    "Llama-3.2-3B-Instruct-q4f16_1-MLC",
        label: "Llama 3.2 · 3B",
        badge: "Équilibré",
        size:  "~1.8 GB",
    },
    {
        id:    "Phi-3.5-mini-instruct-q4f16_1-MLC",
        label: "Phi 3.5 Mini · 3.8B",
        badge: "Pro",
        size:  "~2.2 GB",
    },
];

const SYSTEM_PROMPT =
    "You are a helpful, harmless, and honest AI assistant. " +
    "Answer in the same language as the user. Be concise but thorough. " +
    "Format your responses with Markdown when appropriate (lists, code blocks, bold text, etc.).";


// ═══════════════════════════════════════════════════════
// ÉTAT GLOBAL
// ═══════════════════════════════════════════════════════

const State = {
    engine:            null,    // MLCEngine instance
    isStreaming:       false,   // Génération en cours
    abortStreaming:    null,    // Function pour stopper
    selectedModel:     MODELS[1].id,
    loadedModelId:     null,    // ID du modèle actuellement chargé en mémoire
    conversations:     [],      // [{ id, title, messages: [{role, content}] }]
    activeConvId:      null,
    ondesReady:        false,
    useOndesStorage:   false,
};


// ═══════════════════════════════════════════════════════
// DOM
// ═══════════════════════════════════════════════════════

const $ = (id) => document.getElementById(id);

const DOM = {
    // Screens
    screenLoading: $("screen-loading"),
    screenChat:    $("screen-chat"),

    // Modal sélection de modèle
    modalBackdrop: $("modal-backdrop"),
    modalSheet:    $("modal-model-select"),
    modalClose:    $("modal-close"),

    // Model select
    modelCards:    $("model-cards"),
    btnStart:      $("btn-start"),
    webgpuWarning: $("webgpu-warning"),

    // Loading
    loadingTitle:     $("loading-title"),
    loadingModelName: $("loading-model-name"),
    progressFill:     $("progress-fill"),
    loadingPct:       $("loading-pct"),
    loadingStatus:    $("loading-status"),

    // Chat header
    headerModelName: $("header-model-name"),
    btnMenu:         $("btn-menu"),
    btnNewChat:      $("btn-new-chat"),

    // Sidebar
    sidebar:              $("sidebar"),
    sidebarOverlay:       $("sidebar-overlay"),
    sidebarClose:         $("sidebar-close"),
    sidebarNewChat:       $("sidebar-new-chat"),
    sidebarConversations: $("sidebar-conversations"),
    sidebarModelLabel:    $("sidebar-model-label"),
    btnChangeModel:       $("btn-change-model"),

    // Chat
    chatMain:    $("chat-main"),
    welcomeState: $("welcome-state"),
    messagesList: $("messages-list"),

    // Input
    messageInput: $("message-input"),
    sendBtn:      $("send-btn"),
};


// ═══════════════════════════════════════════════════════
// POINTS D'ENTRÉE
// ═══════════════════════════════════════════════════════

/**
 * Démarre l'app avec le bridge Ondes.
 * Deux cas couverts :
 *   1. Le module ES se charge AVANT le bridge  → on écoute OndesReady
 *   2. Le bridge est déjà injecté AVANT le module → window.Ondes est présent,
 *      OndesReady a déjà été dispatché et ne refira pas ; on démarre directement.
 * Le flag bootStarted empêche un double démarrage.
 */
let bootStarted = false;

async function startApp() {
    if (bootStarted) return;
    bootStarted = true;
    State.ondesReady      = true;
    State.useOndesStorage = true;
    console.log("✅ OndesReady — démarrage de l'app");
    await boot();
}

// Cas 1 : bridge injecté après le chargement du module
document.addEventListener("OndesReady", () => startApp());

// Cas 2 : bridge déjà injecté avant le chargement du module (race condition)
if (window.Ondes) {
    startApp();
}


// ═══════════════════════════════════════════════════════
// DÉMARRAGE
// ═══════════════════════════════════════════════════════

async function boot() {
    // Vérifier WebGPU
    const gpuOk = await checkWebGPU();
    if (!gpuOk) {
        DOM.webgpuWarning.style.display = "flex";
        DOM.btnStart.disabled = true;
        DOM.btnStart.textContent = "WebGPU non disponible";
    }

    // Charger conversations sauvegardées
    await loadConversationsFromStorage();

    // Événements (toujours initialisés avant de choisir l'écran)
    setupModelSelectEvents();
    setupChatEvents();

    // Afficher le statut de cache sur les cards (⚡ en cache / ☁ à télécharger)
    // Lancé en arrière-plan, sans bloquer le démarrage
    updateModelCardsCacheStatus();

    // Si un modèle a déjà été sélectionné lors d'une visite précédente,
    // on le charge directement sans repasser par la sélection.
    const savedModel = await getFromStorage(STORAGE_KEY_MODEL);
    if (savedModel && MODELS.some(m => m.id === savedModel)) {
        State.selectedModel = savedModel;
        selectModelCard(savedModel);
        // Lancement automatique du chargement
        loadEngine(savedModel);
    } else {
        // Première visite : on laisse l'utilisateur choisir
        openModelModal(false);
    }
}


// ═══════════════════════════════════════════════════════
// WEBGPU CHECK
// ═══════════════════════════════════════════════════════

async function checkWebGPU() {
    if (!navigator.gpu) return false;
    try {
        const adapter = await navigator.gpu.requestAdapter();
        return !!adapter;
    } catch {
        return false;
    }
}


// ═══════════════════════════════════════════════════════
// SÉLECTION DU MODÈLE
// ═══════════════════════════════════════════════════════

function setupModelSelectEvents() {
    // Fermeture du modal (quand un modèle est déjà chargé)
    DOM.modalClose.addEventListener("click", () => {
        closeModelModal();
    });

    // Click sur les cards
    DOM.modelCards.querySelectorAll(".model-card").forEach((card) => {
        card.addEventListener("click", () => {
            selectModelCard(card.dataset.model);
        });
    });

    // Bouton "Charger le modèle"
    DOM.btnStart.addEventListener("click", () => {
        if (DOM.btnStart.disabled) return;
        loadEngine(State.selectedModel);
    });
}

function selectModelCard(modelId) {
    State.selectedModel = modelId;
    DOM.modelCards.querySelectorAll(".model-card").forEach((card) => {
        card.classList.toggle("selected", card.dataset.model === modelId);
    });
}


// ═══════════════════════════════════════════════════════
// CHARGEMENT DU MOTEUR WEBLLM
// ═══════════════════════════════════════════════════════

async function loadEngine(modelId) {
    // ─── 1. Libérer l'engine existant avant d'en charger un nouveau ──────────
    // IMPORTANT : sans engine.unload(), les buffers WebGPU restent alloués en
    // mémoire système même après State.engine = null. C'est la cause principale
    // de la saturation RAM/VRAM observée.
    if (State.engine) {
        try { await State.engine.unload(); } catch (_) {}
        State.engine = null;
        State.loadedModelId = null;
    }

    closeModelModal();
    showScreen("loading");

    const modelInfo = MODELS.find(m => m.id === modelId) || { label: modelId };
    DOM.loadingModelName.textContent = modelInfo.label;
    DOM.loadingPct.textContent       = "";
    DOM.progressFill.classList.add("indeterminate");
    DOM.progressFill.style.width     = "";

    // ─── 2. Vérifier si le modèle est déjà en cache (Cache Storage API) ──────
    // Les modèles WebLLM (~750 MB – 2.2 GB) sont stockés définitivement dans
    // WebsiteData/Default/ via la Cache Storage API. Si déjà présent, aucun
    // téléchargement réseau n'est nécessaire → on informe l'utilisateur.
    const alreadyCached = await webllm.hasModelInCache(modelId).catch(() => false);
    DOM.loadingTitle.textContent = alreadyCached
        ? "Chargement depuis le cache…"
        : "Première utilisation — téléchargement…";
    setLoadingStatus(alreadyCached
        ? "Lecture des données en cache local…"
        : "Initialisation du téléchargement…");

    try {
        // Callback de progression
        const initProgressCallback = (progress) => {
            const text = progress.text || "";
            const pct  = progress.progress !== undefined ? progress.progress : -1;

            // Si cache détecté en amont mais le callback indique un fetch = re-download partiel
            const isDownloading = /fetch|download|param/i.test(text);
            DOM.loadingTitle.textContent = isDownloading
                ? "Téléchargement en cours…"
                : (alreadyCached ? "Chargement depuis le cache…" : "Chargement du modèle…");

            DOM.loadingStatus.textContent = text;

            if (pct >= 0) {
                DOM.progressFill.classList.remove("indeterminate");
                DOM.progressFill.style.width = `${Math.round(pct * 100)}%`;
                DOM.loadingPct.textContent   = `${Math.round(pct * 100)} %`;
            } else {
                DOM.progressFill.classList.add("indeterminate");
                DOM.loadingPct.textContent = "";
            }
        };

        // Créer le moteur WebLLM
        State.engine = await webllm.CreateMLCEngine(
            modelId,
            {
                initProgressCallback,
                logLevel: "SILENT",
            }
        );

        // Tracker le modèle chargé en mémoire
        State.loadedModelId = modelId;

        // Sauvegarde du modèle choisi
        await saveToStorage(STORAGE_KEY_MODEL, modelId);

        setLoadingStatus("Modèle prêt !");
        DOM.progressFill.style.width = "100%";

        await sleep(500);

        // Mettre à jour l'en-tête
        DOM.headerModelName.textContent = modelInfo.label;
        DOM.sidebarModelLabel.textContent = modelInfo.label;

        // Aller vers le chat
        showScreen("chat");
        initChatScreen();

    } catch (err) {
        console.error("Erreur chargement modèle :", err);
        setLoadingStatus(`Erreur : ${err.message || err}`);
        showNativeToast("Erreur lors du chargement du modèle.", "error");

        await sleep(2500);
        openModelModal(true);
    }
}

function setLoadingStatus(text) {
    DOM.loadingStatus.textContent = text;
}


// ═══════════════════════════════════════════════════════
// ÉCRAN DE CHAT — INITIALISATION
// ═══════════════════════════════════════════════════════

function initChatScreen() {
    renderSidebarConversations();

    // Reprendre la dernière conversation ou en créer une nouvelle
    if (State.conversations.length > 0 && State.activeConvId) {
        openConversation(State.activeConvId);
    } else {
        newConversation();
    }
}


// ═══════════════════════════════════════════════════════
// GESTION DES CONVERSATIONS
// ═══════════════════════════════════════════════════════

function newConversation() {
    const conv = {
        id:       genId(),
        title:    "Nouvelle conversation",
        messages: [],
        createdAt: Date.now(),
    };
    State.conversations.unshift(conv);
    State.activeConvId = conv.id;

    renderMessages();
    renderSidebarConversations();
    saveConversationsToStorage();
    DOM.messageInput.focus();
}

function openConversation(convId) {
    const conv = State.conversations.find(c => c.id === convId);
    if (!conv) return;
    State.activeConvId = convId;
    renderMessages();
    renderSidebarConversations();
    saveActiveConvToStorage();
    closeSidebar();
}

function deleteConversation(convId) {
    State.conversations = State.conversations.filter(c => c.id !== convId);

    if (State.activeConvId === convId) {
        if (State.conversations.length > 0) {
            openConversation(State.conversations[0].id);
        } else {
            newConversation();
        }
    }

    renderSidebarConversations();
    saveConversationsToStorage();
}

function getActiveConv() {
    return State.conversations.find(c => c.id === State.activeConvId) || null;
}

/**
 * Génère un titre automatique pour la conversation (premiers mots du message)
 */
function autoTitleConv(conv, firstUserMsg) {
    if (conv.title !== "Nouvelle conversation") return;
    const words = firstUserMsg.trim().split(/\s+/).slice(0, 6).join(" ");
    conv.title = words.length > 40 ? words.slice(0, 40) + "…" : words;
}


// ═══════════════════════════════════════════════════════
// RENDU DES MESSAGES
// ═══════════════════════════════════════════════════════

function renderMessages() {
    const conv = getActiveConv();
    DOM.messagesList.innerHTML = "";

    if (!conv || conv.messages.length === 0) {
        DOM.welcomeState.style.display = "";
        DOM.messagesList.style.display = "none";
    } else {
        DOM.welcomeState.style.display = "none";
        DOM.messagesList.style.display = "";

        conv.messages.forEach((msg) => {
            appendMessageNode(msg.role, msg.content, false);
        });

        scrollToBottom();
    }
}

/**
 * Crée et insère un nœud de message dans la liste.
 * @param {string} role    - "user" | "assistant"
 * @param {string} content - texte
 * @param {boolean} animate - enable enter animation
 * @returns {HTMLElement} le nœud créé (pour le streaming)
 */
function appendMessageNode(role, content = "", animate = true) {
    DOM.welcomeState.style.display = "none";
    DOM.messagesList.style.display = "";

    const group = document.createElement("div");
    group.className = `message-group${animate ? "" : ""}`;

    if (role === "user") {
        group.innerHTML = `
            <div class="msg-user">
                <div class="msg-user-bubble">${escapeHtml(content)}</div>
            </div>`;
    } else {
        group.innerHTML = `
            <div class="msg-ai">
                <div class="msg-ai-avatar">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <circle cx="12" cy="12" r="10"/>
                        <path d="M8 12c0-2.2 1.8-4 4-4s4 1.8 4 4" stroke-linecap="round"/>
                        <circle cx="12" cy="14" r="2.5" fill="currentColor" stroke="none"/>
                    </svg>
                </div>
                <div class="msg-ai-content">
                    <div class="msg-ai-text"></div>
                    <div class="msg-ai-actions" style="display:none"></div>
                </div>
            </div>`;
    }

    DOM.messagesList.appendChild(group);

    if (animate) {
        group.style.animation = "msg-in 200ms ease";
    }

    return group;
}

/**
 * Met à jour le contenu d'un message IA en cours de streaming.
 */
function updateAiMessageContent(node, text, isStreaming = false) {
    const textEl = node.querySelector(".msg-ai-text");
    if (!textEl) return;

    const cursor = isStreaming ? '<span class="stream-cursor"></span>' : "";
    textEl.innerHTML = renderMarkdown(text) + cursor;
}

/**
 * Finalise un message IA (retire le cursor, ajoute les actions).
 */
function finalizeAiMessage(node, text) {
    const textEl    = node.querySelector(".msg-ai-text");
    const actionsEl = node.querySelector(".msg-ai-actions");

    if (textEl)    textEl.innerHTML = renderMarkdown(text);
    if (actionsEl) {
        actionsEl.style.display = "";
        actionsEl.innerHTML = `
            <button class="msg-action-btn" data-action="copy">
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/></svg>
                Copier
            </button>`;

        actionsEl.querySelector("[data-action='copy']").addEventListener("click", () => {
            navigator.clipboard.writeText(text).then(() => {
                showToast("Copié !");
            });
        });
    }
}

/** Indicateur "En train de penser…" */
function appendThinkingNode() {
    const group = document.createElement("div");
    group.className = "message-group";
    group.innerHTML = `
        <div class="msg-ai">
            <div class="msg-ai-avatar">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="12" cy="12" r="10"/>
                    <path d="M8 12c0-2.2 1.8-4 4-4s4 1.8 4 4" stroke-linecap="round"/>
                    <circle cx="12" cy="14" r="2.5" fill="currentColor" stroke="none"/>
                </svg>
            </div>
            <div class="msg-ai-content">
                <div class="thinking-dots">
                    <span></span><span></span><span></span>
                </div>
            </div>
        </div>`;
    DOM.messagesList.appendChild(group);
    scrollToBottom();
    return group;
}


// ═══════════════════════════════════════════════════════
// ENVOI DE MESSAGE & STREAMING
// ═══════════════════════════════════════════════════════

async function sendMessage() {
    const input = DOM.messageInput.value.trim();
    if (!input || State.isStreaming || !State.engine) return;

    const conv = getActiveConv();
    if (!conv) return;

    // Ajouter le message utilisateur
    const userMsg = { role: "user", content: input };
    conv.messages.push(userMsg);

    // Auto-titre
    if (conv.messages.filter(m => m.role === "user").length === 1) {
        autoTitleConv(conv, input);
    }

    // Réinitialiser l'input
    DOM.messageInput.value = "";
    autoResizeTextarea();
    setInputEnabled(false);

    // Afficher le message utilisateur
    appendMessageNode("user", input);
    scrollToBottom();

    // Afficher indicateur de réflexion
    const thinkingNode = appendThinkingNode();
    scrollToBottom();

    // Préparer le contexte (limité à MAX_CONTEXT_MESSAGES)
    const recentMessages = conv.messages.slice(-MAX_CONTEXT_MESSAGES);
    const messages = [
        { role: "system", content: SYSTEM_PROMPT },
        ...recentMessages,
    ];

    State.isStreaming = true;
    setStopMode(true);

    let responseText = "";
    let aiNode = null;
    let stopped = false;

    // Fonction d'annulation
    State.abortStreaming = () => {
        stopped = true;
    };

    try {
        const chunks = await State.engine.chat.completions.create({
            messages,
            temperature: 0.7,
            top_p:       0.9,
            stream:      true,
            stream_options: { include_usage: false },
        });

        // Remplacer le thinking node par un vrai nœud de message au premier token
        let firstToken = true;

        for await (const chunk of chunks) {
            if (stopped) break;

            const delta = chunk.choices[0]?.delta?.content || "";
            if (!delta) continue;

            responseText += delta;

            if (firstToken) {
                firstToken = false;
                // Remplacer le thinking indicator
                thinkingNode.remove();
                aiNode = appendMessageNode("assistant", "", true);
            }

            updateAiMessageContent(aiNode, responseText, true);
            scrollToBottomIfNearEnd();
        }

    } catch (err) {
        // Stop demandé ou erreur
        if (!stopped) {
            console.error("Erreur génération :", err);
            showToast("Erreur lors de la génération");
        }
    }

    // Finalisation
    thinkingNode.remove(); // au cas où aucun token

    if (responseText) {
        // Sauvegarder la réponse
        const assistantMsg = { role: "assistant", content: responseText };
        conv.messages.push(assistantMsg);

        if (aiNode) {
            finalizeAiMessage(aiNode, responseText);
        } else {
            // Au cas où aucun token n'aurait été rendu
            const node = appendMessageNode("assistant", responseText, true);
            finalizeAiMessage(node, responseText);
        }

        saveConversationsToStorage();
        renderSidebarConversations();
    } else if (!stopped) {
        showToast("Aucune réponse générée");
    }

    State.isStreaming    = false;
    State.abortStreaming = null;
    setStopMode(false);
    setInputEnabled(true);
    DOM.messageInput.focus();
    scrollToBottom();
}

function stopGeneration() {
    if (State.abortStreaming) {
        State.abortStreaming();
    }
}


// ═══════════════════════════════════════════════════════
// ÉVÉNEMENTS CHAT
// ═══════════════════════════════════════════════════════

function setupChatEvents() {
    // Envoyer avec Enter (Shift+Enter = saut de ligne)
    DOM.messageInput.addEventListener("keydown", (e) => {
        if (e.key === "Enter" && !e.shiftKey) {
            e.preventDefault();
            if (!DOM.sendBtn.disabled) sendMessage();
        }
    });

    // Activer / désactiver le bouton envoyer
    DOM.messageInput.addEventListener("input", () => {
        autoResizeTextarea();
        updateSendBtnState();
    });

    // Bouton envoyer / stop
    DOM.sendBtn.addEventListener("click", () => {
        if (State.isStreaming) {
            stopGeneration();
        } else {
            sendMessage();
        }
    });

    // Nouvelle conversation
    DOM.btnNewChat.addEventListener("click", () => {
        if (State.isStreaming) return;
        newConversation();
    });

    DOM.sidebarNewChat.addEventListener("click", () => {
        if (State.isStreaming) return;
        newConversation();
        closeSidebar();
    });

    // Sidebar
    DOM.btnMenu.addEventListener("click", openSidebar);
    DOM.sidebarClose.addEventListener("click", closeSidebar);
    DOM.sidebarOverlay.addEventListener("click", closeSidebar);

    // Changer de modèle
    // IMPORTANT : engine.unload() libère les buffers WebGPU (RAM/VRAM).
    // Sans ça, chaque changement de modèle accumule de la mémoire jusqu'à saturation.
    DOM.btnChangeModel.addEventListener("click", async () => {
        closeSidebar();
        if (State.engine) {
            try { await State.engine.unload(); } catch (_) {}
            State.engine = null;
            State.loadedModelId = null;
        }
        // Rafraîchit les badges ⚡/☁ avant d'ouvrir le modal
        updateModelCardsCacheStatus();
        openModelModal(true);
    });

    // Suggestions d'accueil
    document.querySelectorAll(".suggestion-chip").forEach((chip) => {
        chip.addEventListener("click", () => {
            const msg = chip.dataset.msg;
            if (msg) {
                DOM.messageInput.value = msg;
                autoResizeTextarea();
                updateSendBtnState();
                sendMessage();
            }
        });
    });

    // Scroll → afficher bouton "retour en bas"
    DOM.chatMain.addEventListener("scroll", onChatScroll);
    createScrollBottomButton();
}

// ─── Sidebar ─────────────────────────────────────────

function openSidebar() {
    DOM.sidebar.classList.add("open");
    DOM.sidebarOverlay.classList.add("visible");
}

function closeSidebar() {
    DOM.sidebar.classList.remove("open");
    DOM.sidebarOverlay.classList.remove("visible");
}

// ─── Sidebar conversations ────────────────────────────

function renderSidebarConversations() {
    const el = DOM.sidebarConversations;
    el.innerHTML = "";

    if (State.conversations.length === 0) {
        el.innerHTML = `<p style="padding:8px 10px;font-size:13px;color:var(--text-muted)">Aucune conversation</p>`;
        return;
    }

    State.conversations.forEach((conv) => {
        const item = document.createElement("div");
        item.className = `conv-item${conv.id === State.activeConvId ? " active" : ""}`;
        item.innerHTML = `
            <span class="conv-item-icon">💬</span>
            <span class="conv-item-label">${escapeHtml(conv.title)}</span>
            <button class="conv-item-delete" title="Supprimer">
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12" stroke-linecap="round"/></svg>
            </button>`;

        item.addEventListener("click", (e) => {
            if (e.target.closest(".conv-item-delete")) {
                e.stopPropagation();
                deleteConversation(conv.id);
                return;
            }
            openConversation(conv.id);
            renderSidebarConversations();
        });

        el.appendChild(item);
    });
}

// ─── Input helpers ────────────────────────────────────

function updateSendBtnState() {
    const hasText = DOM.messageInput.value.trim().length > 0;
    DOM.sendBtn.disabled = !hasText || !State.engine;
}

function setInputEnabled(enabled) {
    DOM.messageInput.disabled = !enabled;
    if (!State.isStreaming) {
        DOM.sendBtn.disabled = !enabled || DOM.messageInput.value.trim().length === 0;
    }
}

function setStopMode(active) {
    if (active) {
        DOM.sendBtn.disabled = false;
        DOM.sendBtn.classList.add("stop-mode");
        DOM.sendBtn.title = "Arrêter la génération";
        DOM.sendBtn.innerHTML = `
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                <rect x="6" y="6" width="12" height="12" rx="2"/>
            </svg>`;
    } else {
        DOM.sendBtn.classList.remove("stop-mode");
        DOM.sendBtn.title = "Envoyer";
        DOM.sendBtn.innerHTML = `
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 4l8 16-8-3.5L4 20z"/>
            </svg>`;
        updateSendBtnState();
    }
}

function autoResizeTextarea() {
    const el = DOM.messageInput;
    el.style.height = "auto";
    el.style.height = Math.min(el.scrollHeight, 160) + "px";
}

// ─── Scroll helpers ───────────────────────────────────

let scrollBottomBtn = null;

function createScrollBottomButton() {
    scrollBottomBtn = document.createElement("button");
    scrollBottomBtn.className = "scroll-bottom-btn";
    scrollBottomBtn.title = "Retour en bas";
    scrollBottomBtn.innerHTML = `
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <path d="M6 9l6 6 6-6" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>`;
    scrollBottomBtn.addEventListener("click", scrollToBottom);
    document.body.appendChild(scrollBottomBtn);
}

function onChatScroll() {
    const el   = DOM.chatMain;
    const near = el.scrollHeight - el.scrollTop - el.clientHeight < 120;
    if (scrollBottomBtn) {
        scrollBottomBtn.classList.toggle("visible", !near);
    }
}

function scrollToBottom() {
    DOM.chatMain.scrollTop = DOM.chatMain.scrollHeight;
    if (scrollBottomBtn) scrollBottomBtn.classList.remove("visible");
}

function scrollToBottomIfNearEnd() {
    const el = DOM.chatMain;
    const nearEnd = el.scrollHeight - el.scrollTop - el.clientHeight < 200;
    if (nearEnd) scrollToBottom();
}


// ═══════════════════════════════════════════════════════
// NAVIGATION ENTRE SCREENS
// ═══════════════════════════════════════════════════════

function showScreen(name) {
    const screens = {
        "loading": DOM.screenLoading,
        "chat":    DOM.screenChat,
    };

    Object.values(screens).forEach(s => s.classList.remove("active"));
    if (screens[name]) screens[name].classList.add("active");
}

// ─── Modal sélection du modèle ────────────────────────

function openModelModal(canClose = false) {
    DOM.modalBackdrop.classList.add("open");
    DOM.modalSheet.classList.add("open");
    DOM.modalClose.style.display = canClose ? "flex" : "none";
    // Backdrop click ferme seulement si on peut fermer
    if (canClose) {
        DOM.modalBackdrop.onclick = closeModelModal;
    } else {
        DOM.modalBackdrop.onclick = null;
    }
}

function closeModelModal() {
    DOM.modalBackdrop.classList.remove("open");
    DOM.modalSheet.classList.remove("open");
}


// ═══════════════════════════════════════════════════════
// GESTION DU CACHE DES MODÈLES
// ═══════════════════════════════════════════════════════

/**
 * Met à jour les badges de statut sur chaque card de modèle :
 *   ⚡ En cache  → modèle présent sur disque, chargement instantané
 *   ☁ À télécharger → premier chargement nécessitera un download
 * Ajoute également un bouton 🗑 pour supprimer un modèle du cache.
 */
async function updateModelCardsCacheStatus() {
    for (const model of MODELS) {
        const card = DOM.modelCards.querySelector(`[data-model="${model.id}"]`);
        if (!card) continue;

        // Vérifier si le modèle est déjà stocké localement
        const cached = await webllm.hasModelInCache(model.id).catch(() => false);

        // Mettre à jour le tag de statut dans .model-card-size
        const sizeEl = card.querySelector(".model-card-size");
        if (sizeEl) {
            sizeEl.innerHTML = `${model.size}&nbsp;<span class="model-cache-tag ${cached ? 'cached' : 'not-cached'}">${cached ? '⚡ En cache' : '☁ À télécharger'}</span>`;
        }

        // Bouton de suppression (seulement si en cache)
        card.querySelector(".model-delete-btn")?.remove();
        if (cached) {
            const deleteBtn = document.createElement("button");
            deleteBtn.className = "model-delete-btn";
            deleteBtn.title = "Supprimer du cache (libère l'espace disque)";
            deleteBtn.innerHTML = `
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polyline points="3 6 5 6 21 6"/>
                    <path d="M19 6l-1 14a2 2 0 01-2 2H8a2 2 0 01-2-2L5 6"/>
                    <path d="M10 11v6M14 11v6"/>
                    <path d="M9 6V4h6v2"/>
                </svg>`;
            deleteBtn.addEventListener("click", (e) => {
                e.stopPropagation(); // Ne pas sélectionner la card
                deleteModelFromCache(model.id);
            });
            card.appendChild(deleteBtn);
        }
    }
}

/**
 * Supprime les fichiers d'un modèle du Cache Storage.
 * Libère l'espace disque occupé (~750 MB à 2.2 GB par modèle).
 * Si le modèle est actuellement chargé, il est d'abord déchargé.
 */
async function deleteModelFromCache(modelId) {
    const modelInfo = MODELS.find(m => m.id === modelId) || { label: modelId };

    // Décharger le modèle s'il est actuellement actif
    if (State.loadedModelId === modelId && State.engine) {
        try { await State.engine.unload(); } catch (_) {}
        State.engine = null;
        State.loadedModelId = null;
    }

    try {
        await webllm.deleteModelAllInfoInCache(modelId);
        showNativeToast(`Cache "${modelInfo.label}" supprimé`, "success");
        // Rafraîchir les badges après suppression
        await updateModelCardsCacheStatus();
    } catch (err) {
        console.error("Erreur suppression cache :", err);
        showNativeToast("Erreur lors de la suppression du cache", "error");
    }
}


// ═══════════════════════════════════════════════════════
// STOCKAGE (Ondes.Storage ou localStorage)
// ═══════════════════════════════════════════════════════

async function saveToStorage(key, value) {
    try {
        const serialized = JSON.stringify(value);
        if (State.useOndesStorage) {
            await Ondes.Storage.set({ key, value: serialized });
        } else {
            localStorage.setItem(key, serialized);
        }
    } catch (err) {
        console.warn("Erreur sauvegarde :", err);
    }
}

async function getFromStorage(key) {
    try {
        if (State.useOndesStorage) {
            const res = await Ondes.Storage.get({ key });
            if (res?.value == null) return null;
            return JSON.parse(res.value);
        } else {
            const raw = localStorage.getItem(key);
            return raw ? JSON.parse(raw) : null;
        }
    } catch {
        return null;
    }
}

async function loadConversationsFromStorage() {
    const convs  = await getFromStorage(STORAGE_KEY_CONVERSATIONS);
    const active = await getFromStorage(STORAGE_KEY_ACTIVE);

    State.conversations = Array.isArray(convs) ? convs : [];
    State.activeConvId  = active || null;
}

async function saveConversationsToStorage() {
    // Limiter le nombre de conversations
    if (State.conversations.length > MAX_CONVERSATIONS) {
        State.conversations = State.conversations.slice(0, MAX_CONVERSATIONS);
    }
    await saveToStorage(STORAGE_KEY_CONVERSATIONS, State.conversations);
    await saveActiveConvToStorage();
}

async function saveActiveConvToStorage() {
    await saveToStorage(STORAGE_KEY_ACTIVE, State.activeConvId);
}


// ═══════════════════════════════════════════════════════
// MARKDOWN RENDERER LÉGER
// ═══════════════════════════════════════════════════════

/**
 * Rendu Markdown minimal, optimisé pour les réponses LLM.
 * Gère : titres, gras, italique, code inline, blocs de code,
 *        listes ul/ol, citations, séparateurs, liens.
 */
function renderMarkdown(raw) {
    if (!raw) return "";

    let text = raw;

    // 1. Code blocks (``` ... ```) — traité avant tout le reste
    const codeBlocks = [];
    text = text.replace(/```(\w*)\n?([\s\S]*?)```/g, (_, lang, code) => {
        const idx = codeBlocks.length;
        codeBlocks.push(`<pre><code class="lang-${escapeHtml(lang)}">${escapeHtml(code.trimEnd())}</code></pre>`);
        return `%%CODEBLOCK_${idx}%%`;
    });

    // 2. Ligne par ligne
    const lines = text.split("\n");
    const output = [];
    let inList = false;
    let listType = null;

    for (let i = 0; i < lines.length; i++) {
        let line = lines[i];

        // Titres
        const h3 = line.match(/^### (.+)/);
        const h2 = line.match(/^## (.+)/);
        const h1 = line.match(/^# (.+)/);

        if (h1) { if (inList) { output.push(closeList(listType)); inList = false; } output.push(`<h1>${inlineMarkdown(h1[1])}</h1>`); continue; }
        if (h2) { if (inList) { output.push(closeList(listType)); inList = false; } output.push(`<h2>${inlineMarkdown(h2[1])}</h2>`); continue; }
        if (h3) { if (inList) { output.push(closeList(listType)); inList = false; } output.push(`<h3>${inlineMarkdown(h3[1])}</h3>`); continue; }

        // Séparateur
        if (/^---+$/.test(line.trim())) {
            if (inList) { output.push(closeList(listType)); inList = false; }
            output.push("<hr>");
            continue;
        }

        // Citation
        const bq = line.match(/^> (.+)/);
        if (bq) {
            if (inList) { output.push(closeList(listType)); inList = false; }
            output.push(`<blockquote>${inlineMarkdown(bq[1])}</blockquote>`);
            continue;
        }

        // Liste non ordonnée
        const ul = line.match(/^[-*+] (.+)/);
        if (ul) {
            if (!inList || listType !== "ul") {
                if (inList) output.push(closeList(listType));
                output.push("<ul>");
                inList = true;
                listType = "ul";
            }
            output.push(`<li>${inlineMarkdown(ul[1])}</li>`);
            continue;
        }

        // Liste ordonnée
        const ol = line.match(/^\d+\. (.+)/);
        if (ol) {
            if (!inList || listType !== "ol") {
                if (inList) output.push(closeList(listType));
                output.push("<ol>");
                inList = true;
                listType = "ol";
            }
            output.push(`<li>${inlineMarkdown(ol[1])}</li>`);
            continue;
        }

        // Fin de liste
        if (inList && line.trim() === "") {
            output.push(closeList(listType));
            inList = false;
            listType = null;
        }

        // Ligne vide → break
        if (line.trim() === "") {
            output.push("<br>");
            continue;
        }

        // Paragraphe
        output.push(`<p>${inlineMarkdown(line)}</p>`);
    }

    if (inList) output.push(closeList(listType));

    let result = output.join("");

    // Réinjecter les blocs de code
    codeBlocks.forEach((block, idx) => {
        result = result.replace(`%%CODEBLOCK_${idx}%%`, block);
    });

    // Nettoyer les <br> superflus en début / fin
    result = result.replace(/^(<br>)+/, "").replace(/(<br>)+$/, "");

    return result;
}

function closeList(type) {
    return type === "ol" ? "</ol>" : "</ul>";
}

/**
 * Rendu Markdown inline : gras, italique, code, liens.
 */
function inlineMarkdown(text) {
    return escapeHtmlPartial(text)
        // Code inline
        .replace(/`([^`]+)`/g, "<code>$1</code>")
        // Gras
        .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
        .replace(/__([^_]+)__/g, "<strong>$1</strong>")
        // Italique
        .replace(/\*([^*]+)\*/g, "<em>$1</em>")
        .replace(/_([^_]+)_/g, "<em>$1</em>")
        // Liens
        .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>');
}

function escapeHtml(str) {
    return String(str)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
}

/** Échappe < > & mais pas les apostrophes/guillemets (pour inline Markdown) */
function escapeHtmlPartial(str) {
    return String(str)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;");
}


// ═══════════════════════════════════════════════════════
// TOASTS (natifs Ondes ou fallback custom)
// ═══════════════════════════════════════════════════════

function showNativeToast(message, type = "info") {
    if (State.useOndesStorage && window.Ondes?.UI?.showToast) {
        Ondes.UI.showToast({ message, type, duration: 2500 });
    } else {
        showToast(message);
    }
}

let toastTimeout = null;

function showToast(message) {
    let toast = document.querySelector(".toast");
    if (!toast) {
        toast = document.createElement("div");
        toast.className = "toast";
        document.body.appendChild(toast);
    }

    toast.textContent = message;
    toast.classList.add("show");

    if (toastTimeout) clearTimeout(toastTimeout);
    toastTimeout = setTimeout(() => {
        toast.classList.remove("show");
    }, 2500);
}


// ═══════════════════════════════════════════════════════
// UTILITAIRES
// ═══════════════════════════════════════════════════════

function genId() {
    return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}
