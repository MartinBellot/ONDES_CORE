/**
 * Ondes Social — Stories Manager
 * Stories bar + fullscreen viewer with progress bars
 */

const StoriesManager = {
    state: {
        stories: [],
        currentUserIndex: -1,
        currentStoryIndex: 0,
        timer: null,
        progressInterval: null,
        isPaused: false,
    },

    /** Load and render stories bar */
    async load() {
        const container = document.getElementById('storiesScroll');
        if (!container) return;

        try {
            const response = await API.getStories();
            this.state.stories = response.stories || [];
            this._renderBar(container);
        } catch (e) {
            console.error('[Stories] load:', e);
        }
    },

    _renderBar(container) {
        container.innerHTML = '';

        // "Your story" button
        const yourStory = createElement('div', 'story-item');
        const myAvatar = getAvatar(App.state.currentUser);
        yourStory.innerHTML = `
            <div class="story-ring add-ring">
                <div class="story-avatar">
                    <img src="${myAvatar}" alt="Vous" onerror="this.src='${defaultAvatar('me')}'">
                </div>
                <div class="story-add-badge">+</div>
            </div>
            <span class="story-name">Votre story</span>
        `;
        yourStory.addEventListener('click', () => this._createStory());
        container.appendChild(yourStory);

        // Other users' stories
        this.state.stories.forEach((userStory, idx) => {
            const item = createElement('div', 'story-item');
            const avatar = getAvatar(userStory.user);
            const hasUnviewed = userStory.has_unviewed;

            item.innerHTML = `
                <div class="story-ring ${hasUnviewed ? '' : 'viewed'}">
                    <div class="story-avatar">
                        <img src="${avatar}" alt="${userStory.user.username}" 
                             onerror="this.src='${defaultAvatar(userStory.user.username)}'">
                    </div>
                </div>
                <span class="story-name">${userStory.user.username}</span>
            `;
            item.addEventListener('click', () => this.open(idx));
            container.appendChild(item);
        });
    },

    /** Open story viewer at user index */
    open(userIndex) {
        if (!this.state.stories[userIndex]) return;

        this.state.currentUserIndex = userIndex;
        this.state.currentStoryIndex = 0;

        const viewer = document.getElementById('storyViewer');
        viewer.classList.add('active');
        document.body.style.overflow = 'hidden';

        this._showCurrentStory();
    },

    close() {
        const viewer = document.getElementById('storyViewer');
        viewer.classList.remove('active');
        document.body.style.overflow = '';

        this._stopTimer();
        this.state.currentUserIndex = -1;

        // Cleanup video
        const content = document.getElementById('storyViewerContent');
        const video = content?.querySelector('video');
        if (video) video.pause();
    },

    _showCurrentStory() {
        const userStory = this.state.stories[this.state.currentUserIndex];
        if (!userStory) { this.close(); return; }

        const story = userStory.stories[this.state.currentStoryIndex];
        if (!story) {
            // Move to next user
            this._nextUser();
            return;
        }

        // Update header
        const avatar = getAvatar(userStory.user);
        document.getElementById('storyViewerAvatar').src = avatar;
        document.getElementById('storyViewerUsername').textContent = userStory.user.username;
        document.getElementById('storyViewerTimeText').textContent = timeAgo(story.created_at);

        // Update content
        const content = document.getElementById('storyViewerContent');
        if (story.media_type === 'video') {
            content.innerHTML = `<video src="${story.hls_url || story.media_url}" playsinline autoplay muted></video>`;
            const video = content.querySelector('video');
            video.play().catch(() => {});
        } else {
            content.innerHTML = `<img src="${story.media_url}" alt="">`;
        }

        // Update progress bars
        this._renderProgress(userStory.stories.length, this.state.currentStoryIndex);

        // Mark as viewed
        API.viewStory(story.uuid).catch(() => {});

        // Start timer
        const duration = (story.media_type === 'video' ? Math.min(story.duration || 15, 30) : story.duration || 5) * 1000;
        this._startTimer(duration);
    },

    _renderProgress(total, current) {
        const container = document.getElementById('storyProgressContainer');
        container.innerHTML = '';
        for (let i = 0; i < total; i++) {
            const seg = createElement('div', 'story-progress-segment');
            const fill = createElement('div', 'story-progress-fill');
            if (i < current) fill.classList.add('complete');
            if (i === current) fill.id = 'activeProgressFill';
            seg.appendChild(fill);
            container.appendChild(seg);
        }
    },

    _startTimer(duration) {
        this._stopTimer();

        const fill = document.getElementById('activeProgressFill');
        if (fill) {
            fill.style.transition = `width ${duration}ms linear`;
            requestAnimationFrame(() => {
                fill.style.width = '100%';
            });
        }

        this.state.timer = setTimeout(() => {
            this._nextStory();
        }, duration);
    },

    _stopTimer() {
        clearTimeout(this.state.timer);
        this.state.timer = null;

        const fill = document.getElementById('activeProgressFill');
        if (fill) {
            fill.style.transition = 'none';
            const computed = getComputedStyle(fill).width;
            fill.style.width = computed;
        }
    },

    _nextStory() {
        const userStory = this.state.stories[this.state.currentUserIndex];
        if (!userStory) { this.close(); return; }

        if (this.state.currentStoryIndex < userStory.stories.length - 1) {
            this.state.currentStoryIndex++;
            this._showCurrentStory();
        } else {
            this._nextUser();
        }
    },

    _prevStory() {
        if (this.state.currentStoryIndex > 0) {
            this.state.currentStoryIndex--;
            this._showCurrentStory();
        } else {
            // Previous user
            if (this.state.currentUserIndex > 0) {
                this.state.currentUserIndex--;
                const prevUser = this.state.stories[this.state.currentUserIndex];
                this.state.currentStoryIndex = 0;
                this._showCurrentStory();
            }
        }
    },

    _nextUser() {
        if (this.state.currentUserIndex < this.state.stories.length - 1) {
            this.state.currentUserIndex++;
            this.state.currentStoryIndex = 0;
            this._showCurrentStory();
        } else {
            this.close();
        }
    },

    async _createStory() {
        try {
            const files = await API.pickMedia({ multiple: false, allowVideo: true });
            if (!files || files.length === 0) return;

            const file = files[0];
            const mediaType = file.mime?.startsWith('video') ? 'video' : 'image';

            Ondes.UI.showToast({ message: 'Publication de la story...', type: 'info' });

            await API.createStory({
                media: file.path,
                media_type: mediaType
            });

            Ondes.UI.showToast({ message: 'Story publiée !', type: 'success' });
            await this.load(); // Refresh
        } catch (e) {
            console.error('[Stories] create:', e);
            try { Ondes.UI.showToast({ message: 'Erreur lors de la publication', type: 'error' }); } catch {}
        }
    },

    /** Bind viewer touch/click events */
    bindViewerEvents() {
        const viewer = document.getElementById('storyViewer');
        if (!viewer) return;

        document.getElementById('storyTapLeft')?.addEventListener('click', () => this._prevStory());
        document.getElementById('storyTapRight')?.addEventListener('click', () => this._nextStory());
        document.getElementById('storyCloseBtn')?.addEventListener('click', () => this.close());

        // Pause on hold
        let holdTimer;
        viewer.addEventListener('touchstart', (e) => {
            if (e.target.closest('.story-close-btn')) return;
            holdTimer = setTimeout(() => {
                this._stopTimer();
                this.state.isPaused = true;
            }, 200);
        });
        viewer.addEventListener('touchend', () => {
            clearTimeout(holdTimer);
            if (this.state.isPaused) {
                this.state.isPaused = false;
                // Resume
                const fill = document.getElementById('activeProgressFill');
                if (fill) {
                    const remaining = 100 - parseFloat(getComputedStyle(fill).width) / fill.parentElement.offsetWidth * 100;
                    const userStory = this.state.stories[this.state.currentUserIndex];
                    const story = userStory?.stories[this.state.currentStoryIndex];
                    const totalDuration = ((story?.duration || 5) * 1000);
                    const remainingDuration = totalDuration * (remaining / 100);
                    fill.style.transition = `width ${remainingDuration}ms linear`;
                    fill.style.width = '100%';
                    this.state.timer = setTimeout(() => this._nextStory(), remainingDuration);
                }
            }
        });
    }
};
