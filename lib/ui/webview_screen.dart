import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bridge/bridge_controller.dart';
import '../bridge/ondes_js_injection.dart';
import '../core/services/webview_pool_service.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String? appId;
  final List<String>? labPermissions;
  const WebViewScreen({super.key, required this.url, this.appId, this.labPermissions});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late OndesBridgeController _bridge;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // AppBar State (Enhanced)
  bool _appBarVisible = false;
  String _appBarTitle = "";
  Color _appBarColor = Colors.white;
  Color _appBarTextColor = Colors.black;
  double _appBarHeight = kToolbarHeight;
  bool _appBarCenterTitle = true;
  String? _appBarFontFamily;
  bool _appBarTitleBold = true;
  double _appBarTitleSize = 20;
  double _appBarElevation = 0;
  List<Map<String, dynamic>> _appBarActions = [];
  Map<String, dynamic>? _appBarLeading;
  bool _appBarShowBackButton = true;
  
  // Drawer State
  bool _drawerEnabled = false;
  Map<String, dynamic>? _drawerConfig;
  bool _endDrawerEnabled = false;
  Map<String, dynamic>? _endDrawerConfig;

  InAppWebViewController? _webController;
  InAppWebViewKeepAlive? _keepAlive;

  @override
  void initState() {
    super.initState();
    
    // Tentative de récupération d'une WebView chaude
    _keepAlive = WebViewPoolService().getAvailableKeepAlive();

    _bridge = OndesBridgeController(
      appBundleId: widget.appId, // Sandbox ID
      context, 
      onAppBarConfig: _updateAppBar,
      onDrawerConfig: _updateDrawer,
      onDrawerAction: _handleDrawerAction,
      labPermissions: widget.labPermissions,
    );
  }

  @override
  void dispose() {
    // On signale au pool qu'on a fini, pour qu'il en prépare une nouvelle fraîche
    WebViewPoolService().releaseAndRefill();
    super.dispose();
  }

  void _updateAppBar(Map<String, dynamic> config) {
    setState(() {
      if (config.containsKey('visible')) _appBarVisible = config['visible'];
      if (config.containsKey('title')) _appBarTitle = config['title'];
      if (config.containsKey('centerTitle')) _appBarCenterTitle = config['centerTitle'];
      if (config.containsKey('elevation')) _appBarElevation = (config['elevation'] as num).toDouble();
      if (config.containsKey('height')) _appBarHeight = (config['height'] as num).toDouble();
      if (config.containsKey('showBackButton')) _appBarShowBackButton = config['showBackButton'];
      
      // Title styling
      if (config.containsKey('titleBold')) _appBarTitleBold = config['titleBold'];
      if (config.containsKey('titleSize')) _appBarTitleSize = (config['titleSize'] as num).toDouble();
      if (config.containsKey('fontFamily')) _appBarFontFamily = config['fontFamily'];
      
      // Colors
      if (config.containsKey('backgroundColor')) {
         _appBarColor = _parseColor(config['backgroundColor']);
      }
      if (config.containsKey('foregroundColor')) {
         _appBarTextColor = _parseColor(config['foregroundColor']);
      }
      
      // Actions
      if (config.containsKey('actions')) {
        _appBarActions = (config['actions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      }
      
      // Leading
      if (config.containsKey('leading')) {
        _appBarLeading = config['leading'] as Map<String, dynamic>?;
      }
    });
  }

  void _updateDrawer(Map<String, dynamic> config) {
    setState(() {
      final side = config['side'] ?? 'left';
      
      if (side == 'right' || side == 'end') {
        _endDrawerEnabled = config['enabled'] ?? true;
        _endDrawerConfig = config;
      } else {
        _drawerEnabled = config['enabled'] ?? true;
        _drawerConfig = config;
      }
    });
  }

  void _handleDrawerAction(String action, Map<String, dynamic>? data) {
    if (action == 'open') {
      final side = data?['side'] ?? 'left';
      if (side == 'right' || side == 'end') {
        _scaffoldKey.currentState?.openEndDrawer();
      } else {
        _scaffoldKey.currentState?.openDrawer();
      }
    } else if (action == 'close') {
      Navigator.of(context).pop();
    }
  }

  void _onDrawerItemTap(String value) {
    Navigator.of(context).pop();
    _webController?.evaluateJavascript(
      source: "window.dispatchEvent(new CustomEvent('ondes:drawer:select', { detail: { value: '$value' } }));",
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) {
      hex = "FF$hex";
    }
    return Color(int.parse("0x$hex"));
  }

  TextStyle _buildTitleStyle() {
    TextStyle style = TextStyle(
      color: _appBarTextColor,
      fontSize: _appBarTitleSize,
      fontWeight: _appBarTitleBold ? FontWeight.bold : FontWeight.normal,
    );
    
    if (_appBarFontFamily != null) {
      try {
        style = GoogleFonts.getFont(
          _appBarFontFamily!,
          textStyle: style,
        );
      } catch (e) {
        debugPrint('Font not found: $_appBarFontFamily');
      }
    }
    
    return style;
  }

  Widget? _buildDrawer(Map<String, dynamic>? config) {
    if (config == null) return null;
    
    final header = config['header'] as Map<String, dynamic>?;
    final items = (config['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final footer = config['footer'] as Map<String, dynamic>?;
    final width = (config['width'] as num?)?.toDouble() ?? 280;
    final backgroundColor = config['backgroundColor'] != null 
        ? _parseColor(config['backgroundColor'])
        : Colors.white;
    
    return SizedBox(
      width: width,
      child: Drawer(
        backgroundColor: backgroundColor,
        shape: config['borderRadius'] != null
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular((config['borderRadius'] as num).toDouble()),
                ),
              )
            : null,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              if (header != null) _buildDrawerHeader(header),
              
              // Items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) => _buildDrawerItem(items[i]),
                ),
              ),
              
              // Footer
              if (footer != null) _buildDrawerFooter(footer),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(Map<String, dynamic> header) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: header['backgroundColor'] != null 
            ? _parseColor(header['backgroundColor'])
            : Theme.of(context).primaryColor,
        image: header['backgroundImage'] != null
            ? DecorationImage(
                image: NetworkImage(header['backgroundImage']),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.3),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header['avatar'] != null)
            CircleAvatar(
              radius: 35,
              backgroundImage: NetworkImage(header['avatar']),
              backgroundColor: Colors.white.withOpacity(0.2),
            ),
          if (header['avatar'] != null) const SizedBox(height: 12),
          if (header['title'] != null)
            Text(
              header['title'],
              style: TextStyle(
                color: header['titleColor'] != null 
                    ? _parseColor(header['titleColor'])
                    : Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (header['subtitle'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                header['subtitle'],
                style: TextStyle(
                  color: (header['subtitleColor'] != null 
                      ? _parseColor(header['subtitleColor'])
                      : Colors.white).withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(Map<String, dynamic> item) {
    // Divider
    if (item['type'] == 'divider') {
      return Divider(
        height: (item['height'] as num?)?.toDouble() ?? 16,
        thickness: (item['thickness'] as num?)?.toDouble() ?? 1,
        indent: (item['indent'] as num?)?.toDouble() ?? 16,
        endIndent: (item['endIndent'] as num?)?.toDouble() ?? 16,
      );
    }
    
    // Section Header
    if (item['type'] == 'section') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          item['title'] ?? '',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: item['color'] != null 
                ? _parseColor(item['color'])
                : Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
      );
    }
    
    // Regular Item
    final bool isSelected = item['selected'] == true;
    final bool isDisabled = item['disabled'] == true;
    
    return ListTile(
      enabled: !isDisabled,
      selected: isSelected,
      selectedTileColor: item['selectedColor'] != null 
          ? _parseColor(item['selectedColor']).withOpacity(0.1)
          : Theme.of(context).primaryColor.withOpacity(0.1),
      leading: item['icon'] != null
          ? Icon(
              _parseIcon(item['icon']),
              color: isSelected 
                  ? Theme.of(context).primaryColor
                  : (item['iconColor'] != null ? _parseColor(item['iconColor']) : null),
            )
          : null,
      title: Text(
        item['label'] ?? '',
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: item['subtitle'] != null ? Text(item['subtitle']) : null,
      trailing: _buildDrawerItemTrailing(item),
      onTap: () => _onDrawerItemTap(item['value']?.toString() ?? ''),
    );
  }

  Widget? _buildDrawerItemTrailing(Map<String, dynamic> item) {
    if (item['badge'] != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: item['badgeColor'] != null 
              ? _parseColor(item['badgeColor'])
              : Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          item['badge'].toString(),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      );
    }
    if (item['trailing'] != null) {
      return Text(
        item['trailing'],
        style: TextStyle(color: Colors.grey.shade500),
      );
    }
    if (item['hasSubmenu'] == true) {
      return const Icon(Icons.chevron_right);
    }
    return null;
  }

  Widget _buildDrawerFooter(Map<String, dynamic> footer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: footer['items'] != null
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: (footer['items'] as List).map<Widget>((item) {
                final itm = item as Map<String, dynamic>;
                return IconButton(
                  icon: Icon(_parseIcon(itm['icon'])),
                  onPressed: () => _onDrawerItemTap(itm['value']?.toString() ?? ''),
                  tooltip: itm['label'],
                );
              }).toList(),
            )
          : Text(
              footer['text'] ?? '',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
    );
  }

  List<Widget> _buildAppBarActions() {
    return _appBarActions.map((action) {
      if (action['type'] == 'icon') {
        return IconButton(
          icon: Icon(
            _parseIcon(action['icon']),
            color: action['color'] != null 
                ? _parseColor(action['color'])
                : _appBarTextColor,
          ),
          onPressed: () {
            _webController?.evaluateJavascript(
              source: "window.dispatchEvent(new CustomEvent('ondes:appbar:action', { detail: { value: '${action['value']}' } }));",
            );
          },
          tooltip: action['tooltip'],
        );
      } else if (action['type'] == 'text') {
        return TextButton(
          onPressed: () {
            _webController?.evaluateJavascript(
              source: "window.dispatchEvent(new CustomEvent('ondes:appbar:action', { detail: { value: '${action['value']}' } }));",
            );
          },
          child: Text(
            action['label'] ?? '',
            style: TextStyle(
              color: action['color'] != null 
                  ? _parseColor(action['color'])
                  : _appBarTextColor,
              fontWeight: action['bold'] == true ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      } else if (action['type'] == 'badge') {
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                _parseIcon(action['icon']),
                color: _appBarTextColor,
              ),
              onPressed: () {
                _webController?.evaluateJavascript(
                  source: "window.dispatchEvent(new CustomEvent('ondes:appbar:action', { detail: { value: '${action['value']}' } }));",
                );
              },
            ),
            if (action['badge'] != null && action['badge'] != 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: action['badgeColor'] != null 
                        ? _parseColor(action['badgeColor'])
                        : Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    action['badge'].toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      }
      return const SizedBox.shrink();
    }).toList();
  }

  Widget? _buildLeadingWidget() {
    if (_appBarLeading != null) {
      if (_appBarLeading!['type'] == 'menu') {
        return IconButton(
          icon: Icon(Icons.menu, color: _appBarTextColor),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        );
      } else if (_appBarLeading!['type'] == 'icon') {
        return IconButton(
          icon: Icon(
            _parseIcon(_appBarLeading!['icon']),
            color: _appBarTextColor,
          ),
          onPressed: () {
            _webController?.evaluateJavascript(
              source: "window.dispatchEvent(new CustomEvent('ondes:appbar:leading', { detail: {} }));",
            );
          },
        );
      } else if (_appBarLeading!['type'] == 'avatar') {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () {
              _webController?.evaluateJavascript(
                source: "window.dispatchEvent(new CustomEvent('ondes:appbar:leading', { detail: {} }));",
              );
            },
            child: CircleAvatar(
              backgroundImage: _appBarLeading!['image'] != null 
                  ? NetworkImage(_appBarLeading!['image'])
                  : null,
              backgroundColor: Colors.grey.shade300,
              child: _appBarLeading!['image'] == null 
                  ? Icon(Icons.person, color: _appBarTextColor)
                  : null,
            ),
          ),
        );
      }
    }
    
    if (!_appBarShowBackButton) {
      return const SizedBox.shrink();
    }
    
    return null; // Default back button
  }

  IconData _parseIcon(String? iconName) {
    const iconMap = <String, IconData>{
      'menu': Icons.menu,
      'back': Icons.arrow_back,
      'close': Icons.close,
      'search': Icons.search,
      'more': Icons.more_vert,
      'settings': Icons.settings,
      'notifications': Icons.notifications,
      'share': Icons.share,
      'edit': Icons.edit,
      'delete': Icons.delete,
      'add': Icons.add,
      'home': Icons.home,
      'person': Icons.person,
      'favorite': Icons.favorite,
      'bookmark': Icons.bookmark,
      'cart': Icons.shopping_cart,
      'filter': Icons.filter_list,
      'refresh': Icons.refresh,
      'download': Icons.download,
      'upload': Icons.upload,
      'camera': Icons.camera_alt,
      'photo': Icons.photo,
      'message': Icons.message,
      'call': Icons.call,
      'email': Icons.email,
      'location': Icons.location_on,
      'calendar': Icons.calendar_today,
      'clock': Icons.access_time,
      'star': Icons.star,
      'heart': Icons.favorite,
      'thumb_up': Icons.thumb_up,
      'check': Icons.check,
      'info': Icons.info,
      'help': Icons.help,
      'warning': Icons.warning,
      'error': Icons.error,
      'lock': Icons.lock,
      'logout': Icons.logout,
      'qrcode': Icons.qr_code,
      'flash': Icons.flash_on,
      'moon': Icons.nightlight_round,
      'sun': Icons.wb_sunny,
    };
    return iconMap[iconName] ?? Icons.circle;
  }

  @override
  Widget build(BuildContext context) {
    // Make status bar transparent for immersive experience
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, 
    ));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.black, // Immersive
      extendBody: true,
      extendBodyBehindAppBar: false,
      appBar: _appBarVisible 
          ? PreferredSize(
              preferredSize: Size.fromHeight(_appBarHeight),
              child: AppBar(
                title: Text(_appBarTitle, style: _buildTitleStyle()),
                centerTitle: _appBarCenterTitle,
                backgroundColor: _appBarColor,
                iconTheme: IconThemeData(color: _appBarTextColor),
                elevation: _appBarElevation,
                toolbarHeight: _appBarHeight,
                leading: _buildLeadingWidget(),
                actions: _buildAppBarActions(),
              ),
            )
          : null,
      drawer: _drawerEnabled ? _buildDrawer(_drawerConfig) : null,
      endDrawer: _endDrawerEnabled ? _buildDrawer(_endDrawerConfig) : null,
      body: Stack(
        children: [
          InAppWebView(
            keepAlive: _keepAlive,
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: InAppWebViewSettings(
              isInspectable: true, // Specific for debugging/Lab
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              iframeAllow: "camera; microphone",
              transparentBackground: true,
              
              // Allow Local Server (HTTP)
              allowUniversalAccessFromFileURLs: true,
            ),
            onWebViewCreated: (controller) {
              _webController = controller;
              _bridge.setController(controller);

              if (_keepAlive != null) {
                 // Si c'est une vue recyclée, on doit charger l'URL manuellement
                 // car initialUrlRequest peut être ignoré si la vue est restaurée.
                 controller.loadUrl(urlRequest: URLRequest(url: WebUri(widget.url)));
              }
            },
            onLoadStart: (controller, url) {
              // Reinject just in case, though UserScript is better
            },
            onLoadStop: (controller, url) async {
                // Inject the Bridge JS
                await controller.evaluateJavascript(source: ondesBridgeJs);
            },
            onPermissionRequest: (controller, request) async {
              return PermissionResponse(
                resources: request.resources,
                action: PermissionResponseAction.GRANT,
              );
            },
            onConsoleMessage: (controller, msg) {
              print("JS Console: ${msg.message}");
            },
          ),
          // Fallback Back Button (only if no native AppBar is visible)
          if (!_appBarVisible)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.home, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
