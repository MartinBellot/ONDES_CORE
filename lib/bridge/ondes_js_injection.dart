const String ondesBridgeJs = """
(function() {
    console.log("🌊 Injecting Ondes Core Bridge...");

    if (window.Ondes) return; // Already injected

    window.Ondes = {
        UI: {
            showToast: async function(options) {
                return await window.flutter_inappwebview.callHandler('Ondes.UI.showToast', options);
            },
            configureAppBar: async function(options) {
                return await window.flutter_inappwebview.callHandler('Ondes.UI.configureAppBar', options);
            },
            showAlert: async function(options) {
                return await window.flutter_inappwebview.callHandler('Ondes.UI.showAlert', options);
            }
        },
        User: {
            getProfile: async function() {
                return await window.flutter_inappwebview.callHandler('Ondes.User.getProfile');
            },
            getAuthToken: async function() {
                return await window.flutter_inappwebview.callHandler('Ondes.User.getAuthToken');
            }
        },
        Device: {
            hapticFeedback: async function(style) {
                return await window.flutter_inappwebview.callHandler('Ondes.Device.hapticFeedback', style);
            },
            scanQRCode: async function() {
                return await window.flutter_inappwebview.callHandler('Ondes.Device.scanQRCode');
            },
            getGPSPosition: async function() {
                return await window.flutter_inappwebview.callHandler('Ondes.Device.getGPSPosition');
            }
        },
        Storage: {
            set: async function(key, value) {
                return await window.flutter_inappwebview.callHandler('Ondes.Storage.set', [key, value]);
            },
            get: async function(key) {
                return await window.flutter_inappwebview.callHandler('Ondes.Storage.get', key);
            },
            remove: async function(key) {
                return await window.flutter_inappwebview.callHandler('Ondes.Storage.remove', key);
            }
        },
        App: {
            getInfo: async function() {
                return await window.flutter_inappwebview.callHandler('Ondes.App.getInfo');
            },
            close: async function() {
                return await window.flutter_inappwebview.callHandler('Ondes.App.close');
            }
        }
    };

    // Event ready
    const event = new Event('OndesReady');
    document.dispatchEvent(event);
    console.log("✅ Ondes Core Bridge Ready");
})();
""";
