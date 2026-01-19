const String ondesBridgeJs = """
(function() {
    console.log("🌊 Injecting Ondes Core Bridge v2.1...");

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
        }
    };

    // Event ready
    const event = new Event('OndesReady');
    document.dispatchEvent(event);
    console.log("✅ Ondes Core Bridge v2.1 Ready !");
})();
""";
