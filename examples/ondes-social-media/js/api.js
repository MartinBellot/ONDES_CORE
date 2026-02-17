/**
 * Ondes Social — API Abstraction Layer
 * Wraps Ondes SDK calls with error handling + response normalization.
 *
 * The Dart handler returns snake_case `user_has_liked`, `user_has_bookmarked`
 * on posts and camelCase `hasUnviewed` on story groups. This layer normalises
 * field names so the rest of the JS code can use a single convention.
 *
 * All list endpoints (feeds, comments, users…) are wrapped to always
 * return `{ posts: [] }`, `{ comments: [] }`, etc. regardless of
 * whether the SDK returns a bare array or an object.
 */

// ==================== HELPERS ====================

function _normalizePost(p) {
    if (!p || typeof p !== 'object') return p;
    return {
        ...p,
        is_liked: p.user_has_liked ?? p.is_liked ?? false,
        is_bookmarked: p.user_has_bookmarked ?? p.is_bookmarked ?? false,
    };
}

function _normalizePosts(result) {
    const arr = Array.isArray(result) ? result : (result?.posts || []);
    return arr.map(_normalizePost);
}

function _normalizeStoryGroup(g) {
    if (!g || typeof g !== 'object') return g;
    return {
        ...g,
        has_unviewed: g.hasUnviewed ?? g.has_unviewed ?? false,
    };
}

// ==================== API ====================

const API = {
    // ==================== USER / PROFILE ====================
    async getMyProfile() {
        try {
            return await Ondes.Social.getProfile();
        } catch (e) {
            console.error('[API] getMyProfile:', e);
            return null;
        }
    },

    async getUserProfile(userId) {
        try {
            // Handler expects args[0] as Map { userId?, username? }
            return await Ondes.Social.getProfile({ userId: userId });
        } catch (e) {
            console.error('[API] getUserProfile:', e);
            return null;
        }
    },

    async searchUsers(query) {
        try {
            const result = await Ondes.Social.searchUsers(query);
            const users = Array.isArray(result) ? result : (result?.users || []);
            return { users };
        } catch (e) {
            console.error('[API] searchUsers:', e);
            return { users: [] };
        }
    },

    // ==================== FEED ====================
    async getFeed(options = {}) {
        try {
            const result = await Ondes.Social.getFeed(options);
            return { posts: _normalizePosts(result) };
        } catch (e) {
            console.error('[API] getFeed:', e);
            return { posts: [] };
        }
    },

    async getDiscoverFeed(options = {}) {
        try {
            const result = await Ondes.Social.getFeed({ ...options, type: 'discover' });
            return { posts: _normalizePosts(result) };
        } catch (e) {
            console.error('[API] getDiscoverFeed:', e);
            return { posts: [] };
        }
    },

    async getFriendsFeed(options = {}) {
        try {
            const result = await Ondes.Social.getFeed({ ...options, type: 'friends' });
            return { posts: _normalizePosts(result) };
        } catch (e) {
            console.error('[API] getFriendsFeed:', e);
            return { posts: [] };
        }
    },

    async getVideoFeed(options = {}) {
        try {
            const result = await Ondes.Social.getFeed({ ...options, type: 'video' });
            return { posts: _normalizePosts(result) };
        } catch (e) {
            console.error('[API] getVideoFeed:', e);
            return { posts: [] };
        }
    },

    async getUserPosts(userId, limit = 30, offset = 0) {
        try {
            const result = await Ondes.Social.getUserPosts(userId, { limit, offset });
            return { posts: _normalizePosts(result) };
        } catch (e) {
            console.error('[API] getUserPosts:', e);
            return { posts: [] };
        }
    },

    async getBookmarks(limit = 30, offset = 0) {
        try {
            const result = await Ondes.Social.getBookmarks({ limit, offset });
            return { posts: _normalizePosts(result) };
        } catch (e) {
            console.error('[API] getBookmarks:', e);
            return { posts: [] };
        }
    },

    // ==================== POST ACTIONS ====================
    async getPost(postUuid) {
        try {
            const result = await Ondes.Social.getPost(postUuid);
            return _normalizePost(result);
        } catch (e) {
            console.error('[API] getPost:', e);
            return null;
        }
    },

    async publish(options) {
        try {
            const result = await Ondes.Social.publish(options);
            return _normalizePost(result);
        } catch (e) {
            console.error('[API] publish:', e);
            throw e;
        }
    },

    async deletePost(postUuid) {
        try {
            return await Ondes.Social.deletePost(postUuid);
        } catch (e) {
            console.error('[API] deletePost:', e);
            throw e;
        }
    },

    // ==================== INTERACTIONS ====================
    async like(postUuid) {
        try {
            return await Ondes.Social.likePost(postUuid);
        } catch (e) {
            console.error('[API] like:', e);
            throw e;
        }
    },

    async unlike(postUuid) {
        try {
            return await Ondes.Social.unlikePost(postUuid);
        } catch (e) {
            console.error('[API] unlike:', e);
            throw e;
        }
    },

    async bookmark(postUuid) {
        try {
            return await Ondes.Social.bookmarkPost(postUuid);
        } catch (e) {
            console.error('[API] bookmark:', e);
            throw e;
        }
    },

    async removeBookmark(postUuid) {
        try {
            return await Ondes.Social.unbookmarkPost(postUuid);
        } catch (e) {
            console.error('[API] removeBookmark:', e);
            throw e;
        }
    },

    // ==================== COMMENTS ====================
    async getComments(postUuid, limit = 50, offset = 0) {
        try {
            const result = await Ondes.Social.getComments(postUuid, { limit, offset });
            const comments = Array.isArray(result) ? result : (result?.comments || []);
            return { comments };
        } catch (e) {
            console.error('[API] getComments:', e);
            return { comments: [] };
        }
    },

    async addComment(postUuid, content, parentUuid) {
        try {
            const result = await Ondes.Social.addComment(postUuid, content, parentUuid);
            // Handler returns a single comment map — wrap it
            return { comment: result };
        } catch (e) {
            console.error('[API] addComment:', e);
            throw e;
        }
    },

    async likeComment(commentUuid) {
        try {
            return await Ondes.Social.likeComment(commentUuid);
        } catch (e) {
            console.error('[API] likeComment:', e);
        }
    },

    async getCommentReplies(commentUuid) {
        try {
            const result = await Ondes.Social.getCommentReplies(commentUuid);
            const replies = Array.isArray(result) ? result : (result?.replies || []);
            return { replies };
        } catch (e) {
            console.error('[API] getReplies:', e);
            return { replies: [] };
        }
    },

    async deleteComment(commentUuid) {
        try {
            return await Ondes.Social.deleteComment(commentUuid);
        } catch (e) {
            console.error('[API] deleteComment:', e);
            throw e;
        }
    },

    async getPostLikers(postUuid) {
        try {
            const result = await Ondes.Social.getPostLikers(postUuid);
            const users = Array.isArray(result) ? result : (result?.users || []);
            return { users };
        } catch (e) {
            console.error('[API] getPostLikers:', e);
            return { users: [] };
        }
    },

    // ==================== FOLLOW ====================
    async follow(options) {
        try {
            return await Ondes.Social.follow(options);
        } catch (e) {
            console.error('[API] follow:', e);
            throw e;
        }
    },

    async unfollow(options) {
        try {
            return await Ondes.Social.unfollow(options);
        } catch (e) {
            console.error('[API] unfollow:', e);
            throw e;
        }
    },

    async getFollowers(userId) {
        try {
            const result = await Ondes.Social.getFollowers(userId);
            const followers = Array.isArray(result) ? result : (result?.followers || []);
            return { followers };
        } catch (e) {
            console.error('[API] getFollowers:', e);
            return { followers: [] };
        }
    },

    async getFollowing(userId) {
        try {
            const result = await Ondes.Social.getFollowing(userId);
            const following = Array.isArray(result) ? result : (result?.following || []);
            return { following };
        } catch (e) {
            console.error('[API] getFollowing:', e);
            return { following: [] };
        }
    },

    // ==================== STORIES ====================
    async getStories() {
        try {
            const result = await Ondes.Social.getStories();
            const stories = Array.isArray(result) ? result : (result?.stories || []);
            return { stories: stories.map(_normalizeStoryGroup) };
        } catch (e) {
            console.error('[API] getStories:', e);
            return { stories: [] };
        }
    },

    async createStory(options) {
        try {
            // Handler expects (mediaPath: String, duration?: number)
            const mediaPath = typeof options === 'string' ? options : options.media;
            const duration = typeof options === 'string' ? undefined : options.duration;
            return await Ondes.Social.createStory(mediaPath, duration);
        } catch (e) {
            console.error('[API] createStory:', e);
            throw e;
        }
    },

    async viewStory(storyUuid) {
        try {
            return await Ondes.Social.viewStory(storyUuid);
        } catch (e) {
            console.error('[API] viewStory:', e);
        }
    },

    async deleteStory(storyUuid) {
        try {
            return await Ondes.Social.deleteStory(storyUuid);
        } catch (e) {
            console.error('[API] deleteStory:', e);
            throw e;
        }
    },

    // ==================== MEDIA ====================
    async pickMedia(options = {}) {
        try {
            return await Ondes.Social.pickMedia(options);
        } catch (e) {
            console.error('[API] pickMedia:', e);
            return [];
        }
    },

    // ==================== FRIENDS ====================
    async getFriendsList() {
        try {
            return await Ondes.Friends.list();
        } catch (e) {
            console.error('[API] getFriendsList:', e);
            return [];
        }
    },
};
