/**
 * Instagram Demo - Ondes.Social Integration
 * Demonstrates full social features using the Ondes bridge
 */

// App State
const state = {
    currentUser: null,
    feed: [],
    stories: [],
    currentStory: null,
    currentStoryIndex: 0,
    storyTimer: null,
    selectedMedia: [],
    loading: true
};

// DOM Elements
const elements = {
    feedContainer: document.getElementById('feedContainer'),
    feedPosts: document.getElementById('feed'),
    feedLoading: document.getElementById('feedLoading'),
    feedEmpty: document.getElementById('feedEmpty'),
    storiesScroll: document.getElementById('storiesScroll'),
    createPostModal: document.getElementById('createPostModal'),
    storyViewer: document.getElementById('storyViewer'),
    commentsModal: document.getElementById('commentsModal'),
    navAvatar: document.getElementById('navAvatar')
};

// Debug: Check elements
console.log('[DEBUG] Elements loaded:', {
    createPostModal: !!elements.createPostModal,
    feedContainer: !!elements.feedContainer,
    navAvatar: !!elements.navAvatar
});

// Initialize app when Ondes bridge is ready
// ⚠️ IMPORTANT: Use 'OndesReady' NOT 'DOMContentLoaded' - the SDK is injected after DOM is ready
document.addEventListener('OndesReady', async () => {
    console.log('[DEBUG] OndesReady fired - Ondes SDK is available');
    try {
        await initializeApp();
    } catch (error) {
        console.error('Failed to initialize app:', error);
        showError('Failed to load. Please check your connection.');
    }
});

async function initializeApp() {
    // Get current user profile
    state.currentUser = await Ondes.Social.getProfile();
    
    // Update nav avatar
    if (state.currentUser && state.currentUser.profile_picture) {
        elements.navAvatar.src = state.currentUser.profile_picture;
    }

    console.log('[DEBUG] Current user:', JSON.stringify(state.currentUser));
    
    // Load feed and stories in parallel
    await Promise.all([
        loadFeed(),
        loadStories()
    ]);
    
    state.loading = false;
}

// ==================== FEED ====================

async function loadFeed() {
    try {
        elements.feedLoading.classList.remove('hidden');
        elements.feedEmpty.classList.add('hidden');
        
        const response = await Ondes.Social.getFeed({ limit: 20 });
        console.log('[DEBUG] getFeed response:', JSON.stringify(response).substring(0, 500));
        state.feed = response.posts || response;
        
        // Debug: Log first post media
        if (state.feed.length > 0 && state.feed[0].media) {
            console.log('[DEBUG] First post media:', JSON.stringify(state.feed[0].media));
        }
        
        elements.feedLoading.classList.add('hidden');
        
        if (state.feed.length === 0) {
            elements.feedEmpty.classList.remove('hidden');
        } else {
            renderFeed();
        }
    } catch (error) {
        console.error('Error loading feed:', error);
        elements.feedLoading.classList.add('hidden');
        showError('Failed to load feed');
    }
}

function renderFeed() {
    elements.feedPosts.innerHTML = '';
    
    state.feed.forEach(post => {
        const postElement = createPostElement(post);
        elements.feedPosts.appendChild(postElement);
    });
}

function createPostElement(post) {
    const article = document.createElement('article');
    article.className = 'post-card';
    article.dataset.postId = post.uuid;
    
    // Format time
    const timeAgo = formatTimeAgo(new Date(post.created_at));
    
    // Media content
    let mediaHTML = '';
    if (post.media && post.media.length > 0) {
        if (post.media.length === 1) {
            mediaHTML = createSingleMediaHTML(post.media[0]);
        } else {
            mediaHTML = createCarouselHTML(post.media);
        }
    }
    
    // Tags
    let tagsHTML = '';
    if (post.tags && post.tags.length > 0) {
        tagsHTML = `<div class="post-tags">${post.tags.map(t => '#' + t).join(' ')}</div>`;
    }
    
    article.innerHTML = `
        <header class="post-header">
            <img class="post-avatar" src="${post.author.profile_picture || 'https://via.placeholder.com/36'}" alt="${post.author.username}">
            <div class="post-user-info">
                <div class="post-username">${post.author.username}</div>
                ${post.location ? `<div class="post-location">${post.location}</div>` : ''}
            </div>
            <button class="post-options-btn" onclick="showPostOptions('${post.uuid}')">•••</button>
        </header>
        
        <div class="post-media" ondblclick="handleDoubleTap(event, '${post.uuid}')">
            ${mediaHTML}
            <div class="double-tap-heart">
                <svg viewBox="0 0 24 24"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>
            </div>
        </div>
        
        <div class="post-actions">
            <button class="action-btn ${post.user_has_liked ? 'liked' : ''}" onclick="toggleLike('${post.uuid}')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/>
                </svg>
            </button>
            <button class="action-btn" onclick="showComments('${post.uuid}')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
                </svg>
            </button>
            <button class="action-btn" onclick="sharePost('${post.uuid}')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <line x1="22" y1="2" x2="11" y2="13"></line>
                    <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
                </svg>
            </button>
            <button class="action-btn bookmark-btn ${post.user_has_bookmarked ? 'bookmarked' : ''}" onclick="toggleBookmark('${post.uuid}')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/>
                </svg>
            </button>
        </div>
        
        <div class="post-likes">${formatLikes(post.likes_count)} likes</div>
        
        <div class="post-caption">
            <span class="username">${post.author.username}</span> ${post.content || ''}
        </div>
        
        ${tagsHTML}
        
        ${post.comments_count > 0 ? `
            <div class="post-comments-link" onclick="showComments('${post.uuid}')">
                View all ${post.comments_count} comments
            </div>
        ` : ''}
        
        <div class="post-time">${timeAgo}</div>
    `;
    
    return article;
}

function createSingleMediaHTML(media) {
    // API returns full URLs directly - no need to concatenate
    if (media.media_type === 'video') {
        return `
            <div class="video-player-container" data-video-id="${media.uuid}">
                <video id="video-${media.uuid}" 
                       data-hls="${media.hls_url || ''}" 
                       poster="${media.thumbnail_url || ''}"
                       playsinline muted loop
                       onclick="toggleVideoPlay(this)"></video>
                <div class="video-play-btn" onclick="toggleVideoPlayBtn(this)">
                    <svg viewBox="0 0 24 24" fill="white">
                        <polygon points="5 3 19 12 5 21 5 3"/>
                    </svg>
                </div>
                <div class="video-mute-btn" onclick="toggleVideoMute(this)">
                    <svg class="muted-icon" viewBox="0 0 24 24" fill="white">
                        <path d="M11 5L6 9H2v6h4l5 4V5z"/>
                        <line x1="23" y1="9" x2="17" y2="15" stroke="white" stroke-width="2"/>
                        <line x1="17" y1="9" x2="23" y2="15" stroke="white" stroke-width="2"/>
                    </svg>
                    <svg class="unmuted-icon" viewBox="0 0 24 24" fill="white" style="display:none">
                        <path d="M11 5L6 9H2v6h4l5 4V5z"/>
                        <path d="M15.54 8.46a5 5 0 0 1 0 7.07" stroke="white" stroke-width="2" fill="none"/>
                        <path d="M19.07 4.93a10 10 0 0 1 0 14.14" stroke="white" stroke-width="2" fill="none"/>
                    </svg>
                </div>
            </div>
        `;
    } else {
        return `<img src="${media.display_url}" alt="">`;
    }
}

function createCarouselHTML(mediaItems) {
    const items = mediaItems.map((media, index) => {
        // API returns full URLs directly
        const content = media.media_type === 'video' 
            ? `<video src="${media.display_url}" playsinline muted loop></video>`
            : `<img src="${media.display_url}" alt="">`;
        return `<div class="media-carousel-item">${content}</div>`;
    }).join('');
    
    const dots = mediaItems.map((_, index) => 
        `<div class="media-dot ${index === 0 ? 'active' : ''}"></div>`
    ).join('');
    
    return `
        <div class="media-carousel">${items}</div>
        <div class="media-indicator">${dots}</div>
    `;
}

// ==================== STORIES ====================

async function loadStories() {
    try {
        const response = await Ondes.Social.getStories();
        state.stories = response.stories || response;
        renderStories();
    } catch (error) {
        console.error('Error loading stories:', error);
    }
}

function renderStories() {
    elements.storiesScroll.innerHTML = '';
    
    // Add "Your Story" button
    const yourStory = document.createElement('div');
    yourStory.className = 'story-item';
    yourStory.innerHTML = `
        <div class="story-ring" style="background: transparent;">
            <div class="story-avatar">
                <img src="${state.currentUser?.profile_picture || 'https://via.placeholder.com/64'}" alt="Your story">
                <div class="add-story-badge">+</div>
            </div>
        </div>
        <span class="story-username">Your story</span>
    `;
    yourStory.onclick = () => createStory();
    elements.storiesScroll.appendChild(yourStory);
    
    // Add other users' stories
    state.stories.forEach((userStory, index) => {
        const storyItem = document.createElement('div');
        storyItem.className = 'story-item';
        const hasUnviewed = userStory.stories.some(s => !s.viewed);
        
        storyItem.innerHTML = `
            <div class="story-ring ${hasUnviewed ? '' : 'viewed'}">
                <div class="story-avatar">
                    <img src="${userStory.user.profile_picture || 'https://via.placeholder.com/64'}" alt="${userStory.user.username}">
                </div>
            </div>
            <span class="story-username">${userStory.user.username}</span>
        `;
        storyItem.onclick = () => openStoryViewer(index);
        elements.storiesScroll.appendChild(storyItem);
    });
}

function openStoryViewer(userIndex) {
    if (!state.stories[userIndex]) return;
    
    state.currentStory = state.stories[userIndex];
    state.currentStoryIndex = 0;
    
    elements.storyViewer.classList.add('active');
    showCurrentStory();
}

function showCurrentStory() {
    const userStory = state.currentStory;
    const story = userStory.stories[state.currentStoryIndex];
    
    if (!story) {
        closeStoryViewer();
        return;
    }
    
    // Check if this is the user's own story
    const isOwnStory = userStory.user.id === state.currentUser?.id;
    
    // Update header info
    document.getElementById('story-viewer-avatar').src = userStory.user.profile_picture || 'https://via.placeholder.com/32';
    document.getElementById('story-viewer-username').textContent = userStory.user.username;
    document.getElementById('story-viewer-time').textContent = formatTimeAgo(new Date(story.created_at));
    
    // Update progress bars
    const progressContainer = document.getElementById('story-progress-container');
    progressContainer.innerHTML = userStory.stories.map((_, i) => `
        <div class="story-progress">
            <div class="story-progress-fill" style="width: ${i < state.currentStoryIndex ? '100%' : '0%'}"></div>
        </div>
    `).join('');
    
    // Show content - API returns full URLs in media_url and hls_url
    const contentContainer = document.getElementById('story-content');
    if (story.media_type === 'video') {
        contentContainer.innerHTML = `
            <video src="${story.hls_url || story.media_url}" autoplay playsinline muted></video>
            ${isOwnStory ? `<button class="delete-story-btn" onclick="deleteCurrentStory('${story.uuid}')">🗑️</button>` : ''}
        `;
    } else {
        contentContainer.innerHTML = `
            <img src="${story.media_url}" alt="">
            ${isOwnStory ? `<button class="delete-story-btn" onclick="deleteCurrentStory('${story.uuid}')">🗑️</button>` : ''}
        `;
    }
    
    // Mark as viewed
    Ondes.Social.viewStory(story.uuid);
    
    // Start progress timer
    startStoryProgress();
}

async function deleteCurrentStory(storyUuid) {
    if (state.storyTimer) {
        clearInterval(state.storyTimer);
    }
    
    if (!confirm('Delete this story?')) {
        startStoryProgress();
        return;
    }
    
    try {
        await Ondes.Social.deleteStory(storyUuid);
        
        // Remove from current user's stories
        const userStoryIndex = state.stories.findIndex(s => s.user.id === state.currentUser?.id);
        if (userStoryIndex !== -1) {
            state.stories[userStoryIndex].stories = state.stories[userStoryIndex].stories.filter(s => s.uuid !== storyUuid);
            
            // If no more stories, remove user from stories list
            if (state.stories[userStoryIndex].stories.length === 0) {
                state.stories.splice(userStoryIndex, 1);
                closeStoryViewer();
                renderStories();
                showToast('Story deleted');
                return;
            }
            
            // Update current story state
            state.currentStory = state.stories[userStoryIndex];
            if (state.currentStoryIndex >= state.currentStory.stories.length) {
                state.currentStoryIndex = state.currentStory.stories.length - 1;
            }
        }
        
        showCurrentStory();
        renderStories();
        showToast('Story deleted');
    } catch (error) {
        console.error('Error deleting story:', error);
        showToast('Failed to delete story');
        startStoryProgress();
    }
}

function startStoryProgress() {
    if (state.storyTimer) {
        clearInterval(state.storyTimer);
    }
    
    const progressBars = document.querySelectorAll('.story-progress-fill');
    const currentBar = progressBars[state.currentStoryIndex];
    let progress = 0;
    const duration = 5000; // 5 seconds per story
    const interval = 50;
    
    state.storyTimer = setInterval(() => {
        progress += (interval / duration) * 100;
        currentBar.style.width = `${progress}%`;
        
        if (progress >= 100) {
            clearInterval(state.storyTimer);
            nextStory();
        }
    }, interval);
}

function nextStory() {
    const userStory = state.currentStory;
    
    if (state.currentStoryIndex < userStory.stories.length - 1) {
        state.currentStoryIndex++;
        showCurrentStory();
    } else {
        // Move to next user's stories
        const currentUserIndex = state.stories.findIndex(s => s.user.uuid === userStory.user.uuid);
        if (currentUserIndex < state.stories.length - 1) {
            state.currentStory = state.stories[currentUserIndex + 1];
            state.currentStoryIndex = 0;
            showCurrentStory();
        } else {
            closeStoryViewer();
        }
    }
}

function prevStory() {
    if (state.currentStoryIndex > 0) {
        state.currentStoryIndex--;
        showCurrentStory();
    } else {
        // Move to previous user's stories
        const currentUserIndex = state.stories.findIndex(s => s.user.uuid === state.currentStory.user.uuid);
        if (currentUserIndex > 0) {
            state.currentStory = state.stories[currentUserIndex - 1];
            state.currentStoryIndex = state.stories[currentUserIndex - 1].stories.length - 1;
            showCurrentStory();
        }
    }
}

function closeStoryViewer() {
    if (state.storyTimer) {
        clearInterval(state.storyTimer);
    }
    elements.storyViewer.classList.remove('active');
    state.currentStory = null;
}

// ==================== INTERACTIONS ====================

async function toggleLike(postUuid) {
    const post = state.feed.find(p => p.uuid === postUuid);
    if (!post) return;
    
    const postCard = document.querySelector(`.post-card[data-post-id="${postUuid}"]`);
    const likeBtn = postCard.querySelector('.action-btn');
    const likesCount = postCard.querySelector('.post-likes');
    
    try {
        if (post.user_has_liked) {
            await Ondes.Social.unlike(postUuid);
            post.user_has_liked = false;
            post.likes_count--;
            likeBtn.classList.remove('liked');
        } else {
            await Ondes.Social.like(postUuid);
            post.user_has_liked = true;
            post.likes_count++;
            likeBtn.classList.add('liked');
        }
        likesCount.textContent = formatLikes(post.likes_count) + ' likes';
    } catch (error) {
        console.error('Error toggling like:', error);
    }
}

function handleDoubleTap(event, postUuid) {
    const post = state.feed.find(p => p.uuid === postUuid);
    if (!post || post.user_has_liked) return;
    
    // Show heart animation
    const heart = event.currentTarget.querySelector('.double-tap-heart');
    heart.classList.add('animate');
    setTimeout(() => heart.classList.remove('animate'), 800);
    
    // Like the post
    toggleLike(postUuid);
}

async function toggleBookmark(postUuid) {
    const post = state.feed.find(p => p.uuid === postUuid);
    if (!post) return;
    
    const postCard = document.querySelector(`.post-card[data-post-id="${postUuid}"]`);
    const bookmarkBtn = postCard.querySelector('.bookmark-btn');
    
    try {
        if (post.user_has_bookmarked) {
            await Ondes.Social.removeBookmark(postUuid);
            post.user_has_bookmarked = false;
            bookmarkBtn.classList.remove('bookmarked');
        } else {
            await Ondes.Social.bookmark(postUuid);
            post.user_has_bookmarked = true;
            bookmarkBtn.classList.add('bookmarked');
        }
    } catch (error) {
        console.error('Error toggling bookmark:', error);
    }
}

// ==================== COMMENTS ====================

let currentCommentsPost = null;

async function showComments(postUuid) {
    currentCommentsPost = postUuid;
    elements.commentsModal.classList.add('active');
    
    const commentsList = document.getElementById('comments-list');
    commentsList.innerHTML = '<div class="feed-loading"><div class="spinner"></div></div>';
    
    try {
        const response = await Ondes.Social.getComments(postUuid);
        const comments = response.comments || response;
        
        if (comments.length === 0) {
            commentsList.innerHTML = '<p style="text-align: center; color: var(--text-secondary); padding: 40px;">No comments yet. Be the first!</p>';
        } else {
            renderComments(comments);
        }
    } catch (error) {
        console.error('Error loading comments:', error);
        commentsList.innerHTML = '<p style="text-align: center; color: var(--text-secondary);">Failed to load comments</p>';
    }
}

function renderComments(comments) {
    const commentsList = document.getElementById('comments-list');
    commentsList.innerHTML = comments.map(comment => {
        // Bridge sends 'user' not 'author' for comments, and 'is_liked' not 'user_has_liked'
        const commentUser = comment.user || comment.author;
        const isOwnComment = commentUser?.id === state.currentUser?.id;
        return `
            <div class="comment-item" data-comment-id="${comment.uuid}">
                <img class="comment-avatar" src="${commentUser?.profile_picture || 'https://via.placeholder.com/32'}" alt="${commentUser?.username || ''}">
                <div class="comment-content">
                    <span class="comment-username">${commentUser?.username || 'Unknown'}</span>
                    <p class="comment-text">${comment.content}</p>
                    <div class="comment-meta">
                        <span>${formatTimeAgo(new Date(comment.created_at))}</span>
                        <span>${comment.likes_count} likes</span>
                        <button class="comment-like-btn" onclick="likeComment('${comment.uuid}')">
                            ${comment.is_liked ? 'Unlike' : 'Like'}
                        </button>
                        ${isOwnComment ? `
                            <button class="comment-delete-btn" onclick="deleteComment('${comment.uuid}')">Delete</button>
                        ` : ''}
                    </div>
                </div>
            </div>
        `;
    }).join('');
}

async function deleteComment(commentUuid) {
    if (!confirm('Delete this comment?')) return;
    
    try {
        await Ondes.Social.deleteComment(commentUuid);
        
        // Update comment count
        const post = state.feed.find(p => p.uuid === currentCommentsPost);
        if (post) {
            post.comments_count--;
        }
        
        // Refresh comments
        showComments(currentCommentsPost);
        showToast('Comment deleted');
    } catch (error) {
        console.error('Error deleting comment:', error);
        showToast('Failed to delete comment');
    }
}

async function postComment() {
    const input = document.getElementById('comment-input');
    const content = input.value.trim();
    
    if (!content || !currentCommentsPost) return;
    
    try {
        await Ondes.Social.comment(currentCommentsPost, content);
        input.value = '';
        
        // Refresh comments
        showComments(currentCommentsPost);
        
        // Update comment count in feed
        const post = state.feed.find(p => p.uuid === currentCommentsPost);
        if (post) {
            post.comments_count++;
            const postCard = document.querySelector(`.post-card[data-post-id="${currentCommentsPost}"]`);
            const commentsLink = postCard.querySelector('.post-comments-link');
            if (commentsLink) {
                commentsLink.textContent = `View all ${post.comments_count} comments`;
            }
        }
    } catch (error) {
        console.error('Error posting comment:', error);
    }
}

async function likeComment(commentUuid) {
    try {
        await Ondes.Social.likeComment(commentUuid);
        // Refresh comments
        showComments(currentCommentsPost);
    } catch (error) {
        console.error('Error liking comment:', error);
    }
}

function closeCommentsModal() {
    elements.commentsModal.classList.remove('active');
    currentCommentsPost = null;
}

// ==================== CREATE POST ====================

function openCreatePost() {
    const modal = document.getElementById('createPostModal');
    
    state.selectedMedia = [];
    updateMediaPreview();
    
    // Reset form
    const captionInput = document.getElementById('postCaption');
    const tagsInput = document.getElementById('tagsInput');
    const visibilitySelect = document.getElementById('visibilitySelect');
    if (captionInput) captionInput.value = '';
    if (tagsInput) tagsInput.value = '';
    if (visibilitySelect) visibilitySelect.value = 'followers';
    
    // Hide publishing overlay if visible
    const overlay = document.getElementById('publishingOverlay');
    if (overlay) overlay.classList.remove('active');
    
    if (modal) {
        modal.classList.add('active');
    }
}

function closeCreatePost() {
    elements.createPostModal.classList.remove('active');
    state.selectedMedia = [];
}

async function selectMedia() {
    try {
        console.log('[DEBUG] selectMedia called');
        const result = await Ondes.Social.pickMedia({ 
            multiple: true,
            maxFiles: 10,
            allowVideo: true
        });
        
        console.log('[DEBUG] pickMedia result:', JSON.stringify(result));
        
        if (result && result.length > 0) {
            state.selectedMedia = result;
            console.log('[DEBUG] selectedMedia set:', state.selectedMedia);
            updateMediaPreview();
        } else {
            console.log('[DEBUG] No media selected or empty result');
        }
    } catch (error) {
        console.error('Error selecting media:', error);
    }
}

function updateMediaPreview() {
    console.log('[DEBUG] updateMediaPreview called, selectedMedia:', state.selectedMedia);
    const container = document.getElementById('mediaPreviewContainer');
    const placeholder = document.getElementById('mediaPlaceholder');
    
    if (!container || !placeholder) {
        console.error('[DEBUG] updateMediaPreview: missing elements', { container: !!container, placeholder: !!placeholder });
        return;
    }
    
    if (!state.selectedMedia || state.selectedMedia.length === 0) {
        placeholder.style.display = 'flex';
        container.style.display = 'none';
        container.innerHTML = '';
    } else {
        placeholder.style.display = 'none';
        container.style.display = 'grid';
        container.innerHTML = state.selectedMedia.map((media, index) => {
            // Use previewUrl (base64) for images, as WebView can't access file:// paths
            const previewSrc = media.previewUrl || media.path;
            console.log('[DEBUG] Media item:', index, media.type, media.previewUrl ? 'base64' : media.path);
            
            if (media.type === 'video') {
                return `
                    <div class="media-preview-item">
                        <div class="video-placeholder">
                            <svg viewBox="0 0 24 24" fill="currentColor">
                                <polygon points="5 3 19 12 5 21 5 3"></polygon>
                            </svg>
                            <span>${media.name || 'Video'}</span>
                        </div>
                        <button class="remove-media-btn" onclick="removeMedia(${index})">×</button>
                    </div>
                `;
            } else {
                return `
                    <div class="media-preview-item">
                        <img src="${previewSrc}" alt="Preview ${index + 1}" onerror="this.parentElement.innerHTML='<div class=\\'media-error\\'>Error</div>'">
                        <button class="remove-media-btn" onclick="removeMedia(${index})">×</button>
                    </div>
                `;
            }
        }).join('');
    }
    
    // Update post button state
    const publishBtn = document.getElementById('publishBtn');
    console.log('[DEBUG] publishBtn:', publishBtn, 'disabled:', state.selectedMedia.length === 0);
    if (publishBtn) publishBtn.disabled = state.selectedMedia.length === 0;
}

function removeMedia(index) {
    state.selectedMedia.splice(index, 1);
    updateMediaPreview();
}

async function submitPost() {
    if (!state.selectedMedia || state.selectedMedia.length === 0) {
        return;
    }
    
    const caption = document.getElementById('postCaption')?.value || '';
    const visibility = document.getElementById('visibilitySelect')?.value || 'followers';
    const tags = (document.getElementById('tagsInput')?.value || '')
        .split(',')
        .map(t => t.trim())
        .filter(t => t.length > 0);
    
    // Show publishing overlay with animation
    const overlay = document.getElementById('publishingOverlay');
    const progressBar = document.getElementById('publishingProgressBar');
    const publishingText = document.getElementById('publishingText');
    
    if (overlay) {
        overlay.classList.add('active');
        if (progressBar) progressBar.style.width = '0%';
        if (publishingText) publishingText.textContent = 'Préparation...';
    }
    
    // Simulate progress
    let progress = 0;
    const progressInterval = setInterval(() => {
        progress += Math.random() * 15;
        if (progress > 90) progress = 90;
        if (progressBar) progressBar.style.width = `${progress}%`;
        if (progress > 30 && publishingText) publishingText.textContent = 'Envoi des médias...';
        if (progress > 60 && publishingText) publishingText.textContent = 'Publication...';
    }, 300);
    
    try {
        const mediaPaths = state.selectedMedia.map(m => m.path);
        
        await Ondes.Social.publish({
            content: caption,
            media: mediaPaths,
            visibility: visibility,
            tags: tags
        });
        
        // Complete progress
        clearInterval(progressInterval);
        if (progressBar) progressBar.style.width = '100%';
        if (publishingText) publishingText.textContent = 'Publié !';
        
        // Show success animation
        await showSuccessAnimation();
        
        // Close modal
        closeCreatePost();
        
        // Refresh content based on current page
        await refreshCurrentPageContent();
        
        // Show toast
        showToast('Post publié avec succès !');
        
    } catch (error) {
        console.error('Error creating post:', error);
        clearInterval(progressInterval);
        if (overlay) overlay.classList.remove('active');
        showToast('Erreur lors de la publication');
    }
}

// Show success animation
function showSuccessAnimation() {
    return new Promise((resolve) => {
        // Create success animation element if it doesn't exist
        let successEl = document.getElementById('successAnimation');
        if (!successEl) {
            successEl = document.createElement('div');
            successEl.id = 'successAnimation';
            successEl.className = 'success-animation';
            successEl.innerHTML = `
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="20 6 9 17 4 12"></polyline>
                </svg>
            `;
            document.body.appendChild(successEl);
        }
        
        // Trigger animation
        requestAnimationFrame(() => {
            successEl.classList.add('show');
            
            setTimeout(() => {
                successEl.classList.remove('show');
                setTimeout(resolve, 300);
            }, 800);
        });
    });
}

// Refresh content based on current page
async function refreshCurrentPageContent() {
    switch (currentPage) {
        case 'home':
            await loadFeed();
            window.scrollTo({ top: 0, behavior: 'smooth' });
            break;
        case 'profile':
            // Reload profile stats and posts
            await loadProfile(state.currentUser?.id);
            break;
        case 'search':
            // Stay on search, just update in background
            loadFeed();
            break;
        case 'reels':
            await loadReels();
            break;
        default:
            await loadFeed();
    }
}

// ==================== CREATE STORY ====================

async function createStory() {
    try {
        const result = await Ondes.Social.pickMedia({ 
            multiple: false,
            allowVideo: true
        });
        
        if (result && result.length > 0) {
            const media = result[0];
            
            // Show loading indicator
            showToast('Creating story...');
            
            await Ondes.Social.createStory({
                media: media.path,
                media_type: media.type
            });
            
            // Refresh stories
            await loadStories();
            showToast('Story created!');
        }
    } catch (error) {
        console.error('Error creating story:', error);
        showToast('Failed to create story');
    }
}

// ==================== NAVIGATION ====================

let currentPage = 'home';

function navigateTo(tab) {
    // Update active state
    document.querySelectorAll('.nav-item').forEach(item => item.classList.remove('active'));
    event.currentTarget.classList.add('active');
    
    // Hide all pages
    document.getElementById('feedContainer').classList.add('hidden');
    document.getElementById('searchPage').classList.add('hidden');
    document.getElementById('reelsPage').classList.add('hidden');
    document.getElementById('profilePage').classList.add('hidden');
    document.querySelector('.stories-container').classList.add('hidden');
    
    currentPage = tab;
    
    // Handle navigation
    switch(tab) {
        case 'home':
            document.getElementById('feedContainer').classList.remove('hidden');
            document.querySelector('.stories-container').classList.remove('hidden');
            break;
        case 'search':
            document.getElementById('searchPage').classList.remove('hidden');
            break;
        case 'create':
            openCreatePost();
            // Show home page in background
            document.getElementById('feedContainer').classList.remove('hidden');
            document.querySelector('.stories-container').classList.remove('hidden');
            break;
        case 'reels':
            document.getElementById('reelsPage').classList.remove('hidden');
            loadReels();
            break;
        case 'profile':
            document.getElementById('profilePage').classList.remove('hidden');
            loadProfile(state.currentUser?.id);
            break;
    }
}

// ==================== SEARCH PAGE ====================

let searchTimeout = null;

function initSearch() {
    const searchInput = document.getElementById('searchInput');
    if (searchInput) {
        searchInput.addEventListener('input', (e) => {
            const query = e.target.value.trim();
            
            // Debounce search
            clearTimeout(searchTimeout);
            
            if (query.length < 2) {
                document.getElementById('searchResults').innerHTML = `
                    <div class="search-placeholder">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                            <circle cx="11" cy="11" r="8"/>
                            <path d="m21 21-4.35-4.35"/>
                        </svg>
                        <p>Recherchez des utilisateurs par nom</p>
                    </div>
                `;
                return;
            }
            
            searchTimeout = setTimeout(() => searchUsers(query), 300);
        });
    }
}

async function searchUsers(query) {
    const resultsContainer = document.getElementById('searchResults');
    resultsContainer.innerHTML = '<div class="feed-loading"><div class="spinner"></div></div>';
    
    try {
        const results = await Ondes.Social.searchUsers(query);
        const users = results.users || results;
        
        if (users.length === 0) {
            resultsContainer.innerHTML = `
                <div class="search-placeholder">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                        <circle cx="11" cy="11" r="8"/>
                        <path d="m21 21-4.35-4.35"/>
                    </svg>
                    <p>Aucun utilisateur trouvé pour "${query}"</p>
                </div>
            `;
            return;
        }
        
        resultsContainer.innerHTML = users.map(user => `
            <div class="search-result-item" onclick="openUserProfile(${user.id})">
                <img class="search-avatar" src="${user.profile_picture || 'https://via.placeholder.com/50'}" alt="${user.username}">
                <div class="search-user-info">
                    <span class="search-username">${user.username}</span>
                    ${user.bio ? `<span class="search-bio">${user.bio.substring(0, 50)}${user.bio.length > 50 ? '...' : ''}</span>` : ''}
                </div>
                ${user.id !== state.currentUser?.id ? `
                    <button class="search-follow-btn ${user.is_following ? 'following' : ''}" 
                            onclick="event.stopPropagation(); toggleFollowFromSearch(${user.id}, this)">
                        ${user.is_following ? 'Abonné' : 'Suivre'}
                    </button>
                ` : ''}
            </div>
        `).join('');
    } catch (error) {
        console.error('Error searching users:', error);
        resultsContainer.innerHTML = `<p style="text-align: center; color: var(--text-secondary);">Erreur de recherche</p>`;
    }
}

async function toggleFollowFromSearch(userId, button) {
    const isFollowing = button.classList.contains('following');
    
    try {
        if (isFollowing) {
            await Ondes.Social.unfollow(userId);
            button.classList.remove('following');
            button.textContent = 'Suivre';
        } else {
            await Ondes.Social.follow(userId);
            button.classList.add('following');
            button.textContent = 'Abonné';
        }
    } catch (error) {
        console.error('Error toggling follow:', error);
    }
}

function openUserProfile(userId) {
    document.querySelectorAll('.nav-item').forEach(item => item.classList.remove('active'));
    document.getElementById('profileNavBtn').classList.add('active');
    
    document.getElementById('feedContainer').classList.add('hidden');
    document.getElementById('searchPage').classList.add('hidden');
    document.getElementById('reelsPage').classList.add('hidden');
    document.querySelector('.stories-container').classList.add('hidden');
    document.getElementById('profilePage').classList.remove('hidden');
    
    loadProfile(userId);
}

// ==================== PROFILE PAGE ====================

let profileState = {
    userId: null,
    isOwnProfile: false,
    currentTab: 'posts',
    posts: [],
    bookmarks: []
};

async function loadProfile(userId = null) {
    const targetUserId = userId || state.currentUser?.id;
    profileState.isOwnProfile = !userId || userId === state.currentUser?.id;
    
    try {
        // Load user profile
        const profile = await Ondes.Social.getProfile({ userId: targetUserId });
        
        // Store the actual userId from profile response
        profileState.userId = profile.id;
        
        // Update UI
        document.getElementById('profileAvatar').src = profile.profile_picture || 'https://via.placeholder.com/90';
        document.getElementById('profileUsername').textContent = profile.username;
        document.getElementById('profileBio').textContent = profile.bio || '';
        document.getElementById('postsCount').textContent = profile.posts_count || 0;
        document.getElementById('followersCount').textContent = profile.followers_count || 0;
        document.getElementById('followingCount').textContent = profile.following_count || 0;
        
        // Update action button
        const actionsContainer = document.getElementById('profileActions');
        if (profileState.isOwnProfile) {
            actionsContainer.innerHTML = `
                <button class="profile-btn" onclick="editProfile()">Modifier le profil</button>
            `;
        } else {
            actionsContainer.innerHTML = `
                <button class="profile-btn ${profile.is_following ? 'following' : 'primary'}" onclick="toggleProfileFollow()">
                    ${profile.is_following ? 'Abonné' : 'Suivre'}
                </button>
            `;
        }
        
        // Show/hide bookmarks tab (only for own profile)
        const bookmarksTab = document.querySelector('.profile-tab[data-tab="bookmarks"]');
        if (bookmarksTab) {
            bookmarksTab.style.display = profileState.isOwnProfile ? 'flex' : 'none';
        }
        
        // Load posts
        await loadProfilePosts();
        
    } catch (error) {
        console.error('Error loading profile:', error);
        showToast('Erreur lors du chargement du profil');
    }
}

async function loadProfilePosts() {
    const grid = document.getElementById('profileGrid');
    grid.innerHTML = '<div class="feed-loading"><div class="spinner"></div></div>';
    
    try {
        const response = await Ondes.Social.getUserPosts(profileState.userId);
        profileState.posts = response.posts || response;
        
        renderProfileGrid(profileState.posts);
    } catch (error) {
        console.error('Error loading posts:', error);
        grid.innerHTML = '<p style="text-align: center; color: var(--text-secondary);">Erreur de chargement</p>';
    }
}

async function loadProfileBookmarks() {
    const grid = document.getElementById('profileGrid');
    grid.innerHTML = '<div class="feed-loading"><div class="spinner"></div></div>';
    
    try {
        const response = await Ondes.Social.getBookmarks();
        profileState.bookmarks = response.posts || response;
        
        renderProfileGrid(profileState.bookmarks);
    } catch (error) {
        console.error('Error loading bookmarks:', error);
        grid.innerHTML = '<p style="text-align: center; color: var(--text-secondary);">Erreur de chargement</p>';
    }
}

function renderProfileGrid(posts) {
    const grid = document.getElementById('profileGrid');
    
    if (posts.length === 0) {
        grid.innerHTML = `
            <div class="profile-empty">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                    <rect x="3" y="3" width="18" height="18" rx="2"/>
                </svg>
                <p>Aucun post</p>
            </div>
        `;
        return;
    }
    
    grid.innerHTML = posts.map(post => {
        const media = post.media?.[0];
        // API returns full URLs in display_url and thumbnail_url
        const thumbnail = media?.thumbnail_url || media?.display_url || 'https://via.placeholder.com/150';
        const isVideo = media?.media_type === 'video';

        return `
            <div class="profile-grid-item" onclick="openPostFromProfile('${post.uuid}')">
                <img src="${thumbnail}" alt="">
                ${isVideo ? `
                    <div class="grid-video-icon">
                        <svg viewBox="0 0 24 24" fill="white">
                            <polygon points="5 3 19 12 5 21 5 3"/>
                        </svg>
                    </div>
                ` : ''}
                ${post.media?.length > 1 ? `
                    <div class="grid-multi-icon">
                        <svg viewBox="0 0 24 24" fill="white">
                            <rect x="2" y="6" width="16" height="12" rx="2"/>
                            <rect x="6" y="2" width="16" height="12" rx="2"/>
                        </svg>
                    </div>
                ` : ''}
            </div>
        `;
    }).join('');
}

function switchProfileTab(tab) {
    profileState.currentTab = tab;
    
    document.querySelectorAll('.profile-tab').forEach(t => t.classList.remove('active'));
    document.querySelector(`.profile-tab[data-tab="${tab}"]`).classList.add('active');
    
    if (tab === 'posts') {
        loadProfilePosts();
    } else if (tab === 'bookmarks') {
        loadProfileBookmarks();
    }
}

async function toggleProfileFollow() {
    const btn = document.querySelector('#profileActions .profile-btn');
    const isFollowing = btn.classList.contains('following');
    
    try {
        if (isFollowing) {
            await Ondes.Social.unfollow(profileState.userId);
            btn.classList.remove('following');
            btn.classList.add('primary');
            btn.textContent = 'Suivre';
            
            const count = parseInt(document.getElementById('followersCount').textContent) - 1;
            document.getElementById('followersCount').textContent = count;
        } else {
            await Ondes.Social.follow(profileState.userId);
            btn.classList.add('following');
            btn.classList.remove('primary');
            btn.textContent = 'Abonné';
            
            const count = parseInt(document.getElementById('followersCount').textContent) + 1;
            document.getElementById('followersCount').textContent = count;
        }
    } catch (error) {
        console.error('Error toggling follow:', error);
        showToast('Erreur');
    }
}

async function showFollowers() {
    document.getElementById('usersModalTitle').textContent = 'Followers';
    document.getElementById('usersModal').classList.add('active');
    
    const listContainer = document.getElementById('usersList');
    listContainer.innerHTML = '<div class="feed-loading"><div class="spinner"></div></div>';
    
    try {
        const response = await Ondes.Social.getFollowers(profileState.userId);
        const users = response.followers || response;
        renderUsersList(users);
    } catch (error) {
        console.error('Error loading followers:', error);
        listContainer.innerHTML = '<p style="text-align: center;">Erreur de chargement</p>';
    }
}

async function showFollowing() {
    document.getElementById('usersModalTitle').textContent = 'Abonnements';
    document.getElementById('usersModal').classList.add('active');
    
    const listContainer = document.getElementById('usersList');
    listContainer.innerHTML = '<div class="feed-loading"><div class="spinner"></div></div>';
    
    try {
        const response = await Ondes.Social.getFollowing(profileState.userId);
        const users = response.following || response;
        renderUsersList(users);
    } catch (error) {
        console.error('Error loading following:', error);
        listContainer.innerHTML = '<p style="text-align: center;">Erreur de chargement</p>';
    }
}

function renderUsersList(users) {
    const listContainer = document.getElementById('usersList');
    
    if (users.length === 0) {
        listContainer.innerHTML = '<p style="text-align: center; padding: 20px;">Aucun utilisateur</p>';
        return;
    }
    
    listContainer.innerHTML = users.map(user => `
        <div class="user-item" onclick="closeUsersModal(); openUserProfile(${user.id})">
            <img class="user-avatar" src="${user.profile_picture || 'https://via.placeholder.com/40'}" alt="${user.username}">
            <span class="user-name">${user.username}</span>
        </div>
    `).join('');
}

function closeUsersModal() {
    document.getElementById('usersModal').classList.remove('active');
}

function openPostFromProfile(postUuid) {
    // Find post in either posts or bookmarks
    const post = profileState.posts.find(p => p.uuid === postUuid) || 
                 profileState.bookmarks.find(p => p.uuid === postUuid);
    
    if (post) {
        // Navigate to home and scroll to post or show in modal
        showToast('Affichage du post');
        // For now, just show the feed with this post
        state.feed = [post];
        document.getElementById('profilePage').classList.add('hidden');
        document.getElementById('feedContainer').classList.remove('hidden');
        document.querySelector('.stories-container').classList.remove('hidden');
        renderFeed();
    }
}

function editProfile() {
    showToast('Modification du profil - bientôt disponible');
}

// ==================== REELS PAGE ====================

let reelsState = {
    videos: [],
    currentIndex: 0
};

async function loadReels() {
    const container = document.getElementById('reelsContainer');
    container.innerHTML = '<div class="reels-loading"><div class="spinner"></div></div>';
    
    try {
        const response = await Ondes.Social.getFeed({
            media_type: 'video',
            limit: 20
        });
        
        reelsState.videos = (response.posts || response).filter(post => 
            post.media && post.media.some(m => m.media_type === 'video')
        );
        
        if (reelsState.videos.length === 0) {
            container.innerHTML = `
                <div class="reels-empty">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                        <rect x="2" y="2" width="20" height="20" rx="2"/>
                        <path d="m10 8 6 4-6 4V8z"/>
                    </svg>
                    <h3>Aucun Reel</h3>
                    <p>Les vidéos apparaîtront ici</p>
                </div>
            `;
            return;
        }
        
        renderReels();
    } catch (error) {
        console.error('Error loading reels:', error);
        container.innerHTML = '<p style="text-align: center; color: white; padding: 40px;">Erreur de chargement</p>';
    }
}

function renderReels() {
    const container = document.getElementById('reelsContainer');
    container.innerHTML = '';
    
    reelsState.videos.forEach((post, index) => {
        const videoMedia = post.media.find(m => m.media_type === 'video');
        // API returns full URLs directly
        
        const reelItem = document.createElement('div');
        reelItem.className = 'reel-item';
        reelItem.innerHTML = `
            <video 
                id="reel-video-${index}"
                data-hls="${videoMedia.hls_url || ''}"
                poster="${videoMedia.thumbnail_url || ''}"
                playsinline
                loop
                onclick="toggleReelPlayPause(this)"
            ></video>
            
            <div class="reel-info">
                <div class="reel-author" onclick="openUserProfile(${post.author.id})">
                    <img src="${post.author.profile_picture || 'https://via.placeholder.com/32'}" alt="">
                    <span>${post.author.username}</span>
                </div>
                <p class="reel-caption">${post.content || ''}</p>
            </div>
            
            <div class="reel-actions">
                <button class="reel-action ${post.user_has_liked ? 'liked' : ''}" onclick="toggleReelLike('${post.uuid}', ${index})">
                    <svg viewBox="0 0 24 24" fill="${post.user_has_liked ? 'currentColor' : 'none'}" stroke="currentColor" stroke-width="2">
                        <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/>
                    </svg>
                    <span>${formatLikes(post.likes_count)}</span>
                </button>
                <button class="reel-action" onclick="showComments('${post.uuid}')">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
                    </svg>
                    <span>${post.comments_count}</span>
                </button>
                <button class="reel-action ${post.user_has_bookmarked ? 'bookmarked' : ''}" onclick="toggleReelBookmark('${post.uuid}', ${index})">
                    <svg viewBox="0 0 24 24" fill="${post.user_has_bookmarked ? 'currentColor' : 'none'}" stroke="currentColor" stroke-width="2">
                        <path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/>
                    </svg>
                </button>
            </div>
        `;
        
        container.appendChild(reelItem);
        
        // Initialize HLS for this reel video
        const video = reelItem.querySelector('video');
        initHlsPlayer(video);
    });
    
    // Setup scroll observer for reels
    setupReelsObserver();
}

// Toggle play/pause for reels
function toggleReelPlayPause(video) {
    if (video.paused) {
        video.play().catch(() => {});
    } else {
        video.pause();
    }
}

function setupReelsObserver() {
    const reelItems = document.querySelectorAll('.reel-item');
    
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            const video = entry.target.querySelector('video');
            if (entry.isIntersecting) {
                video.play().catch(() => {});
            } else {
                video.pause();
            }
        });
    }, { threshold: 0.5 });
    
    reelItems.forEach(item => observer.observe(item));
}

async function toggleReelLike(postUuid, index) {
    const post = reelsState.videos[index];
    if (!post) return;
    
    const btn = document.querySelector(`.reel-item:nth-child(${index + 1}) .reel-action.liked, .reel-item:nth-child(${index + 1}) .reel-action:first-child`);
    
    try {
        if (post.user_has_liked) {
            await Ondes.Social.unlikePost(postUuid);
            post.user_has_liked = false;
            post.likes_count--;
        } else {
            await Ondes.Social.likePost(postUuid);
            post.user_has_liked = true;
            post.likes_count++;
        }
        
        // Re-render this reel
        renderReels();
    } catch (error) {
        console.error('Error toggling reel like:', error);
    }
}

async function toggleReelBookmark(postUuid, index) {
    const post = reelsState.videos[index];
    if (!post) return;
    
    try {
        if (post.user_has_bookmarked) {
            await Ondes.Social.unbookmarkPost(postUuid);
            post.user_has_bookmarked = false;
        } else {
            await Ondes.Social.bookmarkPost(postUuid);
            post.user_has_bookmarked = true;
        }
        
        renderReels();
    } catch (error) {
        console.error('Error toggling reel bookmark:', error);
    }
}

// ==================== POST OPTIONS ====================

let currentOptionsPost = null;

function showPostOptions(postUuid) {
    currentOptionsPost = postUuid;
    const post = state.feed.find(p => p.uuid === postUuid);
    
    const modal = document.getElementById('postOptionsModal');
    const content = modal.querySelector('.options-content');
    
    // Show different options based on ownership
    if (post && post.author.id === state.currentUser?.id) {
        content.innerHTML = `
            <button class="option-item danger" onclick="deleteCurrentPost()">Supprimer</button>
            <button class="option-item" onclick="copyPostLink()">Copier le lien</button>
            <button class="option-item" onclick="closePostOptions()">Annuler</button>
        `;
    } else {
        content.innerHTML = `
            <button class="option-item" onclick="copyPostLink()">Copier le lien</button>
            <button class="option-item" onclick="reportPost()">Signaler</button>
            <button class="option-item" onclick="closePostOptions()">Annuler</button>
        `;
    }
    
    modal.classList.add('active');
}

async function deleteCurrentPost() {
    if (!currentOptionsPost) return;
    
    if (!confirm('Voulez-vous vraiment supprimer ce post ?')) {
        closePostOptions();
        return;
    }
    
    try {
        await Ondes.Social.deletePost(currentOptionsPost);
        
        // Remove from feed
        state.feed = state.feed.filter(p => p.uuid !== currentOptionsPost);
        renderFeed();
        
        showToast('Post supprimé');
        closePostOptions();
    } catch (error) {
        console.error('Error deleting post:', error);
        showToast('Erreur lors de la suppression');
    }
}

function copyPostLink() {
    const link = `ondes://social/post/${currentOptionsPost}`;
    navigator.clipboard?.writeText(link).then(() => {
        showToast('Lien copié');
    }).catch(() => {
        showToast('Impossible de copier');
    });
    closePostOptions();
}

function reportPost() {
    showToast('Signalement envoyé');
    closePostOptions();
}

function closePostOptions() {
    document.getElementById('postOptionsModal').classList.remove('active');
    currentOptionsPost = null;
}

async function sharePost(postUuid) {
    try {
        await Ondes.Utils.share({
            title: 'Check out this post!',
            url: `ondes://social/post/${postUuid}`
        });
    } catch (error) {
        console.error('Error sharing:', error);
    }
}

// ==================== UTILITIES ====================

function formatTimeAgo(dateStr) {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    if (isNaN(date.getTime())) return '';
    
    const now = new Date();
    const seconds = Math.floor((now - date) / 1000);
    
    if (seconds < 60) return 'Just now';
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
    if (seconds < 604800) return `${Math.floor(seconds / 86400)}d ago`;
    
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

function formatLikes(count) {
    if (count === undefined || count === null) return '0';
    if (count >= 1000000) return (count / 1000000).toFixed(1) + 'M';
    if (count >= 1000) return (count / 1000).toFixed(1) + 'K';
    return count.toString();
}

function showToast(message) {
    // Simple toast notification
    const toast = document.createElement('div');
    toast.style.cssText = `
        position: fixed;
        bottom: 90px;
        left: 50%;
        transform: translateX(-50%);
        background: var(--bg-card);
        color: var(--text-primary);
        padding: 12px 24px;
        border-radius: 8px;
        z-index: 1000;
        animation: fadeInOut 2s ease forwards;
    `;
    toast.textContent = message;
    document.body.appendChild(toast);
    
    setTimeout(() => toast.remove(), 2000);
}

function showError(message) {
    elements.feedLoading.classList.add('hidden');
    elements.feedPosts.innerHTML = `
        <div class="feed-empty">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="12" r="10"></circle>
                <line x1="12" y1="8" x2="12" y2="12"></line>
                <line x1="12" y1="16" x2="12.01" y2="16"></line>
            </svg>
            <h3>Oops!</h3>
            <p>${message}</p>
        </div>
    `;
}

// Add CSS animation for toast
const style = document.createElement('style');
style.textContent = `
    @keyframes fadeInOut {
        0%, 100% { opacity: 0; }
        20%, 80% { opacity: 1; }
    }
`;
document.head.appendChild(style);

// ==================== VIDEO PLAYER CONTROLS ====================

// Toggle video play/pause when clicking video
function toggleVideoPlay(video) {
    if (video.paused) {
        video.play().catch(() => {});
        updatePlayButton(video, true);
    } else {
        video.pause();
        updatePlayButton(video, false);
    }
}

// Toggle video play/pause from button
function toggleVideoPlayBtn(btn) {
    const container = btn.closest('.video-player-container');
    const video = container.querySelector('video');
    toggleVideoPlay(video);
}

// Toggle video mute
function toggleVideoMute(btn) {
    const container = btn.closest('.video-player-container');
    const video = container.querySelector('video');
    const mutedIcon = btn.querySelector('.muted-icon');
    const unmutedIcon = btn.querySelector('.unmuted-icon');
    
    video.muted = !video.muted;
    
    if (video.muted) {
        mutedIcon.style.display = 'block';
        unmutedIcon.style.display = 'none';
    } else {
        mutedIcon.style.display = 'none';
        unmutedIcon.style.display = 'block';
    }
}

// Update play button visibility
function updatePlayButton(video, isPlaying) {
    const container = video.closest('.video-player-container');
    if (!container) return;
    const playBtn = container.querySelector('.video-play-btn');
    if (playBtn) {
        playBtn.classList.toggle('hidden', isPlaying);
    }
}

// Initialize HLS.js for video playback
function initHlsPlayer(videoElement) {
    const hlsUrl = videoElement.dataset.hls;
    if (!hlsUrl) {
        console.warn('No HLS URL found for video');
        return;
    }
    
    // Don't initialize twice
    if (videoElement._hls) {
        return;
    }
    
    console.log('[VIDEO] Initializing HLS player:', hlsUrl);
    
    if (typeof Hls !== 'undefined' && Hls.isSupported()) {
        const hls = new Hls({
            maxBufferLength: 30,
            maxMaxBufferLength: 60,
            startLevel: -1 // Auto quality
        });
        
        hls.on(Hls.Events.ERROR, (event, data) => {
            // Only log fatal errors or important ones
            if (data.fatal) {
                console.error('[HLS] Fatal error:', data.type, data.details);
                if (data.type === Hls.ErrorTypes.NETWORK_ERROR) {
                    console.log('[HLS] Trying to recover from network error');
                    hls.startLoad();
                } else if (data.type === Hls.ErrorTypes.MEDIA_ERROR) {
                    console.log('[HLS] Trying to recover from media error');
                    hls.recoverMediaError();
                }
            }
            // Ignore non-fatal errors (buffer stalls, etc.) - these are normal
        });
        
        hls.on(Hls.Events.MANIFEST_PARSED, () => {
            console.log('[HLS] Manifest loaded, video ready');
        });
        
        hls.loadSource(hlsUrl);
        hls.attachMedia(videoElement);
        
        // Store hls instance for cleanup
        videoElement._hls = hls;
    } else if (videoElement.canPlayType('application/vnd.apple.mpegurl')) {
        // Native HLS support (Safari)
        console.log('[VIDEO] Using native HLS support');
        videoElement.src = hlsUrl;
    } else {
        console.warn('[VIDEO] HLS not supported, video may not play');
    }
}

// Intersection Observer for video autoplay (Reels page) and play state updates
const videoObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        const video = entry.target;
        const isReel = video.closest('.reel-item');
        
        if (entry.isIntersecting) {
            // For Reels: autoplay immediately
            // For Feed: only play if already started (not auto)
            if (isReel) {
                video.play().catch(() => {});
            }
            updatePlayButton(video, !video.paused);
        } else {
            video.pause();
            updatePlayButton(video, false);
        }
    });
}, { threshold: 0.5 });

// Observe videos when they are added to the DOM
const feedObserver = new MutationObserver((mutations) => {
    mutations.forEach(mutation => {
        mutation.addedNodes.forEach(node => {
            if (node.nodeType === 1) {
                const videos = node.querySelectorAll ? node.querySelectorAll('video') : [];
                videos.forEach(video => {
                    // Initialize HLS player
                    initHlsPlayer(video);
                    // Observe for autoplay
                    videoObserver.observe(video);
                    // Listen for play/pause events
                    video.addEventListener('play', () => updatePlayButton(video, true));
                    video.addEventListener('pause', () => updatePlayButton(video, false));
                });
            }
        });
    });
});

feedObserver.observe(document.body, { childList: true, subtree: true });

// Pull to refresh
let touchStartY = 0;
let isPulling = false;

document.addEventListener('touchstart', (e) => {
    if (window.scrollY === 0) {
        touchStartY = e.touches[0].clientY;
        isPulling = true;
    }
});

document.addEventListener('touchmove', (e) => {
    if (!isPulling) return;
    
    const touchY = e.touches[0].clientY;
    const diff = touchY - touchStartY;
    
    if (diff > 100 && window.scrollY === 0) {
        // Visual feedback could be added here
    }
});

document.addEventListener('touchend', async (e) => {
    if (!isPulling) return;
    
    const touchY = e.changedTouches[0].clientY;
    const diff = touchY - touchStartY;
    
    if (diff > 100 && window.scrollY === 0) {
        showToast('Refreshing...');
        await Promise.all([loadFeed(), loadStories()]);
    }
    
    isPulling = false;
});

// Keyboard shortcuts
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        closeCreatePost();
        closeCommentsModal();
        closeStoryViewer();
    }
});

// Handle comment input Enter key
document.getElementById('comment-input')?.addEventListener('keypress', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        postComment();
    }
});

// Initialize search functionality
initSearch();

// New post button in header
const newPostBtn = document.getElementById('newPostBtn');
console.log('[DEBUG] newPostBtn element:', newPostBtn);
if (newPostBtn) {
    newPostBtn.addEventListener('click', () => {
        console.log('[DEBUG] newPostBtn clicked!');
        openCreatePost();
    });
} else {
    console.error('[DEBUG] newPostBtn not found in DOM!');
}

// Create Post Modal buttons
document.getElementById('closePostModal')?.addEventListener('click', closeCreatePost);
document.getElementById('selectMediaBtn')?.addEventListener('click', selectMedia);
document.getElementById('publishBtn')?.addEventListener('click', submitPost);

// Nav button click handlers
document.querySelectorAll('.nav-item').forEach(btn => {
    btn.addEventListener('click', (e) => {
        const tab = btn.dataset.tab;
        if (tab) navigateTo(tab);
    });
});

// Make sure feedContainer has default state (not hidden)
document.getElementById('feedContainer')?.classList.remove('hidden');
document.querySelector('.stories-container')?.classList.remove('hidden');
