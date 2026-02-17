/**
 * Ondes Social — Feed Manager
 * Handles all feed types: main, friends, discover, video, bookmarks
 */

const FeedManager = {
    state: {
        mainFeed: [],
        friendsFeed: [],
        discoverFeed: [],
        videoFeed: [],
        bookmarksFeed: [],
        mainOffset: 0,
        friendsOffset: 0,
        discoverOffset: 0,
        videoOffset: 0,
        bookmarksOffset: 0,
        activeHomeTab: 'main', // 'main' | 'friends'
        loading: false,
    },

    /** Initialize home feed */
    async initHome() {
        this._bindHomeTabs();
        await this.loadMainFeed(true);
    },

    _bindHomeTabs() {
        document.querySelectorAll('.feed-tab').forEach(tab => {
            tab.addEventListener('click', () => {
                const type = tab.dataset.feed;
                if (type === this.state.activeHomeTab) return;
                this.state.activeHomeTab = type;
                document.querySelectorAll('.feed-tab').forEach(t => t.classList.toggle('active', t.dataset.feed === type));
                
                const mainContainer = document.getElementById('mainFeedContent');
                const friendsContainer = document.getElementById('friendsFeedContent');
                
                if (type === 'main') {
                    mainContainer.style.display = 'block';
                    friendsContainer.style.display = 'none';
                    if (this.state.mainFeed.length === 0) this.loadMainFeed(true);
                } else {
                    mainContainer.style.display = 'none';
                    friendsContainer.style.display = 'block';
                    if (this.state.friendsFeed.length === 0) this.loadFriendsFeed(true);
                }
            });
        });
    },

    // ==================== MAIN FEED ====================

    async loadMainFeed(fresh = false) {
        if (this.state.loading) return;
        this.state.loading = true;

        const container = document.getElementById('mainFeedPosts');
        const loading = document.getElementById('mainFeedLoading');
        const empty = document.getElementById('mainFeedEmpty');

        if (fresh) {
            this.state.mainOffset = 0;
            this.state.mainFeed = [];
            container.innerHTML = '';
            loading.style.display = 'flex';
            empty.style.display = 'none';
        }

        try {
            const response = await API.getFeed({ limit: 20, offset: this.state.mainOffset });
            const posts = response.posts || [];
            this.state.mainFeed.push(...posts);
            this.state.mainOffset += posts.length;

            loading.style.display = 'none';

            if (this.state.mainFeed.length === 0) {
                empty.style.display = 'flex';
            } else {
                posts.forEach(post => {
                    container.appendChild(PostRenderer.renderPost(post));
                });
            }
        } catch (e) {
            console.error('[Feed] main:', e);
            loading.style.display = 'none';
        }

        this.state.loading = false;
    },

    // ==================== FRIENDS FEED ====================

    async loadFriendsFeed(fresh = false) {
        if (this.state.loading) return;
        this.state.loading = true;

        const container = document.getElementById('friendsFeedPosts');
        const loading = document.getElementById('friendsFeedLoading');
        const empty = document.getElementById('friendsFeedEmpty');

        if (fresh) {
            this.state.friendsOffset = 0;
            this.state.friendsFeed = [];
            container.innerHTML = '';
            loading.style.display = 'flex';
            empty.style.display = 'none';
        }

        try {
            const response = await API.getFriendsFeed({ limit: 20, offset: this.state.friendsOffset });
            const posts = response.posts || [];
            this.state.friendsFeed.push(...posts);
            this.state.friendsOffset += posts.length;

            loading.style.display = 'none';

            if (this.state.friendsFeed.length === 0) {
                empty.style.display = 'flex';
            } else {
                posts.forEach(post => {
                    container.appendChild(PostRenderer.renderPost(post));
                });
            }
        } catch (e) {
            console.error('[Feed] friends:', e);
            loading.style.display = 'none';
        }

        this.state.loading = false;
    },

    // ==================== DISCOVER FEED ====================

    async loadDiscoverFeed(fresh = false) {
        if (this.state.loading) return;
        this.state.loading = true;

        const container = document.getElementById('discoverGrid');
        const loading = document.getElementById('discoverLoading');

        if (fresh) {
            this.state.discoverOffset = 0;
            this.state.discoverFeed = [];
            container.innerHTML = '';
            loading.style.display = 'flex';
        }

        try {
            const response = await API.getDiscoverFeed({ limit: 30, offset: this.state.discoverOffset });
            const posts = response.posts || [];
            this.state.discoverFeed.push(...posts);
            this.state.discoverOffset += posts.length;

            loading.style.display = 'none';

            posts.forEach((post, i) => {
                // Make some items large for visual variety (every 5th starting at index 0)
                const isLarge = i % 7 === 0 && i < 21;
                container.appendChild(PostRenderer.renderDiscoverItem(post, isLarge));
            });
        } catch (e) {
            console.error('[Feed] discover:', e);
            loading.style.display = 'none';
        }

        this.state.loading = false;
    },

    // ==================== VIDEO FEED ====================

    async loadVideoFeed(fresh = false) {
        if (this.state.loading) return;
        this.state.loading = true;

        const container = document.getElementById('reelViewport');
        const loading = document.getElementById('reelsLoading');

        if (fresh) {
            this.state.videoOffset = 0;
            this.state.videoFeed = [];
            container.innerHTML = '';
            if (loading) loading.style.display = 'flex';
        }

        try {
            const response = await API.getVideoFeed({ limit: 10, offset: this.state.videoOffset });
            const posts = response.posts || [];
            this.state.videoFeed.push(...posts);
            this.state.videoOffset += posts.length;

            if (loading) loading.style.display = 'none';

            posts.forEach(post => {
                container.appendChild(this._renderReel(post));
            });

            // Initialize reel video observation
            this._initReelObserver();
        } catch (e) {
            console.error('[Feed] video:', e);
            if (loading) loading.style.display = 'none';
        }

        this.state.loading = false;
    },

    _renderReel(post) {
        const reel = createElement('div', 'reel-item');
        reel.dataset.uuid = post.uuid;

        const videoMedia = post.media?.find(m => m.media_type === 'video');
        const videoSrc = videoMedia?.hls_url || videoMedia?.display_url || '';
        const poster = videoMedia?.thumbnail_url || '';

        reel.innerHTML = `
            <video data-hls="${videoMedia?.hls_url || ''}"
                   data-src="${videoMedia?.display_url || ''}" 
                   poster="${poster}"
                   playsinline muted loop preload="metadata"></video>
            <div class="reel-overlay"></div>
            <div class="reel-info">
                <div class="reel-username" data-user-id="${post.author.id}">@${post.author.username}</div>
                ${post.content ? `<div class="reel-caption">${post.content}</div>` : ''}
            </div>
            <div class="reel-actions">
                <div class="reel-action">
                    <button class="reel-action-btn ${post.is_liked ? 'liked' : ''}" data-action="like">
                        ${post.is_liked ? icon('heartFilled') : icon('heart')}
                    </button>
                    <span class="reel-action-count">${formatCount(post.likes_count)}</span>
                </div>
                <div class="reel-action">
                    <button class="reel-action-btn" data-action="comment">${icon('comment')}</button>
                    <span class="reel-action-count">${formatCount(post.comments_count)}</span>
                </div>
                <div class="reel-action">
                    <button class="reel-action-btn" data-action="share">${icon('share')}</button>
                </div>
                <div class="reel-action">
                    <button class="reel-action-btn ${post.is_bookmarked ? 'bookmarked' : ''}" data-action="bookmark">
                        ${post.is_bookmarked ? icon('bookmarkFilled') : icon('bookmark')}
                    </button>
                </div>
            </div>
        `;

        // Events
        reel.addEventListener('click', (e) => {
            const btn = e.target.closest('[data-action]');
            if (!btn) {
                // Tap to toggle play/pause
                const video = reel.querySelector('video');
                if (video) {
                    video.paused ? video.play().catch(() => {}) : video.pause();
                }
                return;
            }
            const action = btn.dataset.action;
            switch (action) {
                case 'like':
                    post.is_liked = !post.is_liked;
                    post.likes_count += post.is_liked ? 1 : -1;
                    btn.className = `reel-action-btn ${post.is_liked ? 'liked' : ''}`;
                    btn.innerHTML = post.is_liked ? icon('heartFilled') : icon('heart');
                    btn.nextElementSibling.textContent = formatCount(post.likes_count);
                    (post.is_liked ? API.like(post.uuid) : API.unlike(post.uuid)).catch(() => {});
                    break;
                case 'comment':
                    CommentsManager.open(post.uuid);
                    break;
                case 'bookmark':
                    post.is_bookmarked = !post.is_bookmarked;
                    btn.className = `reel-action-btn ${post.is_bookmarked ? 'bookmarked' : ''}`;
                    btn.innerHTML = post.is_bookmarked ? icon('bookmarkFilled') : icon('bookmark');
                    (post.is_bookmarked ? API.bookmark(post.uuid) : API.removeBookmark(post.uuid)).catch(() => {});
                    break;
            }
        });

        reel.querySelector('[data-user-id]')?.addEventListener('click', (e) => {
            e.stopPropagation();
            ProfileManager.openUser(parseInt(e.target.dataset.userId));
        });

        return reel;
    },

    _reelObserver: null,
    _initReelObserver() {
        if (this._reelObserver) return;
        this._reelObserver = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                const video = entry.target.querySelector('video');
                if (!video) return;

                if (entry.isIntersecting) {
                    // Initialize HLS
                    const hlsUrl = video.dataset.hls;
                    const srcUrl = video.dataset.src;
                    if (hlsUrl && window.Hls && Hls.isSupported() && !video._hlsInit) {
                        const hls = new Hls({ maxBufferLength: 10 });
                        hls.loadSource(hlsUrl);
                        hls.attachMedia(video);
                        video._hlsInit = true;
                        video._hls = hls;
                    } else if (hlsUrl && video.canPlayType('application/vnd.apple.mpegurl') && !video.src) {
                        video.src = hlsUrl;
                    } else if (srcUrl && !video.src) {
                        video.src = srcUrl;
                    }
                    video.play().catch(() => {});
                } else {
                    video.pause();
                }
            });
        }, { threshold: 0.7 });

        document.querySelectorAll('.reel-item').forEach(item => {
            this._reelObserver.observe(item);
        });
    },

    // ==================== BOOKMARKS FEED ====================

    async loadBookmarksFeed(fresh = false) {
        if (this.state.loading) return;
        this.state.loading = true;

        const container = document.getElementById('profileBookmarksGrid');
        if (!container) { this.state.loading = false; return; }

        if (fresh) {
            this.state.bookmarksOffset = 0;
            this.state.bookmarksFeed = [];
            container.innerHTML = '';
        }

        try {
            const response = await API.getBookmarks(30, this.state.bookmarksOffset);
            const posts = response.posts || response || [];
            this.state.bookmarksFeed.push(...posts);
            this.state.bookmarksOffset += posts.length;

            if (this.state.bookmarksFeed.length === 0) {
                container.innerHTML = `
                    <div class="empty-state" style="grid-column: 1/-1">
                        ${icon('bookmark')}
                        <h3>Aucune sauvegarde</h3>
                        <p>Sauvegardez des publications pour les retrouver ici</p>
                    </div>
                `;
            } else {
                posts.forEach(post => {
                    container.appendChild(PostRenderer.renderProfileGridItem(post));
                });
            }
        } catch (e) {
            console.error('[Feed] bookmarks:', e);
        }

        this.state.loading = false;
    },

    /** Setup infinite scroll for a page */
    setupInfiniteScroll(pageEl, loadFn) {
        pageEl.addEventListener('scroll', throttle(() => {
            const threshold = 300;
            if (pageEl.scrollTop + pageEl.clientHeight >= pageEl.scrollHeight - threshold) {
                loadFn();
            }
        }, 200));
    }
};
