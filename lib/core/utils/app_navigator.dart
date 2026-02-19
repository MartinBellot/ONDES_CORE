import 'package:flutter/material.dart';

/// Global navigator key injected into [MaterialApp].
/// Used by [GenesisIslandWidget] to push routes from outside the widget tree.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
