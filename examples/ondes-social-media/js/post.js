/**
 * Ondes Social — Post Rendering & Interactions
 */

const PostRenderer = {
    /** Render a single post card */
    renderPost(post) {
        const article = createElement('article', 'post-card');
        article.dataset.uuid = post.uuid;

        const hasMedia = post.media && post.media.length > 0;
        const isTextOnly = !hasMedia && post.content;

        article.innerHTML = `
            ${this._header(post)}
            ${hasMedia ? this._media(post) : ''}
            ${isTextOnly ? this._textOnly(post) : ''}
            ${this._actions(post)}
            ${this._info(post)}
        `;

        // Wire up event handlers
        this._bindEvents(article, post);
        return article;
    },

    _header(post) {
        const avatar = getAvatar(post.author);
        const location = post.location_name || '';
        return `
            <header class="post-header">
                <img class="avatar avatar-sm" src="${avatar}" alt="${post.author.username}" 
                     onerror="this.src='${defaultAvatar(post.author.username)}'">
                <div class="post-user-info">
                    <div class="post-username" data-user-id="${post.author.id}">${post.author.username}</div>
                    ${location ? `<div class="post-location">${location}</div>` : ''}
                </div>
                <button class="post-menu-btn btn-icon" data-action="menu">${icon('more')}</button>
            </header>
        `;
    },

    _media(post) {
        const medias = post.media;
        if (medias.length === 1) {
            return this._singleMedia(medias[0], post.uuid);
        }
        return this._carousel(medias, post.uuid);
    },

    _singleMedia(media, postUuid) {
        if (media.media_type === 'video') {
            return `
                <div class="post-media post-video-container" data-post-uuid="${postUuid}">
                    <video data-hls="${media.hls_url || media.display_url || ''}"
                           data-src="${media.display_url || ''}"
                           poster="${media.thumbnail_url || ''}"
                           playsinline muted loop preload="metadata"></video>
                    <div class="video-play-overlay visible" data-action="play-video">
                        ${icon('playCircle')}
                    </div>
                    <button class="video-mute-btn" data-action="toggle-mute">${icon('volumeOff')}</button>
                    <div class="double-tap-heart">${icon('heartFilled')}</div>
                </div>
            `;
        }
        return `
            <div class="post-media" data-post-uuid="${postUuid}">
                <img src="${media.display_url}" alt="" loading="lazy"
                     onerror="this.parentElement.style.display='none'">
                <div class="double-tap-heart">${icon('heartFilled')}</div>
            </div>
        `;
    },

    _carousel(medias, postUuid) {
        const items = medias.map((m, i) => {
            const content = m.media_type === 'video'
                ? `<video src="${m.display_url}" poster="${m.thumbnail_url || ''}" playsinline muted loop preload="metadata"></video>`
                : `<img src="${m.display_url}" alt="" loading="lazy">`;
            return `<div class="post-carousel-item">${content}</div>`;
        }).join('');

        const dots = medias.map((_, i) =>
            `<div class="carousel-dot ${i === 0 ? 'active' : ''}"></div>`
        ).join('');

        return `
            <div class="post-media" data-post-uuid="${postUuid}">
                <div class="post-carousel">${items}</div>
                <div class="carousel-dots">${dots}</div>
                <div class="double-tap-heart">${icon('heartFilled')}</div>
            </div>
        `;
    },

    _textOnly(post) {
        const gradient = getTextGradient(post.uuid);
        const text = post.content.length > 200 ? post.content.slice(0, 200) + '...' : post.content;
        return `
            <div class="post-media" data-post-uuid="${post.uuid}">
                <div class="post-text-only ${gradient}">
                    <div class="text-content">${this._escapeHtml(text)}</div>
                </div>
                <div class="double-tap-heart">${icon('heartFilled')}</div>
            </div>
        `;
    },

    _actions(post) {
        const liked = post.is_liked;
        const bookmarked = post.is_bookmarked;
        return `
            <div class="post-actions">
                <button class="post-action-btn ${liked ? 'liked' : ''}" data-action="like">
                    ${liked ? icon('heartFilled') : icon('heart')}
                </button>
                <button class="post-action-btn" data-action="comment">${icon('comment')}</button>
                <button class="post-action-btn" data-action="share">${icon('share')}</button>
                <div class="post-actions-spacer"></div>
                <button class="post-action-btn ${bookmarked ? 'bookmarked' : ''}" data-action="bookmark">
                    ${bookmarked ? icon('bookmarkFilled') : icon('bookmark')}
                </button>
            </div>
        `;
    },

    _info(post) {
        const hasMedia = post.media && post.media.length > 0;
        const hasTags = post.tags && post.tags.length > 0;
        const captionText = hasMedia ? post.content : '';

        return `
            <div class="post-info">
                ${post.likes_count > 0 ? `<div class="post-likes-count">${formatCount(post.likes_count)} j'aime</div>` : ''}
                ${captionText ? `
                    <div class="post-caption-area">
                        <span class="author" data-user-id="${post.author.id}">${post.author.username}</span>
                        <span class="caption-text">${this._escapeHtml(captionText)}</span>
                    </div>
                ` : ''}
                ${hasTags ? `<div class="post-tags">${post.tags.map(t => `<span class="post-tag">#${t}</span>`).join(' ')}</div>` : ''}
                ${post.comments_count > 0 ? `
                    <div class="post-comments-link" data-action="comment">
                        Voir les ${post.comments_count} commentaire${post.comments_count > 1 ? 's' : ''}
                    </div>
                ` : ''}
                <div class="post-time">${timeAgo(post.created_at)}</div>
            </div>
        `;
    },

    _escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    },

    _bindEvents(article, post) {
        // Double tap to like
        let lastTap = 0;
        const mediaEl = article.querySelector('.post-media');
        if (mediaEl) {
            mediaEl.addEventListener('click', (e) => {
                if (e.target.closest('[data-action]')) return;
                const now = Date.now();
                if (now - lastTap < 300) {
                    this._doubleTapLike(article, post);
                }
                lastTap = now;
            });
        }

        // Action buttons
        article.addEventListener('click', (e) => {
            const btn = e.target.closest('[data-action]');
            if (!btn) return;
            const action = btn.dataset.action;

            switch (action) {
                case 'like': this._toggleLike(article, post); break;
                case 'bookmark': this._toggleBookmark(article, post); break;
                case 'comment': CommentsManager.open(post.uuid); break;
                case 'share': this._sharePost(post); break;
                case 'menu': this._showMenu(post); break;
                case 'play-video': this._playVideo(article); break;
                case 'toggle-mute': this._toggleMute(article); break;
            }
        });

        // Username click -> profile
        article.querySelectorAll('[data-user-id]').forEach(el => {
            el.addEventListener('click', () => {
                ProfileManager.openUser(parseInt(el.dataset.userId));
            });
        });

        // Carousel scroll
        const carousel = article.querySelector('.post-carousel');
        if (carousel) {
            carousel.addEventListener('scroll', throttle(() => {
                const index = Math.round(carousel.scrollLeft / carousel.offsetWidth);
                const dots = article.querySelectorAll('.carousel-dot');
                dots.forEach((dot, i) => dot.classList.toggle('active', i === index));
            }, 100));
        }

        // Lazy video initialization with Intersection Observer
        const videoContainer = article.querySelector('.post-video-container');
        if (videoContainer) {
            this._observeVideo(videoContainer);
        }
    },

    async _doubleTapLike(article, post) {
        const heart = article.querySelector('.double-tap-heart');
        if (heart) {
            heart.classList.remove('animate');
            void heart.offsetWidth;
            heart.classList.add('animate');
            setTimeout(() => heart.classList.remove('animate'), 900);
        }

        if (!post.is_liked) {
            post.is_liked = true;
            post.likes_count = (post.likes_count || 0) + 1;
            this._updateLikeUI(article, post);
            try { await API.like(post.uuid); } catch {}
        }

        try { await Ondes.Device.hapticFeedback('light'); } catch {}
    },

    async _toggleLike(article, post) {
        post.is_liked = !post.is_liked;
        post.likes_count = (post.likes_count || 0) + (post.is_liked ? 1 : -1);
        this._updateLikeUI(article, post);

        try {
            if (post.is_liked) {
                await API.like(post.uuid);
                try { await Ondes.Device.hapticFeedback('light'); } catch {}
            } else {
                await API.unlike(post.uuid);
            }
        } catch {
            // Rollback
            post.is_liked = !post.is_liked;
            post.likes_count = (post.likes_count || 0) + (post.is_liked ? 1 : -1);
            this._updateLikeUI(article, post);
        }
    },

    _updateLikeUI(article, post) {
        const btn = article.querySelector('[data-action="like"]');
        if (btn) {
            btn.className = `post-action-btn ${post.is_liked ? 'liked' : ''}`;
            btn.innerHTML = post.is_liked ? icon('heartFilled') : icon('heart');
        }
        const count = article.querySelector('.post-likes-count');
        if (count) {
            count.textContent = `${formatCount(post.likes_count)} j'aime`;
        } else if (post.likes_count > 0) {
            const info = article.querySelector('.post-info');
            if (info) {
                const el = createElement('div', 'post-likes-count', { text: `${formatCount(post.likes_count)} j'aime` });
                info.insertBefore(el, info.firstChild);
            }
        }
    },

    async _toggleBookmark(article, post) {
        post.is_bookmarked = !post.is_bookmarked;
        const btn = article.querySelector('[data-action="bookmark"]');
        btn.className = `post-action-btn ${post.is_bookmarked ? 'bookmarked' : ''}`;
        btn.innerHTML = post.is_bookmarked ? icon('bookmarkFilled') : icon('bookmark');

        try {
            if (post.is_bookmarked) {
                await API.bookmark(post.uuid);
                try { await Ondes.Device.hapticFeedback('light'); } catch {}
            } else {
                await API.removeBookmark(post.uuid);
            }
        } catch {
            post.is_bookmarked = !post.is_bookmarked;
            btn.className = `post-action-btn ${post.is_bookmarked ? 'bookmarked' : ''}`;
            btn.innerHTML = post.is_bookmarked ? icon('bookmarkFilled') : icon('bookmark');
        }
    },

    _sharePost(post) {
        try {
            Ondes.UI.showToast({ message: 'Lien copié !', type: 'success', duration: 2000 });
        } catch {}
    },

    async _showMenu(post) {
        try {
            const isOwn = post.author.id === App.state.currentUser?.id;
            if (isOwn) {
                const ok = await Ondes.UI.showConfirm({
                    title: 'Supprimer',
                    message: 'Voulez-vous supprimer cette publication ?',
                    confirmText: 'Supprimer',
                    cancelText: 'Annuler',
                    confirmColor: '#ef4444'
                });
                if (ok) {
                    await API.deletePost(post.uuid);
                    document.querySelector(`[data-uuid="${post.uuid}"]`)?.remove();
                    Ondes.UI.showToast({ message: 'Publication supprimée', type: 'success' });
                }
            }
        } catch {}
    },

    _playVideo(container) {
        const video = container.querySelector('video');
        const overlay = container.querySelector('.video-play-overlay');
        if (!video) return;

        const hlsUrl = video.dataset.hls;
        const srcUrl = video.dataset.src;

        // Initialize HLS if needed
        if (hlsUrl && window.Hls && Hls.isSupported() && !video._hlsInitialized) {
            const hls = new Hls({ maxBufferLength: 10, maxMaxBufferLength: 30 });
            hls.loadSource(hlsUrl);
            hls.attachMedia(video);
            video._hlsInitialized = true;
            video._hls = hls;
        } else if (hlsUrl && video.canPlayType('application/vnd.apple.mpegurl') && !video.src) {
            video.src = hlsUrl;
        } else if (srcUrl && !video.src) {
            video.src = srcUrl;
        }

        if (video.paused) {
            video.play().catch(() => {});
            overlay?.classList.remove('visible');
        } else {
            video.pause();
            overlay?.classList.add('visible');
        }
    },

    _toggleMute(container) {
        const video = container.querySelector('video');
        const btn = container.querySelector('.video-mute-btn');
        if (!video || !btn) return;
        video.muted = !video.muted;
        btn.innerHTML = video.muted ? icon('volumeOff') : icon('volumeOn');
    },

    _observeVideo(container) {
        if (!PostRenderer._videoObserver) {
            PostRenderer._videoObserver = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    const video = entry.target.querySelector('video');
                    if (!video) return;
                    if (!entry.isIntersecting && !video.paused) {
                        video.pause();
                        entry.target.querySelector('.video-play-overlay')?.classList.add('visible');
                    }
                });
            }, { threshold: 0.5 });
        }
        PostRenderer._videoObserver.observe(container);
    },

    /** Render a post for the discover grid */
    renderDiscoverItem(post, isLarge = false) {
        const item = createElement('div', `discover-grid-item ${isLarge ? 'large' : ''}`);
        item.dataset.uuid = post.uuid;

        const hasMedia = post.media && post.media.length > 0;
        const firstMedia = hasMedia ? post.media[0] : null;

        if (firstMedia) {
            if (firstMedia.media_type === 'video') {
                item.innerHTML = `
                    <img src="${firstMedia.thumbnail_url || ''}" alt="" loading="lazy">
                    <div class="discover-media-badge">${icon('play')}</div>
                `;
            } else {
                item.innerHTML = `<img src="${firstMedia.display_url}" alt="" loading="lazy">`;
            }
            if (post.media.length > 1) {
                item.innerHTML += `<div class="discover-media-badge">${icon('multiMedia')}</div>`;
            }
        } else {
            const gradient = getTextGradient(post.uuid);
            const text = post.content?.slice(0, 60) || '';
            item.innerHTML = `<div class="profile-grid-text ${gradient}">${PostRenderer._escapeHtml(text)}</div>`;
        }

        item.addEventListener('click', () => {
            // Open post detail (could open in a modal)
            CommentsManager.openPostDetail(post);
        });

        return item;
    },

    /** Render a post for the profile grid */
    renderProfileGridItem(post) {
        const item = createElement('div', 'profile-grid-item');
        item.dataset.uuid = post.uuid;

        const hasMedia = post.media && post.media.length > 0;
        const firstMedia = hasMedia ? post.media[0] : null;

        if (firstMedia) {
            if (firstMedia.media_type === 'video') {
                item.innerHTML = `
                    <img src="${firstMedia.thumbnail_url || firstMedia.display_url}" alt="" loading="lazy">
                    <div class="profile-grid-badge">${icon('play')}</div>
                `;
            } else {
                item.innerHTML = `<img src="${firstMedia.display_url}" alt="" loading="lazy">`;
            }
            if (post.media.length > 1) {
                item.innerHTML += `<div class="profile-grid-badge">${icon('multiMedia')}</div>`;
            }
        } else {
            const gradient = getTextGradient(post.uuid);
            const text = post.content?.slice(0, 80) || '';
            item.className = 'profile-grid-item';
            item.innerHTML = `<div class="profile-grid-text ${gradient}">${PostRenderer._escapeHtml(text)}</div>`;
        }

        item.addEventListener('click', () => {
            CommentsManager.openPostDetail(post);
        });

        return item;
    }
};
