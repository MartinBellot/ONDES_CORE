/**
 * Ondes Social — Comments Manager
 * Bottom sheet with threaded comments
 */

const CommentsManager = {
    state: {
        currentPostUuid: null,
        comments: [],
        replyingTo: null,   // { uuid, username }
    },

    /** Open comments sheet for a post */
    async open(postUuid) {
        this.state.currentPostUuid = postUuid;
        this.state.replyingTo = null;
        this.state.comments = [];

        const modal = document.getElementById('commentsModal');
        modal.classList.add('active');

        const list = document.getElementById('commentsList');
        list.innerHTML = '<div class="feed-loading"><div class="spinner"></div></div>';

        // Reset reply indicator
        this._updateReplyUI();

        try {
            const response = await API.getComments(postUuid);
            this.state.comments = response.comments || [];
            this._renderComments(list);
        } catch (e) {
            console.error('[Comments]', e);
            list.innerHTML = '<div class="empty-state"><p>Impossible de charger les commentaires</p></div>';
        }
    },

    close() {
        const modal = document.getElementById('commentsModal');
        modal.classList.remove('active');
        this.state.currentPostUuid = null;
        this.state.replyingTo = null;
    },

    /** Open a full post detail (from discover/profile grid) */
    openPostDetail(post) {
        // For now, open comments sheet which shows the post context
        this.open(post.uuid);
    },

    _renderComments(container) {
        container.innerHTML = '';

        if (this.state.comments.length === 0) {
            container.innerHTML = `
                <div class="empty-state">
                    ${icon('comment')}
                    <h3>Pas encore de commentaire</h3>
                    <p>Soyez le premier à commenter</p>
                </div>
            `;
            return;
        }

        this.state.comments.forEach(comment => {
            container.appendChild(this._renderComment(comment));
        });
    },

    _renderComment(comment, isReply = false) {
        const div = createElement('div', 'comment-item');
        const avatar = getAvatar(comment.user);

        div.innerHTML = `
            <img class="avatar ${isReply ? 'avatar-xs' : 'avatar-sm'}" src="${avatar}" alt="${comment.user.username}"
                 onerror="this.src='${defaultAvatar(comment.user.username)}'">
            <div class="comment-body">
                <div>
                    <span class="comment-username">${comment.user.username}</span>
                    <span class="comment-text">${this._escapeHtml(comment.content)}</span>
                </div>
                <div class="comment-meta">
                    <span class="comment-time">${timeAgo(comment.created_at)}</span>
                    ${comment.likes_count > 0 ? `<span class="comment-like-count">${comment.likes_count} j'aime</span>` : ''}
                    ${!isReply ? `<span class="comment-reply-btn" data-comment-uuid="${comment.uuid}" data-username="${comment.user.username}">Répondre</span>` : ''}
                    <button class="comment-like-btn ${comment.is_liked ? 'liked' : ''}" data-comment-uuid="${comment.uuid}">
                        ${comment.is_liked ? icon('heartFilled') : icon('heart')}
                    </button>
                </div>
                ${!isReply && comment.replies_count > 0 ? `
                    <div class="comment-replies-toggle" data-comment-uuid="${comment.uuid}" data-loaded="false">
                        — Voir ${comment.replies_count} réponse${comment.replies_count > 1 ? 's' : ''}
                    </div>
                    <div class="comment-replies" id="replies-${comment.uuid}" style="display:none"></div>
                ` : ''}
            </div>
        `;

        // Reply button
        div.querySelector('.comment-reply-btn')?.addEventListener('click', (e) => {
            this.state.replyingTo = {
                uuid: e.target.dataset.commentUuid,
                username: e.target.dataset.username
            };
            this._updateReplyUI();
            document.getElementById('commentInput')?.focus();
        });

        // Like button
        div.querySelector('.comment-like-btn')?.addEventListener('click', async (e) => {
            const btn = e.currentTarget;
            const uuid = btn.dataset.commentUuid;
            comment.is_liked = !comment.is_liked;
            btn.className = `comment-like-btn ${comment.is_liked ? 'liked' : ''}`;
            btn.innerHTML = comment.is_liked ? icon('heartFilled') : icon('heart');
            try { await API.likeComment(uuid); } catch {}
        });

        // Load replies toggle
        div.querySelector('.comment-replies-toggle')?.addEventListener('click', async (e) => {
            const toggle = e.currentTarget;
            const uuid = toggle.dataset.commentUuid;
            const repliesContainer = div.querySelector(`#replies-${uuid}`);

            if (toggle.dataset.loaded === 'true') {
                const visible = repliesContainer.style.display !== 'none';
                repliesContainer.style.display = visible ? 'none' : 'flex';
                toggle.textContent = visible
                    ? `— Voir ${comment.replies_count} réponse${comment.replies_count > 1 ? 's' : ''}`
                    : `— Masquer les réponses`;
                return;
            }

            toggle.textContent = 'Chargement...';
            try {
                const response = await API.getCommentReplies(uuid);
                const replies = response.replies || [];
                repliesContainer.innerHTML = '';
                replies.forEach(reply => {
                    repliesContainer.appendChild(this._renderComment(reply, true));
                });
                repliesContainer.style.display = 'flex';
                toggle.dataset.loaded = 'true';
                toggle.textContent = '— Masquer les réponses';
            } catch {
                toggle.textContent = 'Erreur de chargement';
            }
        });

        // Username click
        div.querySelector('.comment-username')?.addEventListener('click', () => {
            this.close();
            ProfileManager.openUser(comment.user.id);
        });

        return div;
    },

    _updateReplyUI() {
        const indicator = document.getElementById('replyIndicator');
        if (!indicator) return;

        if (this.state.replyingTo) {
            indicator.style.display = 'flex';
            indicator.querySelector('.reply-to-name').textContent = this.state.replyingTo.username;
        } else {
            indicator.style.display = 'none';
        }
    },

    /** Send comment */
    async send() {
        const input = document.getElementById('commentInput');
        const content = input?.value.trim();
        if (!content || !this.state.currentPostUuid) return;

        input.value = '';
        const parentUuid = this.state.replyingTo?.uuid || null;
        this.state.replyingTo = null;
        this._updateReplyUI();

        try {
            const response = await API.addComment(this.state.currentPostUuid, content, parentUuid);
            if (response?.comment) {
                const list = document.getElementById('commentsList');
                const emptyState = list.querySelector('.empty-state');
                if (emptyState) emptyState.remove();

                if (parentUuid) {
                    // Add to replies section
                    const repliesContainer = document.getElementById(`replies-${parentUuid}`);
                    if (repliesContainer) {
                        repliesContainer.style.display = 'flex';
                        repliesContainer.appendChild(this._renderComment(response.comment, true));
                    }
                } else {
                    list.appendChild(this._renderComment(response.comment));
                    list.scrollTop = list.scrollHeight;
                }
            }
            try { Ondes.Device.hapticFeedback('light'); } catch {}
        } catch (e) {
            console.error('[Comments] send:', e);
            try { Ondes.UI.showToast({ message: 'Erreur d\'envoi', type: 'error' }); } catch {}
        }
    },

    _escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    },

    /** Bind input events */
    bindEvents() {
        const input = document.getElementById('commentInput');
        const sendBtn = document.getElementById('commentSendBtn');
        const closeBtn = document.getElementById('closeCommentsBtn');
        const cancelReply = document.getElementById('cancelReply');

        input?.addEventListener('input', () => {
            sendBtn?.classList.toggle('active', input.value.trim().length > 0);
        });

        input?.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                this.send();
            }
        });

        sendBtn?.addEventListener('click', () => this.send());
        closeBtn?.addEventListener('click', () => this.close());
        cancelReply?.addEventListener('click', () => {
            this.state.replyingTo = null;
            this._updateReplyUI();
        });
    }
};
