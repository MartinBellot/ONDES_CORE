/**
 * Ondes Social — Main App
 * Initialization, routing, state management
 */

const App = {
    state: {
        currentUser: null,
        currentPage: 'home',
        initialized: false,
    },

    /** Initialize the application */
    async init() {
        if (this.state.initialized) return;

        try {
            // Get current user profile
            this.state.currentUser = await API.getMyProfile();
        } catch (e) {
            console.error('[App] Failed to get user profile:', e);
            this.state.currentUser = { id: 0, username: 'utilisateur', avatar: null };
        }

        // Bind navigation
        this._bindNavigation();

        // Bind managers
        CommentsManager.bindEvents();
        StoriesManager.bindViewerEvents();
        SearchManager.bindEvents();
        ProfileManager.bindEvents();
        this._bindCreatePost();
        this._bindModals();

        // Load initial content in parallel
        try {
            await Promise.all([
                StoriesManager.load(),
                FeedManager.initHome(),
            ]);
        } catch (e) {
            console.error('[App] Initial load error:', e);
        }

        // Set profile avatar in nav
        this._updateNavAvatar();

        this.state.initialized = true;
        document.body.classList.add('loaded');
    },

    /** Page routing */
    navigate(page) {
        if (page === this.state.currentPage && page !== 'create') return;

        // Hide all pages
        document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));

        // Show target page
        const target = document.getElementById(`${page}Page`);
        if (target) target.classList.add('active');

        // Update nav
        document.querySelectorAll('.pill-nav-item').forEach(item => {
            item.classList.toggle('active', item.dataset.page === page);
        });

        // Handle header visibility
        const header = document.querySelector('.app-header');
        if (page === 'reels') {
            header.classList.add('hidden');
        } else {
            header.classList.remove('hidden');
        }

        // Lazy load page content
        this._onPageEnter(page);

        this.state.currentPage = page;
    },

    _onPageEnter(page) {
        switch (page) {
            case 'home':
                // Already loaded on init
                break;

            case 'discover':
                if (FeedManager.state.discoverFeed.length === 0) {
                    FeedManager.loadDiscoverFeed(true);
                }
                break;

            case 'reels':
                if (FeedManager.state.videoFeed.length === 0) {
                    FeedManager.loadVideoFeed(true);
                }
                break;

            case 'profile':
                ProfileManager.load();
                break;

            case 'create':
                this._openCreatePost();
                return; // Don't change currentPage
        }
    },

    _bindNavigation() {
        // Pill nav items
        document.querySelectorAll('.pill-nav-item').forEach(item => {
            item.addEventListener('click', () => {
                this.navigate(item.dataset.page);
            });
        });

        // Pill nav create button
        document.querySelector('.pill-nav-create')?.addEventListener('click', () => {
            this._openCreatePost();
        });

        // Header search button
        document.getElementById('headerSearchBtn')?.addEventListener('click', () => {
            SearchManager.open();
        });

        // Discover search trigger
        document.getElementById('discoverSearchTrigger')?.addEventListener('click', () => {
            SearchManager.open();
        });
    },

    /** Create Post */
    _openCreatePost() {
        const modal = document.getElementById('createPostModal');
        modal.classList.add('active');
        this._resetCreateForm();
    },

    _closeCreatePost() {
        const modal = document.getElementById('createPostModal');
        modal.classList.remove('active');
        this._resetCreateForm();
    },

    _resetCreateForm() {
        const textarea = document.getElementById('createPostCaption');
        const preview = document.getElementById('createPostMediaPreview');
        const textModeToggle = document.getElementById('textModeToggle');

        if (textarea) textarea.value = '';
        if (preview) { preview.innerHTML = ''; preview.style.display = 'none'; }
        if (textModeToggle) textModeToggle.classList.remove('active');

        this._createPostState = {
            media: [],
            textOnly: false,
            gradientIndex: 0,
            visibility: 'public'
        };

        document.getElementById('textOnlyPreview')?.remove();
        document.getElementById('publishBtn')?.classList.remove('ready');
    },

    _bindCreatePost() {
        this._createPostState = { media: [], textOnly: false, gradientIndex: 0, visibility: 'public' };

        document.getElementById('closeCreateBtn')?.addEventListener('click', () => this._closeCreatePost());

        // Pick media
        document.getElementById('pickMediaBtn')?.addEventListener('click', async () => {
            try {
                const files = await API.pickMedia({ multiple: true, allowVideo: true, maxFiles: 10 });
                if (files && files.length > 0) {
                    this._createPostState.media = files;
                    this._createPostState.textOnly = false;
                    this._showMediaPreview(files);
                }
            } catch (e) {
                console.error('[Create] pickMedia:', e);
            }
        });

        // Text mode toggle
        document.getElementById('textModeToggle')?.addEventListener('click', () => {
            this._createPostState.textOnly = !this._createPostState.textOnly;
            document.getElementById('textModeToggle').classList.toggle('active', this._createPostState.textOnly);
            document.getElementById('createPostMediaPreview').style.display = 'none';

            if (this._createPostState.textOnly) {
                this._showTextOnlyPreview();
                this._createPostState.media = [];
            } else {
                document.getElementById('textOnlyPreview')?.remove();
            }

            this._updatePublishReady();
        });

        // Gradient selector
        document.getElementById('createPostContent')?.addEventListener('click', (e) => {
            if (e.target.closest('.gradient-option')) {
                const idx = parseInt(e.target.closest('.gradient-option').dataset.index);
                this._createPostState.gradientIndex = idx;
                this._updateTextOnlyGradient();
            }
        });

        // Caption input
        document.getElementById('createPostCaption')?.addEventListener('input', () => {
            this._updatePublishReady();
        });

        // Publish
        document.getElementById('publishBtn')?.addEventListener('click', () => this._publish());
    },

    _showMediaPreview(files) {
        const preview = document.getElementById('createPostMediaPreview');
        preview.style.display = 'flex';
        preview.innerHTML = '';

        document.getElementById('textOnlyPreview')?.remove();

        files.forEach((file, i) => {
            const item = createElement('div', 'media-preview-item');
            if (file.mime?.startsWith('video')) {
                item.innerHTML = `
                    <video src="${file.path}" muted></video>
                    <div class="media-preview-badge">${icon('video')}</div>
                `;
            } else {
                item.innerHTML = `<img src="${file.path}" alt="Media ${i + 1}">`;
            }
            const removeBtn = createElement('button', 'media-preview-remove');
            removeBtn.innerHTML = icon('close');
            removeBtn.addEventListener('click', () => {
                this._createPostState.media.splice(i, 1);
                if (this._createPostState.media.length === 0) {
                    preview.style.display = 'none';
                }
                this._showMediaPreview(this._createPostState.media);
            });
            item.appendChild(removeBtn);
            preview.appendChild(item);
        });

        this._updatePublishReady();
    },

    _showTextOnlyPreview() {
        let existing = document.getElementById('textOnlyPreview');
        if (existing) existing.remove();

        const preview = createElement('div', 'text-only-create-preview');
        preview.id = 'textOnlyPreview';

        const gradients = [
            'linear-gradient(135deg, #6366f1, #8b5cf6)',
            'linear-gradient(135deg, #ec4899, #f43f5e)',
            'linear-gradient(135deg, #06b6d4, #3b82f6)',
            'linear-gradient(135deg, #f59e0b, #ef4444)',
            'linear-gradient(135deg, #10b981, #059669)',
            'linear-gradient(135deg, #1a1a2e, #16213e)'
        ];

        preview.innerHTML = `
            <div class="text-only-preview-card" style="background: ${gradients[this._createPostState.gradientIndex]}">
                <p id="textOnlyLiveText">Votre texte ici...</p>
            </div>
            <div class="gradient-selector">
                ${gradients.map((g, i) => `
                    <div class="gradient-option ${i === this._createPostState.gradientIndex ? 'active' : ''}" 
                         data-index="${i}" style="background: ${g}"></div>
                `).join('')}
            </div>
        `;

        document.getElementById('createPostContent')?.insertBefore(
            preview,
            document.getElementById('createPostCaption')?.parentElement
        );

        // Live text update
        document.getElementById('createPostCaption')?.addEventListener('input', () => {
            const text = document.getElementById('createPostCaption')?.value;
            const liveText = document.getElementById('textOnlyLiveText');
            if (liveText) liveText.textContent = text || 'Votre texte ici...';
        });
    },

    _updateTextOnlyGradient() {
        const gradients = [
            'linear-gradient(135deg, #6366f1, #8b5cf6)',
            'linear-gradient(135deg, #ec4899, #f43f5e)',
            'linear-gradient(135deg, #06b6d4, #3b82f6)',
            'linear-gradient(135deg, #f59e0b, #ef4444)',
            'linear-gradient(135deg, #10b981, #059669)',
            'linear-gradient(135deg, #1a1a2e, #16213e)'
        ];

        const card = document.querySelector('.text-only-preview-card');
        if (card) card.style.background = gradients[this._createPostState.gradientIndex];

        document.querySelectorAll('.gradient-option').forEach((opt, i) => {
            opt.classList.toggle('active', i === this._createPostState.gradientIndex);
        });
    },

    _updatePublishReady() {
        const btn = document.getElementById('publishBtn');
        const caption = document.getElementById('createPostCaption')?.value.trim();
        const hasMedia = this._createPostState.media.length > 0;
        const isTextOnly = this._createPostState.textOnly && caption;
        btn?.classList.toggle('ready', hasMedia || isTextOnly);
    },

    async _publish() {
        const caption = document.getElementById('createPostCaption')?.value.trim();
        const { media, textOnly, gradientIndex, visibility } = this._createPostState;

        if (!caption && media.length === 0) return;

        // Show publishing overlay
        document.getElementById('publishingOverlay')?.classList.add('active');

        try {
            const params = {
                caption: caption || '',
                visibility: visibility,
            };

            if (textOnly) {
                params.text_only = true;
                params.gradient_index = gradientIndex;
            } else if (media.length > 0) {
                params.media = media.map(f => f.path);
            }

            await API.publish(params);

            try { Ondes.Device.hapticFeedback('success'); } catch {}
            try { Ondes.UI.showToast({ message: 'Publié avec succès !', type: 'success' }); } catch {}

            this._closeCreatePost();

            // Refresh feed
            FeedManager.loadMainFeed(true);
        } catch (e) {
            console.error('[Create] publish error:', e);
            try { Ondes.UI.showToast({ message: 'Erreur lors de la publication', type: 'error' }); } catch {}
        } finally {
            document.getElementById('publishingOverlay')?.classList.remove('active');
        }
    },

    _bindModals() {
        // Close modals on overlay click
        document.querySelectorAll('.modal-overlay').forEach(overlay => {
            overlay.addEventListener('click', (e) => {
                if (e.target === overlay) {
                    overlay.closest('.modal')?.classList.remove('active');
                }
            });
        });
    },

    _updateNavAvatar() {
        const navAvatar = document.getElementById('navProfileAvatar');
        if (navAvatar && this.state.currentUser) {
            navAvatar.src = getAvatar(this.state.currentUser);
        }
    }
};

/* ---- Bootstrap ---- */

// Ondes SDK ready event
if (typeof window.Ondes !== 'undefined') {
    App.init();
} else {
    document.addEventListener('OndesReady', () => App.init());
}

// Fallback for development/preview without Ondes SDK
setTimeout(() => {
    if (!App.state.initialized) {
        console.warn('[App] Ondes SDK not detected, running in preview mode');
        // Mock minimal API for preview
        if (typeof window.Ondes === 'undefined') {
            window.Ondes = {
                Social: {},
                Friends: {},
                UI: { showToast: (msg) => console.log('[Toast]', msg) },
                User: { getProfile: () => Promise.resolve({ id: 1, username: 'preview', avatar: null }) },
                Device: { hapticFeedback: () => {} },
                Storage: {}
            };
        }
        App.init();
    }
}, 2000);
