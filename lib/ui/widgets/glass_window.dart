import 'dart:ui';
import 'package:flutter/material.dart';

class GlassWindow extends StatelessWidget {
  final double width;
  final double height;
  final Widget child;
  final String title;

  const GlassWindow({
    Key? key,
    required this.width,
    required this.height,
    required this.child,
    this.title = "Window",
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 25,
                spreadRadius: 5,
              ),
            ],
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Column(
              children: [
                // Window Header (MacOS style)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  width: double.infinity,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  child: Text(
                          title,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                ),
                // Content
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
