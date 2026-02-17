/**
 * Ondes Social — Search Manager
 */

const SearchManager = {
    state: {
        results: [],
        query: '',
    },

    /** Open search modal */
    open() {
        const modal = document.getElementById('searchModal');
        modal.classList.add('active');
        setTimeout(() => {
            document.getElementById('searchInput')?.focus();
        }, 300);
    },

    close() {
        const modal = document.getElementById('searchModal');
        modal.classList.remove('active');
        this.state.query = '';
        this.state.results = [];
    },

    /** Perform search */
    async search(query) {
        this.state.query = query;
        if (query.length < 2) {
            this._renderResults([]);
            return;
        }

        try {
            const response = await API.searchUsers(query);
            this.state.results = response.users || [];
            this._renderResults(this.state.results);
        } catch (e) {
            console.error('[Search]', e);
        }
    },

    _renderResults(users) {
        const container = document.getElementById('searchResults');
        if (!container) return;

        if (users.length === 0) {
            if (this.state.query.length >= 2) {
                container.innerHTML = `
                    <div class="empty-state">
                        ${icon('search')}
                        <h3>Aucun résultat</h3>
                        <p>Aucun utilisateur trouvé pour "${this.state.query}"</p>
                    </div>
                `;
            } else {
                container.innerHTML = `
                    <div class="empty-state">
                        ${icon('search')}
                        <p>Recherchez des utilisateurs par nom</p>
                    </div>
                `;
            }
            return;
        }

        container.innerHTML = '';
        users.forEach(user => {
            const item = createElement('div', 'search-result-item');
            const avatar = getAvatar(user);

            item.innerHTML = `
                <img class="avatar avatar-md" src="${avatar}" alt="${user.username}"
                     onerror="this.src='${defaultAvatar(user.username)}'">
                <div class="search-result-info">
                    <div class="search-result-username">${user.username}</div>
                    ${user.bio ? `<div class="search-result-bio">${user.bio}</div>` : ''}
                </div>
                ${user.is_following !== undefined ? `
                    <button class="btn btn-sm ${user.is_following ? 'btn-secondary' : 'btn-primary'}" data-user-id="${user.id}">
                        ${user.is_following ? 'Abonné' : 'Suivre'}
                    </button>
                ` : ''}
            `;

            item.addEventListener('click', (e) => {
                if (e.target.closest('button')) return;
                this.close();
                ProfileManager.openUser(user.id);
            });

            const followBtn = item.querySelector('button');
            followBtn?.addEventListener('click', async () => {
                try {
                    if (user.is_following) {
                        await API.unfollow({ userId: user.id });
                        user.is_following = false;
                    } else {
                        await API.follow({ userId: user.id });
                        user.is_following = true;
                    }
                    followBtn.className = `btn btn-sm ${user.is_following ? 'btn-secondary' : 'btn-primary'}`;
                    followBtn.textContent = user.is_following ? 'Abonné' : 'Suivre';
                } catch {}
            });

            container.appendChild(item);
        });
    },

    /** Bind events */
    bindEvents() {
        const input = document.getElementById('searchInput');
        const closeBtn = document.getElementById('closeSearchBtn');
        const cancelBtn = document.getElementById('cancelSearchBtn');

        if (input) {
            input.addEventListener('input', debounce((e) => {
                this.search(e.target.value.trim());
            }, 400));
        }

        closeBtn?.addEventListener('click', () => this.close());
        cancelBtn?.addEventListener('click', () => this.close());
    }
};
