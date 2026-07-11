import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-screen viewer for careseeker-uploaded documents.
///
/// Pass the full list of documents (as returned by
/// GET /documents/order/:orderId) and the index the user tapped.
/// Supports swiping between documents, pinch-to-zoom on images,
/// and a clean "Open PDF" action for PDF files.
class DocumentViewerScreen extends StatefulWidget {
  final List documents;
  final int initialIndex;

  const DocumentViewerScreen({
    super.key,
    required this.documents,
    this.initialIndex = 0,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _prettyKey(String key) {
    if (key.isEmpty) return "Document";
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : "${w[0].toUpperCase()}${w.substring(1)}")
        .join(' ');
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return "";
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final day = dt.day.toString().padLeft(2, '0');
      final month = months[dt.month - 1];
      var hour = dt.hour % 12;
      if (hour == 0) hour = 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return "$day $month ${dt.year} · $hour:$minute $period";
    } catch (_) {
      return "";
    }
  }

  Future<void> _openExternally(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open this document")),
      );
    }
  }

  bool _isPdf(Map doc) =>
      (doc['file_type'] ?? '').toString().toLowerCase() == 'pdf';

  @override
  Widget build(BuildContext context) {
    final total = widget.documents.length;
    final current = widget.documents[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _prettyKey(current['document_key']?.toString() ?? ''),
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            if (total > 1)
              Text(
                "Document ${_index + 1} of $total",
                style: const TextStyle(color: Colors.white54, fontSize: 11.5),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            tooltip: "Open in browser",
            onPressed: () => _openExternally(current['file_url']?.toString() ?? ''),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: total,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) {
          final doc = widget.documents[i];
          if (_isPdf(doc)) return _buildPdfCard(doc);
          return _buildImagePage(doc);
        },
      ),
      bottomNavigationBar: total > 1 ? _buildDots(total) : null,
    );
  }

  Widget _buildImagePage(Map doc) {
    final url = doc['file_url']?.toString() ?? '';
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 5,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2.5),
            );
          },
          errorBuilder: (_, __, ___) => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_rounded, color: Colors.white38, size: 56),
                SizedBox(height: 10),
                Text("Couldn't load image", style: TextStyle(color: Colors.white38)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfCard(Map doc) {
    final label = _prettyKey(doc['document_key']?.toString() ?? '');
    final uploadedAt = _formatDateTime(doc['uploaded_at']?.toString());
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: Colors.redAccent, size: 58),
          ),
          const SizedBox(height: 20),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            uploadedAt.isNotEmpty ? "PDF document · Uploaded $uploadedAt" : "PDF document",
            style: const TextStyle(color: Colors.white54, fontSize: 12.5),
          ),
          const SizedBox(height: 26),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: () => _openExternally(doc['file_url']?.toString() ?? ''),
            label: const Text("Open PDF", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDots(int total) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final active = i == _index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}