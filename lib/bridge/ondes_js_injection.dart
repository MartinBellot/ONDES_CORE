const String ondesBridgeJs = """
(function() {
    console.log("🌊 Injecting Ondes Core Bridge v2.0...");

    if (window.Ondes) return; // Already injected

    // Helper function for API calls with error handling
    const callBridge = async (handlerName, ...args) => {
        try {
            return await window.flutter_inappwebview.callHandler(handlerName, ...args);
        } catch (error) {
            console.error('[Ondes Bridge] ' + handlerName + ' failed:', error);
            throw error;
        }
    };

    window.Ondes = {
        // ============== 1. UI ==============
        UI: {
            showToast: async function(options) {
                return await callBridge('Ondes.UI.showToast', options);
            },
            configureAppBar: async function(options) {
                return await callBridge('Ondes.UI.configureAppBar', options);
            },
            showAlert: async function(options) {
                return await callBridge('Ondes.UI.showAlert', options);
            },
            showConfirm: async function(options) {
                return await callBridge('Ondes.UI.showConfirm', options);
            },
            showBottomSheet: async function(options) {
                return await callBridge('Ondes.UI.showBottomSheet', options);
            }
        },

        // ============== 2. User ==============
        User: {
            getProfile: async function() {
                return await callBridge('Ondes.User.getProfile');
            },
            getAuthToken: async function() {
                return await callBridge('Ondes.User.getAuthToken');
            },
            isAuthenticated: async function() {
                return await callBridge('Ondes.User.isAuthenticated');
            }
        },

        // ============== 3. Device ==============
        Device: {
            hapticFeedback: async function(style) {
                return await callBridge('Ondes.Device.hapticFeedback', style);
            },
            vibrate: async function(duration) {
                return await callBridge('Ondes.Device.vibrate', duration);
            },
            scanQRCode: async function() {
                return await callBridge('Ondes.Device.scanQRCode');
            },
            getGPSPosition: async function() {
                return await callBridge('Ondes.Device.getGPSPosition');
            },
            getInfo: async function() {
                return await callBridge('Ondes.Device.getInfo');
            }
        },

        // ============== 4. Storage ==============
        Storage: {
            set: async function(key, value) {
                return await callBridge('Ondes.Storage.set', [key, value]);
            },
            get: async function(key) {
                return await callBridge('Ondes.Storage.get', key);
            },
            remove: async function(key) {
                return await callBridge('Ondes.Storage.remove', key);
            },
            clear: async function() {
                return await callBridge('Ondes.Storage.clear');
            },
            getKeys: async function() {
                return await callBridge('Ondes.Storage.getKeys');
            }
        },

        // ============== 5. App ==============
        App: {
            getInfo: async function() {
                return await callBridge('Ondes.App.getInfo');
            },
            close: async function() {
                return await callBridge('Ondes.App.close');
            },
            getManifest: async function() {
                return await callBridge('Ondes.App.getManifest');
            }
        },

        // ============== 6. Friends ==============
        Friends: {
            /**
             * Récupère la liste des amis
             * @returns {Promise<Array<{id, username, avatar, bio, friendshipId, friendsSince}>>}
             */
            list: async function() {
                return await callBridge('Ondes.Friends.list');
            },

            /**
             * Envoie une demande d'amitié
             * @param {Object} options - { username: string } ou { userId: number }
             * @returns {Promise<{id, status, toUser, createdAt}>}
             */
            request: async function(options) {
                return await callBridge('Ondes.Friends.request', options);
            },

            /**
             * Récupère les demandes d'amitié reçues en attente
             * @returns {Promise<Array<{id, fromUser, status, createdAt}>>}
             */
            getPendingRequests: async function() {
                return await callBridge('Ondes.Friends.getPendingRequests');
            },

            /**
             * Récupère les demandes d'amitié envoyées
             * @returns {Promise<Array<{id, toUser, status, createdAt}>>}
             */
            getSentRequests: async function() {
                return await callBridge('Ondes.Friends.getSentRequests');
            },

            /**
             * Accepte une demande d'amitié
             * @param {number} friendshipId - ID de la demande
             * @returns {Promise<{success, friendship}>}
             */
            accept: async function(friendshipId) {
                return await callBridge('Ondes.Friends.accept', friendshipId);
            },

            /**
             * Refuse une demande d'amitié
             * @param {number} friendshipId - ID de la demande
             * @returns {Promise<{success}>}
             */
            reject: async function(friendshipId) {
                return await callBridge('Ondes.Friends.reject', friendshipId);
            },

            /**
             * Supprime un ami
             * @param {number} friendshipId - ID de l'amitié
             * @returns {Promise<{success}>}
             */
            remove: async function(friendshipId) {
                return await callBridge('Ondes.Friends.remove', friendshipId);
            },

            /**
             * Bloque un utilisateur
             * @param {Object} options - { username: string } ou { userId: number }
             * @returns {Promise<{success}>}
             */
            block: async function(options) {
                return await callBridge('Ondes.Friends.block', options);
            },

            /**
             * Débloque un utilisateur
             * @param {number} userId - ID de l'utilisateur
             * @returns {Promise<{success}>}
             */
            unblock: async function(userId) {
                return await callBridge('Ondes.Friends.unblock', userId);
            },

            /**
             * Récupère la liste des utilisateurs bloqués
             * @returns {Promise<Array<{id, user, blockedAt}>>}
             */
            getBlocked: async function() {
                return await callBridge('Ondes.Friends.getBlocked');
            },

            /**
             * Recherche des utilisateurs
             * @param {string} query - Recherche (min 2 caractères)
             * @returns {Promise<Array<{id, username, avatar, bio, friendshipStatus, friendshipId}>>}
             */
            search: async function(query) {
                return await callBridge('Ondes.Friends.search', query);
            },

            /**
             * Compte le nombre de demandes en attente
             * @returns {Promise<number>}
             */
            getPendingCount: async function() {
                return await callBridge('Ondes.Friends.getPendingCount');
            }
        }
    };

    // Event ready
    const event = new Event('OndesReady');
    document.dispatchEvent(event);
    console.log("✅ Ondes Core Bridge v2.0 Ready");
})();
""";
