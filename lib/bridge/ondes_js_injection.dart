const String ondesBridgeJs = """
(function() {
    console.log("🌊 Injecting Ondes Core Bridge v2.5...");

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
            list: async function() {
                return await callBridge('Ondes.Friends.list');
            },
            request: async function(options) {
                return await callBridge('Ondes.Friends.request', options);
            },
            getPendingRequests: async function() {
                return await callBridge('Ondes.Friends.getPendingRequests');
            },
            getSentRequests: async function() {
                return await callBridge('Ondes.Friends.getSentRequests');
            },
            accept: async function(friendshipId) {
                return await callBridge('Ondes.Friends.accept', friendshipId);
            },
            reject: async function(friendshipId) {
                return await callBridge('Ondes.Friends.reject', friendshipId);
            },
            remove: async function(friendshipId) {
                return await callBridge('Ondes.Friends.remove', friendshipId);
            },
            block: async function(options) {
                return await callBridge('Ondes.Friends.block', options);
            },
            unblock: async function(userId) {
                return await callBridge('Ondes.Friends.unblock', userId);
            },
            getBlocked: async function() {
                return await callBridge('Ondes.Friends.getBlocked');
            },
            search: async function(query) {
                return await callBridge('Ondes.Friends.search', query);
            },
            getPendingCount: async function() {
                return await callBridge('Ondes.Friends.getPendingCount');
            }
        },

        // ============== 7. Social ==============
        Social: {
            // ========== FOLLOW ==========
            /**
             * Suivre un utilisateur
             * @param {Object} options - { username: string } ou { userId: number }
             * @returns {Promise<{success, message, follow}>}
             */
            follow: async function(options) {
                if (typeof options === 'string') {
                    options = { username: options };
                } else if (typeof options === 'number') {
                    options = { userId: options };
                }
                return await callBridge('Ondes.Social.follow', options);
            },

            /**
             * Ne plus suivre un utilisateur
             * @param {Object} options - { username: string } ou { userId: number }
             * @returns {Promise<{success, message}>}
             */
            unfollow: async function(options) {
                if (typeof options === 'string') {
                    options = { username: options };
                } else if (typeof options === 'number') {
                    options = { userId: options };
                }
                return await callBridge('Ondes.Social.unfollow', options);
            },

            /**
             * Récupérer les followers d'un utilisateur
             * @param {number} userId - ID de l'utilisateur (optionnel, défaut: utilisateur courant)
             * @returns {Promise<Array<User>>}
             */
            getFollowers: async function(userId) {
                return await callBridge('Ondes.Social.getFollowers', userId);
            },

            /**
             * Récupérer les utilisateurs suivis
             * @param {number} userId - ID de l'utilisateur (optionnel, défaut: utilisateur courant)
             * @returns {Promise<Array<User>>}
             */
            getFollowing: async function(userId) {
                return await callBridge('Ondes.Social.getFollowing', userId);
            },

            // ========== POSTS ==========
            /**
             * Publier un nouveau post
             * @param {Object} options - { content, media, visibility, tags, latitude, longitude, locationName }
             * @returns {Promise<Post>}
             */
            publish: async function(options) {
                return await callBridge('Ondes.Social.publish', options);
            },

            /**
             * Récupérer le feed personnalisé
             * @param {Object} options - { limit, offset, type: 'main'|'discover'|'video' }
             * @returns {Promise<Array<Post>>}
             */
            getFeed: async function(options) {
                return await callBridge('Ondes.Social.getFeed', options || {});
            },

            /**
             * Récupérer un post spécifique
             * @param {string} postUuid - UUID du post
             * @returns {Promise<Post>}
             */
            getPost: async function(postUuid) {
                return await callBridge('Ondes.Social.getPost', postUuid);
            },

            /**
             * Supprimer un post
             * @param {string} postUuid - UUID du post
             * @returns {Promise<{success}>}
             */
            deletePost: async function(postUuid) {
                return await callBridge('Ondes.Social.deletePost', postUuid);
            },

            /**
             * Récupérer les posts d'un utilisateur
             * @param {number} userId - ID de l'utilisateur
             * @param {Object} options - { limit, offset }
             * @returns {Promise<Array<Post>>}
             */
            getUserPosts: async function(userId, options) {
                return await callBridge('Ondes.Social.getUserPosts', userId, options || {});
            },

            // ========== LIKES ==========
            /**
             * Liker un post
             * @param {string} postUuid - UUID du post
             * @returns {Promise<{success, liked, likesCount}>}
             */
            likePost: async function(postUuid) {
                return await callBridge('Ondes.Social.likePost', postUuid);
            },

            /**
             * Retirer le like d'un post
             * @param {string} postUuid - UUID du post
             * @returns {Promise<{success, liked, likesCount}>}
             */
            unlikePost: async function(postUuid) {
                return await callBridge('Ondes.Social.unlikePost', postUuid);
            },

            /**
             * Récupérer les utilisateurs qui ont liké un post
             * @param {string} postUuid - UUID du post
             * @returns {Promise<Array<User>>}
             */
            getPostLikers: async function(postUuid) {
                return await callBridge('Ondes.Social.getPostLikers', postUuid);
            },

            // ========== COMMENTS ==========
            /**
             * Ajouter un commentaire à un post
             * @param {string} postUuid - UUID du post
             * @param {string} content - Contenu du commentaire
             * @param {string} parentUuid - UUID du commentaire parent (pour les réponses)
             * @returns {Promise<Comment>}
             */
            addComment: async function(postUuid, content, parentUuid) {
                return await callBridge('Ondes.Social.addComment', postUuid, content, parentUuid);
            },

            /**
             * Récupérer les commentaires d'un post
             * @param {string} postUuid - UUID du post
             * @param {Object} options - { limit, offset }
             * @returns {Promise<Array<Comment>>}
             */
            getComments: async function(postUuid, options) {
                return await callBridge('Ondes.Social.getComments', postUuid, options || {});
            },

            /**
             * Récupérer les réponses à un commentaire
             * @param {string} commentUuid - UUID du commentaire
             * @returns {Promise<Array<Comment>>}
             */
            getCommentReplies: async function(commentUuid) {
                return await callBridge('Ondes.Social.getCommentReplies', commentUuid);
            },

            /**
             * Supprimer un commentaire
             * @param {string} commentUuid - UUID du commentaire
             * @returns {Promise<{success}>}
             */
            deleteComment: async function(commentUuid) {
                return await callBridge('Ondes.Social.deleteComment', commentUuid);
            },

            /**
             * Liker un commentaire
             * @param {string} commentUuid - UUID du commentaire
             * @returns {Promise<{success, liked, likesCount}>}
             */
            likeComment: async function(commentUuid) {
                return await callBridge('Ondes.Social.likeComment', commentUuid);
            },

            // ========== BOOKMARKS ==========
            /**
             * Sauvegarder un post
             * @param {string} postUuid - UUID du post
             * @returns {Promise<{success, bookmarked}>}
             */
            bookmarkPost: async function(postUuid) {
                return await callBridge('Ondes.Social.bookmarkPost', postUuid);
            },

            /**
             * Retirer un post des favoris
             * @param {string} postUuid - UUID du post
             * @returns {Promise<{success, bookmarked}>}
             */
            unbookmarkPost: async function(postUuid) {
                return await callBridge('Ondes.Social.unbookmarkPost', postUuid);
            },

            /**
             * Récupérer les posts sauvegardés
             * @param {Object} options - { limit, offset }
             * @returns {Promise<Array<Post>>}
             */
            getBookmarks: async function(options) {
                return await callBridge('Ondes.Social.getBookmarks', options || {});
            },

            // ========== STORIES ==========
            /**
             * Créer une story
             * @param {string} mediaPath - Chemin vers le média
             * @param {number} duration - Durée d'affichage en secondes (défaut: 5)
             * @returns {Promise<Story>}
             */
            createStory: async function(mediaPath, duration) {
                return await callBridge('Ondes.Social.createStory', mediaPath, duration || 5);
            },

            /**
             * Récupérer les stories des utilisateurs suivis
             * @returns {Promise<Array<{user, stories, hasUnviewed}>>}
             */
            getStories: async function() {
                return await callBridge('Ondes.Social.getStories');
            },

            /**
             * Marquer une story comme vue
             * @param {string} storyUuid - UUID de la story
             * @returns {Promise<{success, viewsCount}>}
             */
            viewStory: async function(storyUuid) {
                return await callBridge('Ondes.Social.viewStory', storyUuid);
            },

            /**
             * Supprimer une story
             * @param {string} storyUuid - UUID de la story
             * @returns {Promise<{success}>}
             */
            deleteStory: async function(storyUuid) {
                return await callBridge('Ondes.Social.deleteStory', storyUuid);
            },

            // ========== PROFILE ==========
            /**
             * Récupérer le profil social d'un utilisateur
             * @param {Object} options - { userId, username } (optionnel, défaut: utilisateur courant)
             * @returns {Promise<UserProfile>}
             */
            getProfile: async function(options) {
                return await callBridge('Ondes.Social.getProfile', options || {});
            },

            /**
             * Rechercher des utilisateurs
             * @param {string} query - Terme de recherche (min 2 caractères)
             * @returns {Promise<Array<User>>}
             */
            searchUsers: async function(query) {
                return await callBridge('Ondes.Social.searchUsers', query);
            },

            // ========== MEDIA ==========
            /**
             * Ouvrir le sélecteur de média natif
             * @param {Object} options - { type: 'image'|'video'|'both', multiple: boolean }
             * @returns {Promise<{success, paths, count}>}
             */
            pickMedia: async function(options) {
                return await callBridge('Ondes.Social.pickMedia', options || {});
            }
        },

        // ============== 8. Websocket ==============
        Websocket: {
            // Internal handlers storage
            _handlers: {},
            // Polling intervals per connection
            _pollingIntervals: {},

            /**
             * Connect to a WebSocket server
             * @param {string} url - WebSocket URL (ws:// or wss://)
             * @param {Object} options - Connection options
             * @param {boolean} options.reconnect - Auto-reconnect on disconnect (default: false)
             * @param {number} options.timeout - Connection timeout in ms (default: 10000)
             * @returns {Promise<{id, url, status, connectedAt}>}
             */
            connect: async function(url, options) {
                const result = await callBridge('Ondes.Websocket.connect', url, options || {});
                // Initialize handlers storage for this connection
                if (result && result.id) {
                    this._handlers[result.id] = {
                        onMessage: [],
                        onStatusChange: []
                    };
                    // Start polling for this connection
                    this._startPolling(result.id);
                }
                return result;
            },

            /**
             * Disconnect from a WebSocket server
             * @param {string} connectionId - The connection ID returned by connect()
             * @returns {Promise<{success, id}>}
             */
            disconnect: async function(connectionId) {
                // Stop polling first
                this._stopPolling(connectionId);
                const result = await callBridge('Ondes.Websocket.disconnect', connectionId);
                // Clean up handlers
                if (this._handlers[connectionId]) {
                    delete this._handlers[connectionId];
                }
                return result;
            },

            /**
             * Send a message through a WebSocket connection
             * @param {string} connectionId - The connection ID
             * @param {string|Object} data - Data to send (objects will be JSON-stringified)
             * @returns {Promise<{success, id}>}
             */
            send: async function(connectionId, data) {
                return await callBridge('Ondes.Websocket.send', connectionId, data);
            },

            /**
             * Get the status of a WebSocket connection
             * @param {string} connectionId - The connection ID
             * @returns {Promise<{id, url, status, exists, connectedAt, reconnect}>}
             */
            getStatus: async function(connectionId) {
                return await callBridge('Ondes.Websocket.getStatus', connectionId);
            },

            /**
             * List all active WebSocket connections
             * @returns {Promise<Array<{id, url, status, connectedAt}>>}
             */
            list: async function() {
                return await callBridge('Ondes.Websocket.list');
            },

            /**
             * Disconnect all WebSocket connections
             * @returns {Promise<{success, disconnected}>}
             */
            disconnectAll: async function() {
                // Stop all polling
                for (const id in this._pollingIntervals) {
                    this._stopPolling(id);
                }
                const result = await callBridge('Ondes.Websocket.disconnectAll');
                this._handlers = {};
                return result;
            },

            /**
             * Start polling for messages and status changes
             * @private
             */
            _startPolling: function(connectionId) {
                if (this._pollingIntervals[connectionId]) return;
                
                const poll = async () => {
                    try {
                        // Poll for messages
                        const msgResult = await callBridge('Ondes.Websocket.pollMessages', connectionId);
                        if (msgResult && msgResult.messages && msgResult.messages.length > 0) {
                            const handlers = this._handlers[connectionId];
                            if (handlers && handlers.onMessage) {
                                for (const msg of msgResult.messages) {
                                    handlers.onMessage.forEach(cb => {
                                        try { cb(msg.message); } catch(e) { console.error('Ondes.Websocket callback error:', e); }
                                    });
                                }
                            }
                        }
                        
                        // Poll for status changes
                        const statusResult = await callBridge('Ondes.Websocket.pollStatus', connectionId);
                        if (statusResult && statusResult.statusChanges && statusResult.statusChanges.length > 0) {
                            const handlers = this._handlers[connectionId];
                            if (handlers && handlers.onStatusChange) {
                                for (const change of statusResult.statusChanges) {
                                    handlers.onStatusChange.forEach(cb => {
                                        try { cb(change.status, change.error); } catch(e) { console.error('Ondes.Websocket status callback error:', e); }
                                    });
                                }
                            }
                        }
                    } catch (e) {
                        // Connection may be closed, stop polling
                        console.log('[Ondes.Websocket] Polling stopped for ' + connectionId);
                        this._stopPolling(connectionId);
                    }
                };
                
                // Poll every 50ms for responsiveness
                this._pollingIntervals[connectionId] = setInterval(poll, 50);
                // Also poll immediately
                poll();
            },

            /**
             * Stop polling for a connection
             * @private
             */
            _stopPolling: function(connectionId) {
                if (this._pollingIntervals[connectionId]) {
                    clearInterval(this._pollingIntervals[connectionId]);
                    delete this._pollingIntervals[connectionId];
                }
            },

            /**
             * Poll for pending messages (public API for SDK)
             * @param {string} connectionId - The connection ID
             * @returns {Promise<{connectionId, messages}>}
             */
            pollMessages: async function(connectionId) {
                return await callBridge('Ondes.Websocket.pollMessages', connectionId);
            },

            /**
             * Poll for pending status changes (public API for SDK)
             * @param {string} connectionId - The connection ID
             * @returns {Promise<{connectionId, statusChanges}>}
             */
            pollStatus: async function(connectionId) {
                return await callBridge('Ondes.Websocket.pollStatus', connectionId);
            },

            /**
             * Register a callback for incoming messages
             * @param {string} connectionId - The connection ID
             * @param {Function} callback - Function called with (message) on each message
             * @returns {Function} Unsubscribe function
             */
            onMessage: function(connectionId, callback) {
                if (!this._handlers[connectionId]) {
                    this._handlers[connectionId] = { onMessage: [], onStatusChange: [] };
                    // Start polling if not already
                    this._startPolling(connectionId);
                }
                this._handlers[connectionId].onMessage.push(callback);
                
                // Return unsubscribe function
                return () => {
                    const handlers = this._handlers[connectionId];
                    if (handlers) {
                        const index = handlers.onMessage.indexOf(callback);
                        if (index > -1) handlers.onMessage.splice(index, 1);
                    }
                };
            },

            /**
             * Register a callback for connection status changes
             * @param {string} connectionId - The connection ID
             * @param {Function} callback - Function called with (status, error) on status change
             * @returns {Function} Unsubscribe function
             */
            onStatusChange: function(connectionId, callback) {
                if (!this._handlers[connectionId]) {
                    this._handlers[connectionId] = { onMessage: [], onStatusChange: [] };
                    // Start polling if not already
                    this._startPolling(connectionId);
                }
                this._handlers[connectionId].onStatusChange.push(callback);
                
                // Return unsubscribe function
                return () => {
                    const handlers = this._handlers[connectionId];
                    if (handlers) {
                        const index = handlers.onStatusChange.indexOf(callback);
                        if (index > -1) handlers.onStatusChange.splice(index, 1);
                    }
                };
            }
        },

        // ============== 9. UDP ==============
        UDP: {
            // Internal handlers storage
            _handlers: {},

            /**
             * Bind to a UDP port and start listening
             * @param {Object} options - Bind options
             * @param {number} options.port - Port to bind (0 for random)
             * @param {boolean} options.broadcast - Enable broadcast (default: true)
             * @param {boolean} options.reuseAddress - Allow address reuse (default: true)
             * @returns {Promise<{id, port, broadcast, status}>}
             */
            bind: async function(options) {
                const result = await callBridge('Ondes.UDP.bind', options || {});
                if (result && result.id) {
                    this._handlers[result.id] = {
                        onMessage: [],
                        onClose: []
                    };
                }
                return result;
            },

            /**
             * Send a UDP message to a specific address and port
             * @param {string} socketId - The socket ID returned by bind()
             * @param {string} message - Message to send
             * @param {string} address - Target IP address
             * @param {number} port - Target port
             * @returns {Promise<{success, bytesSent, address, port}>}
             */
            send: async function(socketId, message, address, port) {
                return await callBridge('Ondes.UDP.send', socketId, message, address, port);
            },

            /**
             * Broadcast a UDP message to multiple addresses
             * @param {string} socketId - The socket ID
             * @param {string} message - Message to send
             * @param {Array<string>} addresses - List of target IP addresses
             * @param {number} port - Target port (default: 12345)
             * @returns {Promise<{socketId, messageLength, port, results}>}
             */
            broadcast: async function(socketId, message, addresses, port) {
                return await callBridge('Ondes.UDP.broadcast', socketId, message, addresses, port || 12345);
            },

            /**
             * Close a UDP socket
             * @param {string} socketId - The socket ID
             * @returns {Promise<{id, status}>}
             */
            close: async function(socketId) {
                const result = await callBridge('Ondes.UDP.close', socketId);
                if (this._handlers[socketId]) {
                    delete this._handlers[socketId];
                }
                return result;
            },

            /**
             * Get info about a UDP socket
             * @param {string} socketId - The socket ID
             * @returns {Promise<{id, port, broadcast, createdAt, messagesReceived}>}
             */
            getInfo: async function(socketId) {
                return await callBridge('Ondes.UDP.getInfo', socketId);
            },

            /**
             * List all active UDP sockets
             * @returns {Promise<Array<{id, port, broadcast, createdAt, messagesReceived}>>}
             */
            list: async function() {
                return await callBridge('Ondes.UDP.list');
            },

            /**
             * Close all UDP sockets
             * @returns {Promise<{closedCount}>}
             */
            closeAll: async function() {
                const result = await callBridge('Ondes.UDP.closeAll');
                this._handlers = {};
                return result;
            },

            /**
             * Register a callback for incoming UDP messages
             * @param {string} socketId - The socket ID
             * @param {Function} callback - Function called with ({socketId, message, data, address, port, timestamp})
             * @returns {Function} Unsubscribe function
             */
            onMessage: function(socketId, callback) {
                if (!this._handlers[socketId]) {
                    this._handlers[socketId] = { onMessage: [], onClose: [] };
                }
                this._handlers[socketId].onMessage.push(callback);
                
                return () => {
                    const handlers = this._handlers[socketId];
                    if (handlers) {
                        const index = handlers.onMessage.indexOf(callback);
                        if (index > -1) handlers.onMessage.splice(index, 1);
                    }
                };
            },

            /**
             * Register a callback for socket close events
             * @param {string} socketId - The socket ID
             * @param {Function} callback - Function called with ({socketId, timestamp})
             * @returns {Function} Unsubscribe function
             */
            onClose: function(socketId, callback) {
                if (!this._handlers[socketId]) {
                    this._handlers[socketId] = { onMessage: [], onClose: [] };
                }
                this._handlers[socketId].onClose.push(callback);
                
                return () => {
                    const handlers = this._handlers[socketId];
                    if (handlers) {
                        const index = handlers.onClose.indexOf(callback);
                        if (index > -1) handlers.onClose.splice(index, 1);
                    }
                };
            },

            // Internal method called by native side
            _onMessage: function(data) {
                const handlers = this._handlers[data.socketId];
                if (handlers) {
                    handlers.onMessage.forEach(cb => {
                        try { cb(data); } catch(e) { console.error('[Ondes.UDP] onMessage error:', e); }
                    });
                }
            },

            // Internal method called by native side
            _onClose: function(data) {
                const handlers = this._handlers[data.socketId];
                if (handlers) {
                    handlers.onClose.forEach(cb => {
                        try { cb(data); } catch(e) { console.error('[Ondes.UDP] onClose error:', e); }
                    });
                    delete this._handlers[data.socketId];
                }
            }
        }
    };

    // Event ready
    const event = new Event('OndesReady');
    document.dispatchEvent(event);
    console.log("✅ Ondes Core Bridge v2.3 Ready !");
})();
""";
