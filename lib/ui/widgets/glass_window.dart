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
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 12),
                      // Traffic Lights
                      _trafficLight(Colors.redAccent),
                      SizedBox(width: 8),
                      _trafficLight(Colors.amber),
                      SizedBox(width: 8),
                      _trafficLight(Colors.greenAccent),
                      SizedBox(width: 16),
                      // Title
                      Expanded(
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
                      SizedBox(width: 70), // Balance
                    ],
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

  Widget _trafficLight(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
