import 'package:flutter/material.dart';

/// A simple user stroke representing a continuous line.
class Stroke {
  final List<Offset> points;
  final Color color;
  final double width;

  Stroke({required this.points, this.color = Colors.black, this.width = 3.0});
}

/// A freestyle handwriting canvas letting the user draw with their finger.
class DrawingCanvas extends StatefulWidget {
  final double height;
  
  const DrawingCanvas({super.key, this.height = 200});

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  final List<Stroke> _strokes = [];
  Stroke? _currentStroke;

  void _startStroke(Offset position) {
    setState(() {
      _currentStroke = Stroke(points: [position]);
      _strokes.add(_currentStroke!);
    });
  }

  void _updateStroke(Offset position) {
    if (_currentStroke == null) return;
    setState(() {
      _currentStroke!.points.add(position);
    });
  }

  void _endStroke() {
    setState(() {
      _currentStroke = null;
    });
  }

  void _clearCanvas() {
    setState(() {
      _strokes.clear();
      _currentStroke = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Stack(
        children: [
          // The drawing area
          GestureDetector(
            onPanStart: (details) => _startStroke(details.localPosition),
            onPanUpdate: (details) => _updateStroke(details.localPosition),
            onPanEnd: (details) => _endStroke(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                size: Size.infinite,
                painter: _CanvasPainter(_strokes),
              ),
            ),
          ),
          
          // Clear Button
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              tooltip: 'Clear Canvas',
              onPressed: _clearCanvas,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                shadowColor: Colors.black26,
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final List<Stroke> strokes;

  _CanvasPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);

      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter oldDelegate) {
    return true; // We want it to repaint whenever strokes changes
  }
}
