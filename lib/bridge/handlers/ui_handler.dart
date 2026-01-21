import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'base_handler.dart';

/// Handler for Ondes.UI namespace
/// Manages native UI components (toast, alerts, app bar, modals, drawers)
class UIHandler extends BaseHandler {
  final Function(Map<String, dynamic>)? onAppBarConfig;
  final Function(Map<String, dynamic>)? onDrawerConfig;
  final Function(String action, Map<String, dynamic>? data)? onDrawerAction;

  // Loading overlay state
  OverlayEntry? _loadingOverlay;

  UIHandler(BuildContext context, {
    this.onAppBarConfig, 
    this.onDrawerConfig,
    this.onDrawerAction,
  }) : super(context);

  @override
  void registerHandlers() {
    // Basic UI
    _registerShowToast();
    _registerShowAlert();
    _registerShowConfirm();
    _registerShowBottomSheet();
    
    // AppBar (Enhanced)
    _registerConfigureAppBar();
    
    // Drawer System
    _registerConfigureDrawer();
    _registerOpenDrawer();
    _registerCloseDrawer();
    
    // Modal System (Ultra-customized)
    _registerShowModal();
    _registerShowInputDialog();
    _registerShowActionSheet();
    
    // Loading & Progress
    _registerShowLoading();
    _registerHideLoading();
    _registerShowProgress();
    
    // Advanced Snackbar
    _registerShowSnackbar();
  }

  // ============== TOAST ==============
  void _registerShowToast() {
    addSyncHandler('Ondes.UI.showToast', (args) {
      final options = args[0] as Map<String, dynamic>;
      final message = options['message'] ?? '';
      final type = options['type'] ?? 'info';
      final duration = options['duration'] ?? 3000;
      final position = options['position'] ?? 'bottom'; // 'top', 'bottom'

      Color bgColor = Colors.black87;
      IconData? icon;

      switch (type) {
        case 'error':
          bgColor = Colors.red.shade700;
          icon = Icons.error_outline;
          break;
        case 'success':
          bgColor = Colors.green.shade700;
          icon = Icons.check_circle_outline;
          break;
        case 'warning':
          bgColor = Colors.orange.shade700;
          icon = Icons.warning_amber_outlined;
          break;
        default:
          bgColor = Colors.blueGrey.shade800;
          icon = Icons.info_outline;
      }

      // Custom background color
      if (options['backgroundColor'] != null) {
        bgColor = _parseColor(options['backgroundColor']);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (options['hideIcon'] != true) ...[
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontWeight: options['bold'] == true ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          margin: position == 'top' 
              ? EdgeInsets.only(
                  bottom: MediaQuery.of(context).size.height - 150,
                  left: 16,
                  right: 16,
                )
              : const EdgeInsets.all(16),
          duration: Duration(milliseconds: duration),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    });
  }

  // ============== ALERT ==============
  void _registerShowAlert() {
    addHandler('Ondes.UI.showAlert', (args) async {
      final options = args[0] as Map<String, dynamic>;
      await showDialog(
        context: context,
        barrierDismissible: options['dismissible'] ?? true,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(options['borderRadius']?.toDouble() ?? 16),
          ),
          backgroundColor: options['backgroundColor'] != null 
              ? _parseColor(options['backgroundColor']) 
              : null,
          icon: options['icon'] != null 
              ? Icon(
                  _parseIcon(options['icon']),
                  size: 48,
                  color: options['iconColor'] != null 
                      ? _parseColor(options['iconColor'])
                      : Theme.of(ctx).primaryColor,
                )
              : null,
          title: Text(
            options['title'] ?? 'Alert',
            style: _buildTextStyle(options['titleStyle']),
          ),
          content: Text(
            options['message'] ?? '',
            style: _buildTextStyle(options['messageStyle']),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                foregroundColor: options['buttonColor'] != null 
                    ? _parseColor(options['buttonColor'])
                    : null,
              ),
              child: Text(
                options['buttonText'] ?? 'OK',
                style: _buildTextStyle(options['buttonStyle']),
              ),
            )
          ],
        ),
      );
      return null;
    });
  }

  // ============== CONFIRM ==============
  void _registerShowConfirm() {
    addHandler('Ondes.UI.showConfirm', (args) async {
      final options = args[0] as Map<String, dynamic>;
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: options['dismissible'] ?? true,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(options['borderRadius']?.toDouble() ?? 16),
          ),
          icon: options['icon'] != null 
              ? Icon(
                  _parseIcon(options['icon']),
                  size: 48,
                  color: options['iconColor'] != null 
                      ? _parseColor(options['iconColor'])
                      : null,
                )
              : null,
          title: Text(
            options['title'] ?? 'Confirm',
            style: _buildTextStyle(options['titleStyle']),
          ),
          content: Text(
            options['message'] ?? '',
            style: _buildTextStyle(options['messageStyle']),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(
                foregroundColor: options['cancelColor'] != null 
                    ? _parseColor(options['cancelColor'])
                    : Colors.grey,
              ),
              child: Text(
                options['cancelText'] ?? 'Cancel',
                style: _buildTextStyle(options['cancelStyle']),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: options['confirmColor'] != null 
                    ? _parseColor(options['confirmColor'])
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                options['confirmText'] ?? 'Confirm',
                style: _buildTextStyle(options['confirmStyle']),
              ),
            ),
          ],
        ),
      );
      return result ?? false;
    });
  }

  // ============== APPBAR (ENHANCED) ==============
  void _registerConfigureAppBar() {
    addSyncHandler('Ondes.UI.configureAppBar', (args) {
      if (args.isNotEmpty && onAppBarConfig != null) {
        onAppBarConfig!(args[0] as Map<String, dynamic>);
      }
    });
  }

  // ============== DRAWER SYSTEM ==============
  void _registerConfigureDrawer() {
    addSyncHandler('Ondes.UI.configureDrawer', (args) {
      if (args.isNotEmpty && onDrawerConfig != null) {
        onDrawerConfig!(args[0] as Map<String, dynamic>);
      }
    });
  }

  void _registerOpenDrawer() {
    addSyncHandler('Ondes.UI.openDrawer', (args) {
      final side = args.isNotEmpty ? args[0] : 'left';
      if (onDrawerAction != null) {
        onDrawerAction!('open', {'side': side});
      }
    });
  }

  void _registerCloseDrawer() {
    addSyncHandler('Ondes.UI.closeDrawer', (args) {
      if (onDrawerAction != null) {
        onDrawerAction!('close', null);
      }
    });
  }

  // ============== BOTTOM SHEET ==============
  void _registerShowBottomSheet() {
    addHandler('Ondes.UI.showBottomSheet', (args) async {
      final options = args[0] as Map<String, dynamic>;
      final items = (options['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final isScrollable = options['scrollable'] ?? false;
      final showDragHandle = options['showDragHandle'] ?? true;
      
      final result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: isScrollable,
        backgroundColor: options['backgroundColor'] != null 
            ? _parseColor(options['backgroundColor'])
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(options['borderRadius']?.toDouble() ?? 20),
          ),
        ),
        showDragHandle: showDragHandle,
        builder: (ctx) => SafeArea(
          child: Container(
            constraints: isScrollable 
                ? BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8)
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (options['title'] != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Text(
                      options['title'],
                      style: _buildTextStyle(options['titleStyle']) ?? 
                          const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (options['subtitle'] != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Text(
                      options['subtitle'],
                      style: _buildTextStyle(options['subtitleStyle']) ??
                          TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ),
                if (isScrollable)
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (ctx, i) => _buildBottomSheetItem(ctx, items[i]),
                    ),
                  )
                else
                  ...items.map((item) => _buildBottomSheetItem(ctx, item)),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
      return result;
    });
  }

  Widget _buildBottomSheetItem(BuildContext ctx, Map<String, dynamic> item) {
    final bool isDanger = item['danger'] == true;
    final bool isDisabled = item['disabled'] == true;
    
    return ListTile(
      enabled: !isDisabled,
      leading: item['icon'] != null 
          ? Icon(
              _parseIcon(item['icon']),
              color: isDanger 
                  ? Colors.red 
                  : (item['iconColor'] != null ? _parseColor(item['iconColor']) : null),
            ) 
          : null,
      title: Text(
        item['label'] ?? '',
        style: TextStyle(
          color: isDanger ? Colors.red : null,
          fontWeight: item['bold'] == true ? FontWeight.bold : null,
        ),
      ),
      subtitle: item['subtitle'] != null ? Text(item['subtitle']) : null,
      trailing: item['trailing'] != null 
          ? Text(item['trailing'], style: TextStyle(color: Colors.grey.shade500))
          : null,
      onTap: () => Navigator.pop(ctx, item['value']?.toString()),
    );
  }

  // ============== MODAL SYSTEM (ULTRA-CUSTOMIZED) ==============
  void _registerShowModal() {
    addHandler('Ondes.UI.showModal', (args) async {
      final options = args[0] as Map<String, dynamic>;
      final buttons = (options['buttons'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: options['dismissible'] ?? true,
        barrierColor: options['barrierColor'] != null 
            ? _parseColor(options['barrierColor'])
            : Colors.black54,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(options['borderRadius']?.toDouble() ?? 20),
          ),
          backgroundColor: options['backgroundColor'] != null 
              ? _parseColor(options['backgroundColor'])
              : Colors.white,
          elevation: options['elevation']?.toDouble() ?? 8,
          child: Container(
            width: options['width']?.toDouble(),
            constraints: BoxConstraints(
              maxWidth: options['maxWidth']?.toDouble() ?? 400,
              maxHeight: options['maxHeight']?.toDouble() ?? MediaQuery.of(ctx).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                if (options['header'] != null) _buildModalHeader(ctx, options['header']),
                
                // Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(options['padding']?.toDouble() ?? 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (options['icon'] != null)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: (options['iconBackgroundColor'] != null 
                                    ? _parseColor(options['iconBackgroundColor'])
                                    : Theme.of(ctx).primaryColor).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _parseIcon(options['icon']),
                                size: options['iconSize']?.toDouble() ?? 48,
                                color: options['iconColor'] != null 
                                    ? _parseColor(options['iconColor'])
                                    : Theme.of(ctx).primaryColor,
                              ),
                            ),
                          ),
                        if (options['icon'] != null) const SizedBox(height: 16),
                        
                        if (options['title'] != null)
                          Text(
                            options['title'],
                            style: _buildTextStyle(options['titleStyle']) ??
                                const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            textAlign: options['centerContent'] == true 
                                ? TextAlign.center 
                                : TextAlign.start,
                          ),
                        if (options['title'] != null) const SizedBox(height: 8),
                        
                        if (options['message'] != null)
                          Text(
                            options['message'],
                            style: _buildTextStyle(options['messageStyle']) ??
                                TextStyle(fontSize: 16, color: Colors.grey.shade700),
                            textAlign: options['centerContent'] == true 
                                ? TextAlign.center 
                                : TextAlign.start,
                          ),
                        
                        // Custom content sections
                        if (options['sections'] != null)
                          ..._buildModalSections(options['sections']),
                      ],
                    ),
                  ),
                ),
                
                // Footer / Buttons
                if (buttons.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: options['footerColor'] != null 
                          ? _parseColor(options['footerColor'])
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(options['borderRadius']?.toDouble() ?? 20),
                      ),
                    ),
                    child: options['buttonsLayout'] == 'vertical'
                        ? Column(
                            children: buttons.map((btn) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildModalButton(ctx, btn),
                            )).toList(),
                          )
                        : Row(
                            children: buttons.asMap().entries.map((entry) {
                              final btn = entry.value;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: entry.key > 0 ? 8 : 0,
                                  ),
                                  child: _buildModalButton(ctx, btn),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
              ],
            ),
          ),
        ),
      );
      return result;
    });
  }

  Widget _buildModalHeader(BuildContext ctx, Map<String, dynamic> header) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: header['backgroundColor'] != null 
            ? _parseColor(header['backgroundColor'])
            : Theme.of(ctx).primaryColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          if (header['icon'] != null)
            Icon(
              _parseIcon(header['icon']),
              color: header['iconColor'] != null 
                  ? _parseColor(header['iconColor'])
                  : Colors.white,
            ),
          if (header['icon'] != null) const SizedBox(width: 12),
          Expanded(
            child: Text(
              header['title'] ?? '',
              style: _buildTextStyle(header['titleStyle']) ??
                  const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
          ),
          if (header['showClose'] == true)
            IconButton(
              icon: Icon(
                Icons.close,
                color: header['closeColor'] != null 
                    ? _parseColor(header['closeColor'])
                    : Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildModalSections(List<dynamic> sections) {
    return sections.map<Widget>((section) {
      final sec = section as Map<String, dynamic>;
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sec['title'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  sec['title'],
                  style: _buildTextStyle(sec['titleStyle']) ??
                      TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                ),
              ),
            if (sec['content'] != null)
              Text(
                sec['content'],
                style: _buildTextStyle(sec['contentStyle']),
              ),
            if (sec['items'] != null)
              ...((sec['items'] as List).map((item) {
                final itm = item as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      if (itm['icon'] != null) ...[
                        Icon(_parseIcon(itm['icon']), size: 20),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: Text(itm['text'] ?? '')),
                      if (itm['value'] != null)
                        Text(
                          itm['value'],
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: itm['valueColor'] != null 
                                ? _parseColor(itm['valueColor'])
                                : null,
                          ),
                        ),
                    ],
                  ),
                );
              })),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildModalButton(BuildContext ctx, Map<String, dynamic> btn) {
    final bool isPrimary = btn['primary'] == true;
    final bool isDanger = btn['danger'] == true;
    final bool isOutlined = btn['outlined'] == true;
    
    Color buttonColor = Theme.of(ctx).primaryColor;
    if (isDanger) buttonColor = Colors.red;
    if (btn['color'] != null) buttonColor = _parseColor(btn['color']);
    
    if (isOutlined) {
      return OutlinedButton(
        onPressed: () => Navigator.pop(ctx, btn['value']?.toString()),
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonColor,
          side: BorderSide(color: buttonColor),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(btn['borderRadius']?.toDouble() ?? 10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (btn['icon'] != null) ...[
              Icon(_parseIcon(btn['icon']), size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              btn['label'] ?? '',
              style: _buildTextStyle(btn['labelStyle']),
            ),
          ],
        ),
      );
    }
    
    return ElevatedButton(
      onPressed: () => Navigator.pop(ctx, btn['value']?.toString()),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary || isDanger ? buttonColor : Colors.grey.shade200,
        foregroundColor: isPrimary || isDanger ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 14),
        elevation: isPrimary ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(btn['borderRadius']?.toDouble() ?? 10),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (btn['icon'] != null) ...[
            Icon(_parseIcon(btn['icon']), size: 18),
            const SizedBox(width: 8),
          ],
          Text(
            btn['label'] ?? '',
            style: _buildTextStyle(btn['labelStyle']),
          ),
        ],
      ),
    );
  }

  // ============== INPUT DIALOG ==============
  void _registerShowInputDialog() {
    addHandler('Ondes.UI.showInputDialog', (args) async {
      final options = args[0] as Map<String, dynamic>;
      final controller = TextEditingController(text: options['defaultValue'] ?? '');
      
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: options['dismissible'] ?? true,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(options['borderRadius']?.toDouble() ?? 16),
          ),
          title: Text(
            options['title'] ?? 'Input',
            style: _buildTextStyle(options['titleStyle']),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (options['message'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    options['message'],
                    style: _buildTextStyle(options['messageStyle']),
                  ),
                ),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: _parseKeyboardType(options['keyboardType']),
                obscureText: options['obscureText'] ?? false,
                maxLines: options['multiline'] == true ? 4 : 1,
                maxLength: options['maxLength'],
                decoration: InputDecoration(
                  hintText: options['placeholder'] ?? '',
                  labelText: options['label'],
                  prefixIcon: options['prefixIcon'] != null 
                      ? Icon(_parseIcon(options['prefixIcon']))
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(options['cancelText'] ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: options['confirmColor'] != null 
                    ? _parseColor(options['confirmColor'])
                    : null,
              ),
              child: Text(options['confirmText'] ?? 'OK'),
            ),
          ],
        ),
      );
      return result;
    });
  }

  // ============== ACTION SHEET (iOS Style) ==============
  void _registerShowActionSheet() {
    addHandler('Ondes.UI.showActionSheet', (args) async {
      final options = args[0] as Map<String, dynamic>;
      final actions = (options['actions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      
      final result = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          margin: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Actions Container
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    if (options['title'] != null || options['message'] != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Column(
                          children: [
                            if (options['title'] != null)
                              Text(
                                options['title'],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            if (options['message'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  options['message'],
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ...actions.asMap().entries.map((entry) {
                      final action = entry.value;
                      final bool isDestructive = action['destructive'] == true;
                      return InkWell(
                        onTap: () => Navigator.pop(ctx, action['value']?.toString()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            border: entry.key < actions.length - 1
                                ? Border(bottom: BorderSide(color: Colors.grey.shade200))
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              action['label'] ?? '',
                              style: TextStyle(
                                fontSize: 20,
                                color: isDestructive ? Colors.red : Colors.blue,
                                fontWeight: action['bold'] == true ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Cancel Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InkWell(
                  onTap: () => Navigator.pop(ctx, null),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        options['cancelText'] ?? 'Cancel',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: MediaQuery.of(ctx).padding.bottom),
            ],
          ),
        ),
      );
      return result;
    });
  }

  // ============== LOADING OVERLAY ==============
  void _registerShowLoading() {
    addSyncHandler('Ondes.UI.showLoading', (args) {
      final options = args.isNotEmpty ? args[0] as Map<String, dynamic> : <String, dynamic>{};
      
      _hideLoadingOverlay();
      
      _loadingOverlay = OverlayEntry(
        builder: (context) => Material(
          color: Colors.transparent,
          child:
         Container(
          color: (options['barrierColor'] != null 
              ? _parseColor(options['barrierColor'])
              : Colors.black).withOpacity(options['barrierOpacity']?.toDouble() ?? 0.5),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: options['backgroundColor'] != null 
                    ? _parseColor(options['backgroundColor'])
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: options['spinnerSize']?.toDouble() ?? 40,
                    height: options['spinnerSize']?.toDouble() ?? 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        options['spinnerColor'] != null 
                            ? _parseColor(options['spinnerColor'])
                            : Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  if (options['message'] != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      options['message'],
                      style: _buildTextStyle(options['messageStyle']) ??
                          const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        )
      );
      
      Overlay.of(context).insert(_loadingOverlay!);
    });
  }

  void _registerHideLoading() {
    addSyncHandler('Ondes.UI.hideLoading', (args) {
      _hideLoadingOverlay();
    });
  }

  void _hideLoadingOverlay() {
    _loadingOverlay?.remove();
    _loadingOverlay = null;
  }

  // ============== PROGRESS DIALOG ==============
  void _registerShowProgress() {
    addHandler('Ondes.UI.showProgress', (args) async {
      final options = args[0] as Map<String, dynamic>;
      final progress = (options['progress'] as num?)?.toDouble() ?? 0.0;
      
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (options['title'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    options['title'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              LinearProgressIndicator(
                value: progress / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  options['color'] != null 
                      ? _parseColor(options['color'])
                      : Theme.of(ctx).primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                options['message'] ?? '${progress.toInt()}%',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
      return null;
    });
  }

  // ============== ADVANCED SNACKBAR ==============
  void _registerShowSnackbar() {
    addHandler('Ondes.UI.showSnackbar', (args) async {
      final options = args[0] as Map<String, dynamic>;
      final completer = Completer<String?>();
      
      final snackBar = SnackBar(
        content: Row(
          children: [
            if (options['icon'] != null) ...[
              Icon(
                _parseIcon(options['icon']),
                color: options['iconColor'] != null 
                    ? _parseColor(options['iconColor'])
                    : Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    options['message'] ?? '',
                    style: _buildTextStyle(options['messageStyle']) ??
                        const TextStyle(color: Colors.white),
                  ),
                  if (options['subtitle'] != null)
                    Text(
                      options['subtitle'],
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: options['backgroundColor'] != null 
            ? _parseColor(options['backgroundColor'])
            : Colors.grey.shade900,
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: options['duration'] ?? 4000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(options['borderRadius']?.toDouble() ?? 12),
        ),
        margin: const EdgeInsets.all(16),
        action: options['action'] != null
            ? SnackBarAction(
                label: options['action']['label'] ?? 'Action',
                textColor: options['action']['color'] != null 
                    ? _parseColor(options['action']['color'])
                    : Colors.blue.shade200,
                onPressed: () {
                  completer.complete(options['action']['value']?.toString());
                },
              )
            : null,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      
      // If no action, return null after duration
      if (options['action'] == null) {
        return null;
      }
      
      return completer.future.timeout(
        Duration(milliseconds: options['duration'] ?? 4000),
        onTimeout: () => null,
      );
    });
  }

  // ============== HELPER METHODS ==============
  
  Color _parseColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) {
      hex = "FF$hex";
    }
    return Color(int.parse("0x$hex"));
  }

  TextStyle? _buildTextStyle(Map<String, dynamic>? style) {
    if (style == null) return null;
    
    TextStyle baseStyle = TextStyle(
      fontSize: style['fontSize']?.toDouble(),
      fontWeight: style['bold'] == true ? FontWeight.bold 
          : (style['fontWeight'] != null ? _parseFontWeight(style['fontWeight']) : null),
      fontStyle: style['italic'] == true ? FontStyle.italic : null,
      color: style['color'] != null ? _parseColor(style['color']) : null,
      letterSpacing: style['letterSpacing']?.toDouble(),
      height: style['lineHeight']?.toDouble(),
      decoration: style['underline'] == true ? TextDecoration.underline : null,
    );
    
    // Apply Google Font if specified
    if (style['fontFamily'] != null) {
      try {
        baseStyle = GoogleFonts.getFont(
          style['fontFamily'],
          textStyle: baseStyle,
        );
      } catch (e) {
        // Fallback to default if font not found
        debugPrint('Font not found: ${style['fontFamily']}');
      }
    }
    
    return baseStyle;
  }

  FontWeight _parseFontWeight(dynamic weight) {
    if (weight is int) {
      switch (weight) {
        case 100: return FontWeight.w100;
        case 200: return FontWeight.w200;
        case 300: return FontWeight.w300;
        case 400: return FontWeight.w400;
        case 500: return FontWeight.w500;
        case 600: return FontWeight.w600;
        case 700: return FontWeight.w700;
        case 800: return FontWeight.w800;
        case 900: return FontWeight.w900;
      }
    }
    if (weight == 'bold') return FontWeight.bold;
    if (weight == 'normal') return FontWeight.normal;
    return FontWeight.normal;
  }

  TextInputType _parseKeyboardType(String? type) {
    switch (type) {
      case 'email': return TextInputType.emailAddress;
      case 'number': return TextInputType.number;
      case 'phone': return TextInputType.phone;
      case 'url': return TextInputType.url;
      case 'multiline': return TextInputType.multiline;
      default: return TextInputType.text;
    }
  }

  IconData _parseIcon(String? iconName) {
    // Comprehensive icon mapping
    const iconMap = <String, IconData>{
      // Actions
      'share': Icons.share,
      'copy': Icons.copy,
      'delete': Icons.delete,
      'edit': Icons.edit,
      'save': Icons.save,
      'add': Icons.add,
      'remove': Icons.remove,
      'close': Icons.close,
      'check': Icons.check,
      'done': Icons.done,
      'cancel': Icons.cancel,
      'refresh': Icons.refresh,
      'search': Icons.search,
      'filter': Icons.filter_list,
      'sort': Icons.sort,
      'menu': Icons.menu,
      'more': Icons.more_vert,
      'more_horiz': Icons.more_horiz,
      
      // Media
      'camera': Icons.camera_alt,
      'gallery': Icons.photo_library,
      'photo': Icons.photo,
      'video': Icons.videocam,
      'music': Icons.music_note,
      'mic': Icons.mic,
      'play': Icons.play_arrow,
      'pause': Icons.pause,
      'stop': Icons.stop,
      
      // Communication
      'message': Icons.message,
      'chat': Icons.chat,
      'call': Icons.call,
      'email': Icons.email,
      'send': Icons.send,
      'notifications': Icons.notifications,
      'notification': Icons.notifications,
      
      // Navigation
      'home': Icons.home,
      'back': Icons.arrow_back,
      'forward': Icons.arrow_forward,
      'up': Icons.arrow_upward,
      'down': Icons.arrow_downward,
      'left': Icons.chevron_left,
      'right': Icons.chevron_right,
      'expand': Icons.expand_more,
      'collapse': Icons.expand_less,
      
      // User & Profile
      'person': Icons.person,
      'user': Icons.person,
      'people': Icons.people,
      'group': Icons.group,
      'profile': Icons.account_circle,
      'avatar': Icons.account_circle,
      'logout': Icons.logout,
      'login': Icons.login,
      
      // Files & Documents
      'file': Icons.insert_drive_file,
      'folder': Icons.folder,
      'document': Icons.description,
      'download': Icons.download,
      'upload': Icons.upload,
      'attach': Icons.attach_file,
      'link': Icons.link,
      
      // Status & Feedback
      'info': Icons.info,
      'warning': Icons.warning,
      'error': Icons.error,
      'success': Icons.check_circle,
      'help': Icons.help,
      'question': Icons.help_outline,
      'star': Icons.star,
      'star_outline': Icons.star_outline,
      'heart': Icons.favorite,
      'heart_outline': Icons.favorite_border,
      'like': Icons.thumb_up,
      'dislike': Icons.thumb_down,
      
      // Settings & Tools
      'settings': Icons.settings,
      'config': Icons.tune,
      'lock': Icons.lock,
      'unlock': Icons.lock_open,
      'key': Icons.vpn_key,
      'security': Icons.security,
      'privacy': Icons.privacy_tip,
      
      // Location & Maps
      'location': Icons.location_on,
      'map': Icons.map,
      'navigation': Icons.navigation,
      'compass': Icons.explore,
      'gps': Icons.gps_fixed,
      
      // Time & Calendar
      'time': Icons.access_time,
      'clock': Icons.schedule,
      'calendar': Icons.calendar_today,
      'event': Icons.event,
      'alarm': Icons.alarm,
      'timer': Icons.timer,
      
      // Shopping & Commerce
      'cart': Icons.shopping_cart,
      'bag': Icons.shopping_bag,
      'store': Icons.store,
      'payment': Icons.payment,
      'credit_card': Icons.credit_card,
      'money': Icons.attach_money,
      
      // Device & Hardware
      'phone': Icons.phone_android,
      'tablet': Icons.tablet,
      'laptop': Icons.laptop,
      'desktop': Icons.desktop_windows,
      'bluetooth': Icons.bluetooth,
      'wifi': Icons.wifi,
      'battery': Icons.battery_full,
      'brightness': Icons.brightness_6,
      'volume': Icons.volume_up,
      'volume_off': Icons.volume_off,
      
      // Weather
      'sun': Icons.wb_sunny,
      'moon': Icons.nightlight_round,
      'cloud': Icons.cloud,
      'rain': Icons.water_drop,
      'snow': Icons.ac_unit,
      'thunder': Icons.flash_on,
      
      // Social
      'bookmark': Icons.bookmark,
      'bookmark_outline': Icons.bookmark_border,
      'flag': Icons.flag,
      'report': Icons.report,
      'block': Icons.block,
      
      // Misc
      'qrcode': Icons.qr_code,
      'barcode': Icons.qr_code_scanner,
      'fingerprint': Icons.fingerprint,
      'face': Icons.face,
      'emoji': Icons.emoji_emotions,
      'gift': Icons.card_giftcard,
      'trophy': Icons.emoji_events,
      'award': Icons.military_tech,
      'fire': Icons.local_fire_department,
      'flash': Icons.flash_on,
      'power': Icons.power_settings_new,
      'print': Icons.print,
      'code': Icons.code,
      'terminal': Icons.terminal,
      'bug': Icons.bug_report,
      'analytics': Icons.analytics,
      'dashboard': Icons.dashboard,
      'chart': Icons.bar_chart,
      'pie_chart': Icons.pie_chart,
    };
    
    return iconMap[iconName] ?? Icons.circle;
  }
}
