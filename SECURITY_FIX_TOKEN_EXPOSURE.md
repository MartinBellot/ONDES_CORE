# Security Fix: Token Exposure Vulnerability

## 🚨 Problem

**Issue:** The `Ondes.User.getAuthToken()` method in the bridge directly exposed authentication tokens to all mini-apps.

**Risk Level:** 🔴 **CRITICAL**

**Impact:**
- Any mini-app could call `Ondes.User.getAuthToken()` to retrieve the user's authentication token
- A malicious mini-app could steal this token and:
  - Impersonate the user
  - Access their account, posts, messages, friends
  - Make API calls on behalf of the user
  - Potentially exfiltrate the token to external servers

## ✅ Solution

**Removed token exposure entirely** by eliminating the `getAuthToken()` method from:
1. Bridge handler (`lib/bridge/handlers/user_handler.dart`)
2. JavaScript bridge (`lib/bridge/ondes_js_injection.dart`)
3. SDK module (`packages/ondes_sdk/lib/src/modules/user.dart`)

## 🛡️ Security Model

Mini-apps now **cannot access authentication tokens**. Instead, they must use secure bridge APIs:

| Previous (Insecure) | Current (Secure) |
|---------------------|------------------|
| Mini-app gets token → Makes API calls | Mini-app calls bridge API → Bridge makes authenticated calls |
| Token exposed to mini-app code | Token stays within native app |
| Malicious app can steal token | Malicious app has no token access |

## 📚 Available Secure APIs

Mini-apps have full functionality through these secure bridge APIs:

- **`Ondes.Social.*`** - Posts, likes, comments, stories, feed
- **`Ondes.Friends.*`** - Friend management, requests, blocking
- **`Ondes.Storage.*`** - Persistent data storage
- **`Ondes.Device.*`** - GPS, camera, haptic feedback
- **`Ondes.UI.*`** - Native UI components
- **`Ondes.Websocket.*`** - WebSocket connections
- **`Ondes.UDP.*`** - UDP communications

All these APIs handle authentication internally and securely.

## 📝 Migration Guide

### For Mini-App Developers

If your mini-app was using `getAuthToken()`:

```javascript
// ❌ OLD CODE (no longer works)
const token = await Ondes.User.getAuthToken();
fetch('https://api.backend.com/posts', {
    headers: { 'Authorization': `Token ${token}` }
});

// ✅ NEW CODE (use bridge APIs)
const posts = await Ondes.Social.getFeed({ limit: 20 });
```

### For Platform Developers

If you need to add new authenticated endpoints:
1. Create a new handler in `lib/bridge/handlers/`
2. Use `AuthService().token` internally to make authenticated requests
3. Return only the necessary data to the mini-app
4. **Never** expose the token itself

## 🔍 Verification

- ✅ CodeQL security scan: 0 alerts
- ✅ All references to `getAuthToken()` removed or commented out
- ✅ Documentation updated with security rationale
- ✅ Example apps updated to use secure alternatives

## 📖 References

- User documentation: `docs/sdk/user.md`
- Flutter SDK documentation: `docs/sdk/flutter.md`
- Implementation: `lib/bridge/handlers/user_handler.dart`

## 🎯 Impact

**Breaking Change:** Mini-apps using `getAuthToken()` will no longer function

**Mitigation:** All necessary functionality is available through secure bridge APIs

**Benefit:** Eliminates critical security vulnerability that could lead to account takeover
