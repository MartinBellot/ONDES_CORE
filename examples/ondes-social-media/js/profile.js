/**
 * Ondes Social — Profile Manager
 * Own profile + other user profiles
 */

const ProfileManager = {
    state: {
        profile: null,
        userPosts: [],
        bookmarks: [],
        postsOffset: 0,
        bookmarksOffset: 0,
        currentTab: 'posts',
        // Other user modal
        viewedUser: null,
        viewedUserPosts: [],
        viewedUserOffset: 0,
    },

    /** Load and render own profile */
    async load() {
        const header = document.getElementById('profileHeader');
        const grid = document.getElementById('profilePostsGrid');
        if (!header || !grid) return;

        try {
            this.state.profile = App.state.currentUser;
            this._renderHeader(header, this.state.profile);
            await this._loadPosts(grid, true);
        } catch (e) {
            console.error('[Profile] load:', e);
        }
    },

    _renderHeader(container, user) {
        const avatar = getAvatar(user);
        container.innerHTML = `
            <div class="profile-info-section">
                <div class="profile-avatar-section">
                    <img class="avatar avatar-2xl" src="${avatar}" alt="${user.username}"
                         onerror="this.src='${defaultAvatar(user.username)}'">
                </div>
                <div class="profile-stats">
                    <div class="stat">
                        <span class="stat-count">${formatCount(user.posts_count || 0)}</span>
                        <span class="stat-label">Posts</span>
                    </div>
                    <div class="stat" data-action="followers">
                        <span class="stat-count">${formatCount(user.followers_count || 0)}</span>
                        <span class="stat-label">Abonnés</span>
                    </div>
                    <div class="stat" data-action="following">
                        <span class="stat-count">${formatCount(user.following_count || 0)}</span>
                        <span class="stat-label">Abonnements</span>
                    </div>
                </div>
            </div>
            <div class="profile-bio">
                <h2 class="profile-name">${user.first_name || user.username}</h2>
                ${user.bio ? `<p class="profile-bio-text">${user.bio}</p>` : ''}
            </div>
            <div class="profile-actions-row">
                <button class="btn btn-secondary btn-block" id="editProfileBtn">Modifier le profil</button>
                <button class="btn btn-secondary btn-icon" id="shareProfileBtn">${icon('share')}</button>
            </div>
        `;
    },

    async _loadPosts(container, fresh = false) {
        if (fresh) {
            this.state.postsOffset = 0;
            this.state.userPosts = [];
            container.innerHTML = '';
        }

        try {
            const userId = this.state.profile?.id;
            const response = await API.getUserPosts(userId, 30, this.state.postsOffset);
            const posts = response.posts || [];
            this.state.userPosts.push(...posts);
            this.state.postsOffset += posts.length;

            if (this.state.userPosts.length === 0 && fresh) {
                container.innerHTML = `
                    <div class="empty-state grid-empty">
                        ${icon('image')}
                        <h3>Aucun post</h3>
                        <p>Partagez votre premier moment</p>
                    </div>
                `;
                return;
            }

            posts.forEach(post => {
                container.appendChild(PostRenderer.renderProfileGridItem(post));
            });
        } catch (e) {
            console.error('[Profile] loadPosts:', e);
        }
    },

    async _loadBookmarks() {
        const container = document.getElementById('profileBookmarksGrid');
        if (!container) return;

        if (this.state.bookmarks.length === 0) {
            container.innerHTML = '<div class="feed-loading"><div class="spinner"></div></div>';
        }

        try {
            const response = await API.getBookmarks(30, this.state.bookmarksOffset);
            const posts = response.posts || [];
            this.state.bookmarks.push(...posts);
            this.state.bookmarksOffset += posts.length;

            if (this.state.bookmarks.length === 0) {
                container.innerHTML = `
                    <div class="empty-state grid-empty">
                        ${icon('bookmark')}
                        <h3>Aucun favori</h3>
                        <p>Enregistrez des posts pour les retrouver ici</p>
                    </div>
                `;
                return;
            }

            container.innerHTML = '';
            this.state.bookmarks.forEach(post => {
                container.appendChild(PostRenderer.renderProfileGridItem(post));
            });
        } catch (e) {
            console.error('[Profile] loadBookmarks:', e);
            container.innerHTML = '<div class="empty-state"><p>Erreur de chargement</p></div>';
        }
    },

    switchTab(tab) {
        this.state.currentTab = tab;

        document.querySelectorAll('.profile-tab').forEach(btn => {
            btn.classList.toggle('active', btn.dataset.tab === tab);
        });

        const postsGrid = document.getElementById('profilePostsGrid');
        const bookmarksGrid = document.getElementById('profileBookmarksGrid');

        if (tab === 'posts') {
            postsGrid.style.display = 'grid';
            bookmarksGrid.style.display = 'none';
        } else {
            postsGrid.style.display = 'none';
            bookmarksGrid.style.display = 'grid';
            if (this.state.bookmarks.length === 0) {
                this._loadBookmarks();
            }
        }
    },

    /** Open another user's profile in a modal */
    async openUser(userId) {
        const modal = document.getElementById('userProfileModal');
        const content = document.getElementById('userProfileContent');
        if (!modal || !content) return;

        modal.classList.add('active');
        content.innerHTML = '<div class="feed-loading"><div class="spinner"></div></div>';

        this.state.viewedUser = null;
        this.state.viewedUserPosts = [];
        this.state.viewedUserOffset = 0;

        try {
            const user = await API.getUserProfile(userId);
            this.state.viewedUser = user;
            this._renderUserProfile(content, user);

            // Update modal title
            const title = document.getElementById('userProfileTitle');
            if (title) title.textContent = user.username || 'Profil';

            // Load posts
            const postsResponse = await API.getUserPosts(userId, 30, 0);
            const posts = postsResponse.posts || [];
            this.state.viewedUserPosts = posts;
            this.state.viewedUserOffset = posts.length;

            const grid = content.querySelector('.user-profile-grid');
            if (grid) {
                if (posts.length === 0) {
                    grid.innerHTML = `
                        <div class="empty-state grid-empty">
                            ${icon('image')}
                            <p>Aucun post</p>
                        </div>
                    `;
                } else {
                    posts.forEach(post => {
                        grid.appendChild(PostRenderer.renderProfileGridItem(post));
                    });
                }
            }
        } catch (e) {
            console.error('[Profile] openUser:', e);
            content.innerHTML = '<div class="empty-state"><p>Profil introuvable</p></div>';
        }
    },

    _renderUserProfile(container, user) {
        const avatar = getAvatar(user);
        const isMe = user.id === App.state.currentUser?.id;

        container.innerHTML = `
            <div class="user-profile-header">
                <div class="profile-info-section">
                    <div class="profile-avatar-section">
                        <img class="avatar avatar-2xl" src="${avatar}" alt="${user.username}"
                             onerror="this.src='${defaultAvatar(user.username)}'">
                    </div>
                    <div class="profile-stats">
                        <div class="stat">
                            <span class="stat-count">${formatCount(user.posts_count || 0)}</span>
                            <span class="stat-label">Posts</span>
                        </div>
                        <div class="stat">
                            <span class="stat-count">${formatCount(user.followers_count || 0)}</span>
                            <span class="stat-label">Abonnés</span>
                        </div>
                        <div class="stat">
                            <span class="stat-count">${formatCount(user.following_count || 0)}</span>
                            <span class="stat-label">Abonnements</span>
                        </div>
                    </div>
                </div>
                <div class="profile-bio">
                    <h2 class="profile-name">${user.first_name || user.username}</h2>
                    ${user.bio ? `<p class="profile-bio-text">${user.bio}</p>` : ''}
                </div>
                ${!isMe ? `
                    <div class="profile-actions-row">
                        <button class="btn ${user.is_following ? 'btn-secondary' : 'btn-primary'} btn-block user-follow-btn"
                                data-user-id="${user.id}">
                            ${user.is_following ? 'Abonné' : 'Suivre'}
                        </button>
                        <button class="btn btn-secondary btn-block">Message</button>
                    </div>
                ` : ''}
            </div>
            <div class="user-profile-grid profile-grid"></div>
        `;

        // Follow button
        const followBtn = container.querySelector('.user-follow-btn');
        followBtn?.addEventListener('click', async () => {
            try {
                if (user.is_following) {
                    await API.unfollow({ userId: user.id });
                    user.is_following = false;
                } else {
                    await API.follow({ userId: user.id });
                    user.is_following = true;
                }
                followBtn.className = `btn ${user.is_following ? 'btn-secondary' : 'btn-primary'} btn-block user-follow-btn`;
                followBtn.textContent = user.is_following ? 'Abonné' : 'Suivre';
                try { Ondes.Device.hapticFeedback('light'); } catch {}
            } catch (e) {
                console.error('[Profile] follow toggle:', e);
            }
        });
    },

    closeUser() {
        const modal = document.getElementById('userProfileModal');
        modal.classList.remove('active');
    },

    /** Bind events */
    bindEvents() {
        // Profile tabs
        document.querySelectorAll('.profile-tab').forEach(tab => {
            tab.addEventListener('click', () => this.switchTab(tab.dataset.tab));
        });

        // Close user profile modal
        document.getElementById('closeUserProfileBtn')?.addEventListener('click', () => this.closeUser());
    }
};
