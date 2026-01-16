/**
 * TikTok Demo - Ondes.Social Integration
 * Vertical video feed with HLS streaming support
 */

// App State
const state = {
    currentUser: null,
    videos: [],
    currentVideoIndex: 0,
    isLoading: true,
    feedType: 'foryou', // 'foryou' or 'following'
    hlsInstances: new Map(),
    currentCommentsVideo: null,
    selectedVideoFile: null,
    createStep: 0 // 0: record, 1: edit, 2: publish
};

// DOM Elements
const elements = {
    videoFeed: document.getElementById('video-feed'),
    loadingOverlay: document.getElementById('loading-overlay'),
    sidebarActions: document.getElementById('sidebar-actions'),
    bottomInfo: document.getElementById('bottom-info'),
    commentsModal: document.getElementById('comments-modal'),
    shareModal: document.getElementById('share-modal'),
    createModal: document.getElementById('create-modal'),
    tabFollowing: document.getElementById('tab-following'),
    tabForyou: document.getElementById('tab-foryou')
};

// Initialize app when Ondes bridge is ready
// ⚠️ IMPORTANT: Use 'OndesReady' NOT 'DOMContentLoaded' - the SDK is injected after DOM is ready
document.addEventListener('OndesReady', async () => {
    console.log('[DEBUG] OndesReady fired - Ondes SDK is available');
    try {
        await initializeApp();
    } catch (error) {
        console.error('Failed to initialize app:', error);
        showError('Failed to load. Please try again.');
    }
});

async function initializeApp() {
    // Get current user
    state.currentUser = await Ondes.Social.getProfile();
    
    // Load video feed
    await loadVideoFeed();
    
    // Hide loading overlay
    elements.loadingOverlay.classList.add('hidden');
    state.isLoading = false;
    
    // Set up scroll listener
    setupScrollListener();
}

// ==================== VIDEO FEED ====================

async function loadVideoFeed() {
    try {
        const endpoint = state.feedType === 'following' 
            ? { following_only: true }
            : { algorithm: 'trending' };
        
        const response = await Ondes.Social.getFeed({
            ...endpoint,
            media_type: 'video',
            limit: 10
        });
        
        state.videos = (response.posts || response).filter(post => 
            post.media && post.media.some(m => m.media_type === 'video')
        );
        
        if (state.videos.length === 0) {
            showEmptyFeed();
        } else {
            renderVideos();
        }
    } catch (error) {
        console.error('Error loading feed:', error);
        showError('Failed to load videos');
    }
}

function renderVideos() {
    elements.videoFeed.innerHTML = '';
    
    state.videos.forEach((video, index) => {
        const videoItem = createVideoElement(video, index);
        elements.videoFeed.appendChild(videoItem);
    });
    
    // Initialize first video
    if (state.videos.length > 0) {
        updateSidebarAndInfo(0);
        playVideo(0);
    }
}

function createVideoElement(post, index) {
    const div = document.createElement('div');
    div.className = 'video-item loading';
    div.dataset.index = index;
    div.dataset.postId = post.uuid;
    
    const videoMedia = post.media.find(m => m.media_type === 'video');
    const videoSrc = videoMedia.hls_playlist || videoMedia.compressed_file || videoMedia.original_file;
    const isHls = videoMedia.hls_playlist ? true : false;
    
    div.innerHTML = `
        <video 
            id="video-${index}"
            data-hls="${videoMedia.hls_playlist || ''}"
            playsinline
            loop
            preload="metadata"
            poster="${videoMedia.thumbnail || ''}"
        ></video>
        
        <div class="play-indicator">
            <svg viewBox="0 0 24 24">
                <polygon points="5 3 19 12 5 21 5 3"/>
            </svg>
        </div>
        
        <div class="double-tap-heart">
            <svg viewBox="0 0 24 24">
                <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/>
            </svg>
        </div>
        
        <div class="video-progress">
            <div class="video-progress-fill"></div>
        </div>
    `;
    
    const videoEl = div.querySelector('video');
    
    // Initialize HLS or regular video
    if (isHls) {
        initHlsPlayer(videoEl, videoMedia.hls_playlist, index);
    } else {
        videoEl.src = videoSrc;
    }
    
    // Event listeners
    videoEl.addEventListener('loadeddata', () => {
        div.classList.remove('loading');
    });
    
    videoEl.addEventListener('timeupdate', () => {
        const progress = (videoEl.currentTime / videoEl.duration) * 100;
        div.querySelector('.video-progress-fill').style.width = `${progress}%`;
    });
    
    // Tap to pause/play
    let lastTap = 0;
    div.addEventListener('click', (e) => {
        const now = Date.now();
        const timeDiff = now - lastTap;
        
        if (timeDiff < 300 && timeDiff > 0) {
            // Double tap - like
            handleDoubleTap(post.uuid, div);
        } else {
            // Single tap - toggle play
            setTimeout(() => {
                if (Date.now() - lastTap >= 300) {
                    toggleVideoPlay(index);
                }
            }, 300);
        }
        
        lastTap = now;
    });
    
    return div;
}

function initHlsPlayer(videoElement, hlsUrl, index) {
    if (!hlsUrl) return;
    
    if (Hls.isSupported()) {
        const hls = new Hls({
            maxBufferLength: 30,
            maxMaxBufferLength: 60,
            startLevel: -1 // Auto quality
        });
        hls.loadSource(hlsUrl);
        hls.attachMedia(videoElement);
        
        // Store HLS instance for cleanup
        state.hlsInstances.set(index, hls);
        
        hls.on(Hls.Events.MANIFEST_PARSED, () => {
            if (index === state.currentVideoIndex) {
                videoElement.play().catch(() => {});
            }
        });
    } else if (videoElement.canPlayType('application/vnd.apple.mpegurl')) {
        videoElement.src = hlsUrl;
    }
}

function setupScrollListener() {
    const options = {
        root: elements.videoFeed,
        threshold: 0.5
    };
    
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const index = parseInt(entry.target.dataset.index);
                if (index !== state.currentVideoIndex) {
                    // Pause previous video
                    pauseVideo(state.currentVideoIndex);
                    
                    // Update current index
                    state.currentVideoIndex = index;
                    
                    // Play new video
                    playVideo(index);
                    
                    // Update UI
                    updateSidebarAndInfo(index);
                }
            }
        });
    }, options);
    
    document.querySelectorAll('.video-item').forEach(item => {
        observer.observe(item);
    });
}

function playVideo(index) {
    const videoEl = document.getElementById(`video-${index}`);
    if (videoEl) {
        videoEl.play().catch(() => {});
        
        // Resume music disc animation
        const musicDisc = document.querySelector('.music-disc');
        if (musicDisc) musicDisc.classList.remove('paused');
    }
}

function pauseVideo(index) {
    const videoEl = document.getElementById(`video-${index}`);
    if (videoEl) {
        videoEl.pause();
    }
}

function toggleVideoPlay(index) {
    const videoEl = document.getElementById(`video-${index}`);
    const playIndicator = videoEl?.parentElement?.querySelector('.play-indicator');
    
    if (!videoEl) return;
    
    if (videoEl.paused) {
        videoEl.play();
        const musicDisc = document.querySelector('.music-disc');
        if (musicDisc) musicDisc.classList.remove('paused');
    } else {
        videoEl.pause();
        const musicDisc = document.querySelector('.music-disc');
        if (musicDisc) musicDisc.classList.add('paused');
        
        // Show play indicator briefly
        if (playIndicator) {
            playIndicator.classList.add('show');
            setTimeout(() => playIndicator.classList.remove('show'), 500);
        }
    }
}

function updateSidebarAndInfo(index) {
    const post = state.videos[index];
    if (!post) return;
    
    // Update sidebar
    elements.sidebarActions.innerHTML = `
        <div class="action-item">
            <button class="action-btn profile-btn" onclick="openProfile('${post.author.uuid}')">
                <img src="${post.author.profile_picture || 'https://via.placeholder.com/48'}" alt="${post.author.username}">
                ${!post.author.is_following ? '<div class="follow-badge">+</div>' : ''}
            </button>
        </div>
        
        <div class="action-item">
            <button class="action-btn ${post.user_has_liked ? 'liked' : ''}" onclick="toggleLike('${post.uuid}')">
                <svg viewBox="0 0 24 24">
                    <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/>
                </svg>
            </button>
            <span class="action-count">${formatCount(post.likes_count)}</span>
        </div>
        
        <div class="action-item">
            <button class="action-btn" onclick="openComments('${post.uuid}')">
                <svg viewBox="0 0 24 24">
                    <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
                </svg>
            </button>
            <span class="action-count">${formatCount(post.comments_count)}</span>
        </div>
        
        <div class="action-item">
            <button class="action-btn ${post.user_has_bookmarked ? 'bookmarked' : ''}" onclick="toggleBookmark('${post.uuid}')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/>
                </svg>
            </button>
            <span class="action-count">${formatCount(post.bookmarks_count || 0)}</span>
        </div>
        
        <div class="action-item">
            <button class="action-btn" onclick="openShare('${post.uuid}')">
                <svg viewBox="0 0 24 24">
                    <circle cx="18" cy="5" r="3"/>
                    <circle cx="6" cy="12" r="3"/>
                    <circle cx="18" cy="19" r="3"/>
                    <line x1="8.59" y1="13.51" x2="15.42" y2="17.49" stroke="currentColor" stroke-width="2"/>
                    <line x1="15.41" y1="6.51" x2="8.59" y2="10.49" stroke="currentColor" stroke-width="2"/>
                </svg>
            </button>
            <span class="action-count">Share</span>
        </div>
        
        <div class="action-item">
            <div class="music-disc">
                <img src="${post.author.profile_picture || 'https://via.placeholder.com/28'}" alt="Music">
            </div>
        </div>
    `;
    
    // Update bottom info
    const tags = post.tags ? post.tags.map(t => `<span>#${t}</span>`).join('') : '';
    
    elements.bottomInfo.innerHTML = `
        <div class="video-author">@${post.author.username}</div>
        <div class="video-description" onclick="toggleDescription(this)">${post.content || ''}</div>
        ${tags ? `<div class="video-tags">${tags}</div>` : ''}
        <div class="music-info">
            <div class="music-icon">
                <svg viewBox="0 0 24 24">
                    <path d="M9 18V5l12-2v13"/>
                    <circle cx="6" cy="18" r="3"/>
                    <circle cx="18" cy="16" r="3"/>
                </svg>
            </div>
            <div class="music-marquee">
                <span>Original sound - ${post.author.username} &nbsp;&nbsp;&nbsp; Original sound - ${post.author.username}</span>
            </div>
        </div>
    `;
}

function toggleDescription(el) {
    el.classList.toggle('expanded');
}

// ==================== INTERACTIONS ====================

async function toggleLike(postUuid) {
    const post = state.videos.find(p => p.uuid === postUuid);
    if (!post) return;
    
    const likeBtn = elements.sidebarActions.querySelector('.action-btn');
    const countSpan = likeBtn?.parentElement?.querySelector('.action-count');
    
    try {
        if (post.user_has_liked) {
            await Ondes.Social.unlike(postUuid);
            post.user_has_liked = false;
            post.likes_count--;
            likeBtn?.classList.remove('liked');
        } else {
            await Ondes.Social.like(postUuid);
            post.user_has_liked = true;
            post.likes_count++;
            likeBtn?.classList.add('liked');
        }
        
        if (countSpan) {
            countSpan.textContent = formatCount(post.likes_count);
        }
    } catch (error) {
        console.error('Error toggling like:', error);
    }
}

function handleDoubleTap(postUuid, container) {
    const post = state.videos.find(p => p.uuid === postUuid);
    if (!post || post.user_has_liked) return;
    
    // Show heart animation
    const heart = container.querySelector('.double-tap-heart');
    heart.classList.add('animate');
    setTimeout(() => heart.classList.remove('animate'), 800);
    
    // Like the video
    toggleLike(postUuid);
}

async function toggleBookmark(postUuid) {
    const post = state.videos.find(p => p.uuid === postUuid);
    if (!post) return;
    
    try {
        if (post.user_has_bookmarked) {
            await Ondes.Social.removeBookmark(postUuid);
            post.user_has_bookmarked = false;
        } else {
            await Ondes.Social.bookmark(postUuid);
            post.user_has_bookmarked = true;
        }
        
        // Update UI
        updateSidebarAndInfo(state.currentVideoIndex);
    } catch (error) {
        console.error('Error toggling bookmark:', error);
    }
}

// ==================== COMMENTS ====================

async function openComments(postUuid) {
    state.currentCommentsVideo = postUuid;
    const post = state.videos.find(p => p.uuid === postUuid);
    
    elements.commentsModal.classList.add('active');
    document.getElementById('comments-count').textContent = `${post?.comments_count || 0} comments`;
    
    // Pause video
    pauseVideo(state.currentVideoIndex);
    
    // Load comments
    const commentsList = document.getElementById('comments-list');
    commentsList.innerHTML = '<div class="loading-overlay"><div class="loader"><svg viewBox="0 0 50 50"><circle cx="25" cy="25" r="20"></circle></svg></div></div>';
    
    try {
        const response = await Ondes.Social.getComments(postUuid);
        const comments = response.comments || response;
        
        if (comments.length === 0) {
            commentsList.innerHTML = '<p style="text-align: center; color: var(--text-secondary); padding: 40px;">No comments yet</p>';
        } else {
            renderComments(comments);
        }
    } catch (error) {
        console.error('Error loading comments:', error);
        commentsList.innerHTML = '<p style="text-align: center; color: var(--text-secondary);">Failed to load</p>';
    }
}

function renderComments(comments) {
    const commentsList = document.getElementById('comments-list');
    commentsList.innerHTML = comments.map(comment => {
        const isOwnComment = comment.author.id === state.currentUser?.id;
        return `
            <div class="comment-item" data-id="${comment.uuid}">
                <img class="comment-avatar" src="${comment.author.profile_picture || 'https://via.placeholder.com/40'}" alt="">
                <div class="comment-content">
                    <span class="comment-username">${comment.author.username}</span>
                    <p class="comment-text">${comment.content}</p>
                    <div class="comment-meta">
                        <span>${formatTimeAgo(new Date(comment.created_at))}</span>
                        <button onclick="replyToComment('${comment.uuid}')">Reply</button>
                        ${isOwnComment ? `<button class="delete-btn" onclick="deleteComment('${comment.uuid}')">Delete</button>` : ''}
                    </div>
                </div>
                <div class="comment-like">
                    <button class="comment-like-btn ${comment.user_has_liked ? 'liked' : ''}" onclick="likeComment('${comment.uuid}')">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/>
                        </svg>
                    </button>
                    <span class="comment-like-count">${comment.likes_count}</span>
                </div>
            </div>
        `;
    }).join('');
}

async function deleteComment(commentUuid) {
    try {
        await Ondes.Social.deleteComment(commentUuid);
        
        // Update count
        const post = state.videos.find(p => p.uuid === state.currentCommentsVideo);
        if (post) {
            post.comments_count--;
            document.getElementById('comments-count').textContent = `${post.comments_count} comments`;
        }
        
        // Refresh comments
        openComments(state.currentCommentsVideo);
        showToast('Comment deleted');
    } catch (error) {
        console.error('Error deleting comment:', error);
        showToast('Failed to delete');
    }
}

async function postComment() {
    const input = document.getElementById('comment-input');
    const content = input.value.trim();
    
    if (!content || !state.currentCommentsVideo) return;
    
    try {
        await Ondes.Social.comment(state.currentCommentsVideo, content);
        input.value = '';
        
        // Refresh comments
        openComments(state.currentCommentsVideo);
        
        // Update count in sidebar
        const post = state.videos.find(p => p.uuid === state.currentCommentsVideo);
        if (post) {
            post.comments_count++;
            document.getElementById('comments-count').textContent = `${post.comments_count} comments`;
        }
    } catch (error) {
        console.error('Error posting comment:', error);
    }
}

async function likeComment(commentUuid) {
    try {
        await Ondes.Social.likeComment(commentUuid);
        openComments(state.currentCommentsVideo);
    } catch (error) {
        console.error('Error liking comment:', error);
    }
}

function closeCommentsModal() {
    elements.commentsModal.classList.remove('active');
    state.currentCommentsVideo = null;
    playVideo(state.currentVideoIndex);
}

// ==================== SHARE ====================

function openShare(postUuid) {
    state.currentShareVideo = postUuid;
    elements.shareModal.classList.add('active');
}

function closeShareModal() {
    elements.shareModal.classList.remove('active');
}

async function shareVia(method) {
    const postUuid = state.currentShareVideo;
    
    try {
        switch(method) {
            case 'copy':
                await navigator.clipboard.writeText(`ondes://social/post/${postUuid}`);
                showToast('Link copied!');
                break;
            case 'message':
                // Open internal messaging
                showToast('Messaging coming soon!');
                break;
            case 'other':
                await Ondes.Utils.share({
                    title: 'Check out this video!',
                    url: `ondes://social/post/${postUuid}`
                });
                break;
        }
    } catch (error) {
        console.error('Error sharing:', error);
    }
    
    closeShareModal();
}

// ==================== CREATE VIDEO ====================

function openCreateVideo() {
    state.createStep = 0;
    state.selectedVideoFile = null;
    showCreateStep(0);
    elements.createModal.classList.add('active');
    
    // Pause current video
    pauseVideo(state.currentVideoIndex);
}

function closeCreateModal() {
    elements.createModal.classList.remove('active');
    state.selectedVideoFile = null;
    playVideo(state.currentVideoIndex);
}

async function selectVideo() {
    try {
        const result = await Ondes.Social.pickMedia({
            multiple: false,
            allowVideo: true,
            videoOnly: true
        });
        
        if (result && result.length > 0) {
            state.selectedVideoFile = result[0];
            
            // Show preview
            const previewVideo = document.getElementById('selected-video');
            previewVideo.src = state.selectedVideoFile.path;
            previewVideo.play();
            
            // Move to edit step
            showCreateStep(1);
            document.getElementById('next-btn').disabled = false;
        }
    } catch (error) {
        console.error('Error selecting video:', error);
    }
}

function showCreateStep(step) {
    state.createStep = step;
    
    document.getElementById('step-record').classList.toggle('hidden', step !== 0);
    document.getElementById('step-edit').classList.toggle('hidden', step !== 1);
    document.getElementById('step-publish').classList.toggle('hidden', step !== 2);
    
    // Update next button
    const nextBtn = document.getElementById('next-btn');
    if (step === 2) {
        nextBtn.textContent = 'Post';
        nextBtn.onclick = publishVideo;
    } else {
        nextBtn.textContent = 'Next';
        nextBtn.onclick = nextStep;
    }
}

function nextStep() {
    if (state.createStep < 2) {
        showCreateStep(state.createStep + 1);
    }
}

async function publishVideo() {
    if (!state.selectedVideoFile) return;
    
    const caption = document.getElementById('video-caption').value;
    const tagsInput = document.getElementById('video-tags').value;
    const visibility = document.getElementById('video-visibility').value;
    
    const tags = tagsInput
        .split(/[#\s,]+/)
        .map(t => t.trim())
        .filter(t => t.length > 0);
    
    const publishBtn = document.querySelector('.publish-btn');
    publishBtn.disabled = true;
    publishBtn.textContent = 'Publishing...';
    
    try {
        await Ondes.Social.publish({
            content: caption,
            media: [state.selectedVideoFile.path],
            visibility: visibility,
            tags: tags
        });
        
        showToast('Video published!');
        closeCreateModal();
        
        // Refresh feed
        await loadVideoFeed();
    } catch (error) {
        console.error('Error publishing video:', error);
        showToast('Failed to publish video');
    } finally {
        publishBtn.disabled = false;
        publishBtn.textContent = 'Post';
    }
}

// ==================== NAVIGATION ====================

function navigateTo(tab) {
    // Update active state
    document.querySelectorAll('.nav-item').forEach(item => item.classList.remove('active'));
    event.currentTarget.classList.add('active');
    
    switch(tab) {
        case 'home':
            // Already on home
            playVideo(state.currentVideoIndex);
            break;
        case 'discover':
            openDiscoverModal();
            break;
        case 'inbox':
            showToast('Inbox coming soon!');
            break;
        case 'profile':
            openProfileModal(state.currentUser?.id);
            break;
    }
}

function switchFeed(type) {
    state.feedType = type;
    
    elements.tabFollowing.classList.toggle('active', type === 'following');
    elements.tabForyou.classList.toggle('active', type === 'foryou');
    
    // Reload feed
    elements.loadingOverlay.classList.remove('hidden');
    loadVideoFeed();
}

// Tab click handlers
elements.tabFollowing.addEventListener('click', () => switchFeed('following'));
elements.tabForyou.addEventListener('click', () => switchFeed('foryou'));

function openProfile(userUuid) {
    // Find user id from uuid
    const video = state.videos.find(v => v.author.uuid === userUuid);
    if (video) {
        openProfileModal(video.author.id);
    }
}

function openSearch() {
    openDiscoverModal();
}

// ==================== DISCOVER PAGE ====================

let discoverSearchTimeout = null;

function openDiscoverModal() {
    pauseVideo(state.currentVideoIndex);
    document.getElementById('discover-modal').classList.add('active');
    document.getElementById('discover-search-input').value = '';
    document.getElementById('discover-content').innerHTML = `
        <div class="discover-placeholder">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                <circle cx="11" cy="11" r="8"/>
                <path d="m21 21-4.35-4.35"/>
            </svg>
            <p>Search for users</p>
        </div>
    `;
    document.getElementById('discover-search-input').focus();
}

function closeDiscoverModal() {
    document.getElementById('discover-modal').classList.remove('active');
    playVideo(state.currentVideoIndex);
}

function onDiscoverSearch(query) {
    clearTimeout(discoverSearchTimeout);
    
    if (query.trim().length < 2) {
        document.getElementById('discover-content').innerHTML = `
            <div class="discover-placeholder">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                    <circle cx="11" cy="11" r="8"/>
                    <path d="m21 21-4.35-4.35"/>
                </svg>
                <p>Search for users</p>
            </div>
        `;
        return;
    }
    
    discoverSearchTimeout = setTimeout(() => searchDiscoverUsers(query), 300);
}

async function searchDiscoverUsers(query) {
    const content = document.getElementById('discover-content');
    content.innerHTML = '<div class="loading-center"><div class="loader"><svg viewBox="0 0 50 50"><circle cx="25" cy="25" r="20"></circle></svg></div></div>';
    
    try {
        const response = await Ondes.Social.searchUsers(query);
        const users = response.users || response;
        
        if (users.length === 0) {
            content.innerHTML = `
                <div class="discover-placeholder">
                    <p>No users found for "${query}"</p>
                </div>
            `;
            return;
        }
        
        content.innerHTML = users.map(user => `
            <div class="discover-user-item" onclick="openProfileFromDiscover(${user.id})">
                <img class="discover-avatar" src="${user.profile_picture || 'https://via.placeholder.com/50'}" alt="">
                <div class="discover-user-info">
                    <span class="discover-username">@${user.username}</span>
                    ${user.bio ? `<span class="discover-bio">${user.bio.substring(0, 50)}...</span>` : ''}
                </div>
                ${user.id !== state.currentUser?.id ? `
                    <button class="discover-follow-btn ${user.is_following ? 'following' : ''}" 
                            onclick="event.stopPropagation(); toggleDiscoverFollow(${user.id}, this)">
                        ${user.is_following ? 'Following' : 'Follow'}
                    </button>
                ` : ''}
            </div>
        `).join('');
    } catch (error) {
        console.error('Error searching users:', error);
        content.innerHTML = '<p style="text-align: center; color: var(--text-secondary);">Search error</p>';
    }
}

async function toggleDiscoverFollow(userId, button) {
    const isFollowing = button.classList.contains('following');
    
    try {
        if (isFollowing) {
            await Ondes.Social.unfollow(userId);
            button.classList.remove('following');
            button.textContent = 'Follow';
        } else {
            await Ondes.Social.follow(userId);
            button.classList.add('following');
            button.textContent = 'Following';
        }
    } catch (error) {
        console.error('Error toggling follow:', error);
    }
}

function openProfileFromDiscover(userId) {
    closeDiscoverModal();
    openProfileModal(userId);
}

// ==================== PROFILE PAGE ====================

let profilePageState = {
    userId: null,
    isOwnProfile: false,
    currentTab: 'videos',
    posts: [],
    bookmarks: []
};

async function openProfileModal(userId) {
    pauseVideo(state.currentVideoIndex);
    document.getElementById('profile-modal').classList.add('active');
    
    profilePageState.isOwnProfile = !userId || userId === state.currentUser?.id;
    profilePageState.currentTab = 'videos';
    
    // Reset tabs
    document.querySelectorAll('.profile-tab-btn').forEach(t => t.classList.remove('active'));
    document.querySelector('.profile-tab-btn[data-tab="videos"]').classList.add('active');
    
    // Show/hide bookmarks tab (only for own profile)
    const bookmarksTab = document.querySelector('.bookmarks-tab');
    if (bookmarksTab) {
        bookmarksTab.style.display = profilePageState.isOwnProfile ? 'flex' : 'none';
    }
    
    // Load profile
    try {
        const profile = await Ondes.Social.getProfile({ userId: userId });
        
        // Store the actual userId from profile response
        profilePageState.userId = profile.id;
        
        document.getElementById('profile-username-header').textContent = `@${profile.username}`;
        document.getElementById('profile-avatar').src = profile.profile_picture || 'https://via.placeholder.com/100';
        document.getElementById('profile-name').textContent = `@${profile.username}`;
        document.getElementById('profile-following').textContent = profile.following_count || 0;
        document.getElementById('profile-followers').textContent = profile.followers_count || 0;
        document.getElementById('profile-likes').textContent = profile.total_likes || 0;
        document.getElementById('profile-bio').textContent = profile.bio || '';
        
        // Action buttons
        const actionsContainer = document.getElementById('profile-action-btns');
        if (profilePageState.isOwnProfile) {
            actionsContainer.innerHTML = `
                <button class="profile-action-btn edit-btn" onclick="showToast('Edit profile coming soon!')">Edit profile</button>
            `;
        } else {
            actionsContainer.innerHTML = `
                <button class="profile-action-btn follow-btn ${profile.is_following ? 'following' : ''}" onclick="toggleProfilePageFollow()">
                    ${profile.is_following ? 'Following' : 'Follow'}
                </button>
                <button class="profile-action-btn message-btn" onclick="showToast('Messages coming soon!')">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
                    </svg>
                </button>
            `;
        }
        
        // Load videos
        await loadProfileVideos();
        
    } catch (error) {
        console.error('Error loading profile:', error);
        showToast('Error loading profile');
    }
}

function closeProfileModal() {
    document.getElementById('profile-modal').classList.remove('active');
    playVideo(state.currentVideoIndex);
}

async function loadProfileVideos() {
    const grid = document.getElementById('profile-videos-grid');
    grid.innerHTML = '<div class="loading-center"><div class="loader"><svg viewBox="0 0 50 50"><circle cx="25" cy="25" r="20"></circle></svg></div></div>';
    
    try {
        const response = await Ondes.Social.getUserPosts(profilePageState.userId);
        profilePageState.posts = (response.posts || response).filter(p => 
            p.media && p.media.some(m => m.media_type === 'video')
        );
        
        renderProfileVideosGrid(profilePageState.posts);
    } catch (error) {
        console.error('Error loading profile videos:', error);
        grid.innerHTML = '<p style="text-align: center;">Error loading videos</p>';
    }
}

async function loadProfileBookmarks() {
    const grid = document.getElementById('profile-videos-grid');
    grid.innerHTML = '<div class="loading-center"><div class="loader"><svg viewBox="0 0 50 50"><circle cx="25" cy="25" r="20"></circle></svg></div></div>';
    
    try {
        const response = await Ondes.Social.getBookmarks();
        profilePageState.bookmarks = (response.posts || response).filter(p => 
            p.media && p.media.some(m => m.media_type === 'video')
        );
        
        renderProfileVideosGrid(profilePageState.bookmarks);
    } catch (error) {
        console.error('Error loading bookmarks:', error);
        grid.innerHTML = '<p style="text-align: center;">Error loading bookmarks</p>';
    }
}

function renderProfileVideosGrid(posts) {
    const grid = document.getElementById('profile-videos-grid');
    
    if (posts.length === 0) {
        grid.innerHTML = `
            <div class="profile-empty">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                    <rect x="2" y="2" width="20" height="20" rx="2"/>
                    <path d="m10 8 6 4-6 4V8z"/>
                </svg>
                <p>No videos yet</p>
            </div>
        `;
        return;
    }
    
    grid.innerHTML = posts.map(post => {
        const videoMedia = post.media.find(m => m.media_type === 'video');
        const thumbnail = videoMedia?.thumbnail || 'https://via.placeholder.com/150?text=Video';
        
        return `
            <div class="profile-video-item" onclick="playProfileVideo('${post.uuid}')">
                <img src="${thumbnail}" alt="">
                <div class="video-views">
                    <svg viewBox="0 0 24 24" fill="currentColor">
                        <polygon points="5 3 19 12 5 21 5 3"/>
                    </svg>
                    <span>${formatCount(post.views_count || 0)}</span>
                </div>
            </div>
        `;
    }).join('');
}

function switchProfileTab(tab) {
    profilePageState.currentTab = tab;
    
    document.querySelectorAll('.profile-tab-btn').forEach(t => t.classList.remove('active'));
    document.querySelector(`.profile-tab-btn[data-tab="${tab}"]`).classList.add('active');
    
    if (tab === 'videos') {
        loadProfileVideos();
    } else if (tab === 'bookmarks') {
        loadProfileBookmarks();
    }
}

async function toggleProfilePageFollow() {
    const btn = document.querySelector('#profile-action-btns .follow-btn');
    const isFollowing = btn.classList.contains('following');
    
    try {
        if (isFollowing) {
            await Ondes.Social.unfollow(profilePageState.userId);
            btn.classList.remove('following');
            btn.textContent = 'Follow';
            
            const count = parseInt(document.getElementById('profile-followers').textContent) - 1;
            document.getElementById('profile-followers').textContent = count;
        } else {
            await Ondes.Social.follow(profilePageState.userId);
            btn.classList.add('following');
            btn.textContent = 'Following';
            
            const count = parseInt(document.getElementById('profile-followers').textContent) + 1;
            document.getElementById('profile-followers').textContent = count;
        }
    } catch (error) {
        console.error('Error toggling follow:', error);
    }
}

async function showProfileFollowers() {
    document.getElementById('users-list-title').textContent = 'Followers';
    document.getElementById('users-list-modal').classList.add('active');
    
    const content = document.getElementById('users-list-content');
    content.innerHTML = '<div class="loading-center"><div class="loader"><svg viewBox="0 0 50 50"><circle cx="25" cy="25" r="20"></circle></svg></div></div>';
    
    try {
        const response = await Ondes.Social.getFollowers(profilePageState.userId);
        const users = response.followers || response;
        renderUsersListModal(users);
    } catch (error) {
        console.error('Error loading followers:', error);
        content.innerHTML = '<p style="text-align: center;">Error loading followers</p>';
    }
}

async function showProfileFollowing() {
    document.getElementById('users-list-title').textContent = 'Following';
    document.getElementById('users-list-modal').classList.add('active');
    
    const content = document.getElementById('users-list-content');
    content.innerHTML = '<div class="loading-center"><div class="loader"><svg viewBox="0 0 50 50"><circle cx="25" cy="25" r="20"></circle></svg></div></div>';
    
    try {
        const response = await Ondes.Social.getFollowing(profilePageState.userId);
        const users = response.following || response;
        renderUsersListModal(users);
    } catch (error) {
        console.error('Error loading following:', error);
        content.innerHTML = '<p style="text-align: center;">Error loading following</p>';
    }
}

function renderUsersListModal(users) {
    const content = document.getElementById('users-list-content');
    
    if (users.length === 0) {
        content.innerHTML = '<p style="text-align: center; padding: 40px;">No users</p>';
        return;
    }
    
    content.innerHTML = users.map(user => `
        <div class="users-list-item" onclick="closeUsersListModal(); openProfileFromDiscover(${user.id})">
            <img src="${user.profile_picture || 'https://via.placeholder.com/40'}" alt="">
            <span>@${user.username}</span>
        </div>
    `).join('');
}

function closeUsersListModal() {
    document.getElementById('users-list-modal').classList.remove('active');
}

function playProfileVideo(postUuid) {
    // Find the video in posts or bookmarks
    const post = profilePageState.posts.find(p => p.uuid === postUuid) || 
                 profilePageState.bookmarks.find(p => p.uuid === postUuid);
    
    if (post) {
        // Add to feed and navigate
        state.videos = [post, ...state.videos.filter(v => v.uuid !== postUuid)];
        state.currentVideoIndex = 0;
        closeProfileModal();
        renderVideos();
        playVideo(0);
        showToast('Playing video');
    }
}

// ==================== UTILITIES ====================

function formatCount(count) {
    if (count >= 1000000) return (count / 1000000).toFixed(1) + 'M';
    if (count >= 1000) return (count / 1000).toFixed(1) + 'K';
    return count.toString();
}

function formatTimeAgo(date) {
    const now = new Date();
    const seconds = Math.floor((now - date) / 1000);
    
    if (seconds < 60) return `${seconds}s`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`;
    if (seconds < 604800) return `${Math.floor(seconds / 86400)}d`;
    
    return `${Math.floor(seconds / 604800)}w`;
}

function showToast(message) {
    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.textContent = message;
    document.body.appendChild(toast);
    setTimeout(() => toast.remove(), 2000);
}

function showError(message) {
    elements.loadingOverlay.classList.add('hidden');
    elements.videoFeed.innerHTML = `
        <div class="empty-feed">
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

function showEmptyFeed() {
    elements.videoFeed.innerHTML = `
        <div class="empty-feed">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polygon points="23 7 16 12 23 17 23 7"/>
                <rect x="1" y="5" width="15" height="14" rx="2" ry="2"/>
            </svg>
            <h3>No videos yet</h3>
            <p>Be the first to post!</p>
        </div>
    `;
}

// Keyboard shortcuts
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        closeCommentsModal();
        closeShareModal();
        closeCreateModal();
    }
    
    if (e.key === ' ' && !e.target.matches('input, textarea')) {
        e.preventDefault();
        toggleVideoPlay(state.currentVideoIndex);
    }
    
    if (e.key === 'ArrowDown') {
        const nextItem = document.querySelector(`.video-item[data-index="${state.currentVideoIndex + 1}"]`);
        if (nextItem) {
            nextItem.scrollIntoView({ behavior: 'smooth' });
        }
    }
    
    if (e.key === 'ArrowUp') {
        const prevItem = document.querySelector(`.video-item[data-index="${state.currentVideoIndex - 1}"]`);
        if (prevItem) {
            prevItem.scrollIntoView({ behavior: 'smooth' });
        }
    }
});

// Comment input enter handler
document.getElementById('comment-input')?.addEventListener('keypress', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        postComment();
    }
});

// Clean up HLS instances when page unloads
window.addEventListener('beforeunload', () => {
    state.hlsInstances.forEach(hls => hls.destroy());
});

// Infinite scroll - load more videos
let isLoadingMore = false;

elements.videoFeed.addEventListener('scroll', async () => {
    const { scrollTop, scrollHeight, clientHeight } = elements.videoFeed;
    
    if (scrollTop + clientHeight >= scrollHeight - 500 && !isLoadingMore) {
        isLoadingMore = true;
        
        try {
            const response = await Ondes.Social.getFeed({
                media_type: 'video',
                limit: 5,
                offset: state.videos.length
            });
            
            const newVideos = (response.posts || response).filter(post => 
                post.media && post.media.some(m => m.media_type === 'video')
            );
            
            if (newVideos.length > 0) {
                const startIndex = state.videos.length;
                state.videos.push(...newVideos);
                
                newVideos.forEach((video, i) => {
                    const videoItem = createVideoElement(video, startIndex + i);
                    elements.videoFeed.appendChild(videoItem);
                });
                
                // Re-observe new items
                setupScrollListener();
            }
        } catch (error) {
            console.error('Error loading more videos:', error);
        }
        
        isLoadingMore = false;
    }
});
