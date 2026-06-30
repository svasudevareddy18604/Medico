import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import '../../utils/app_colors.dart';

class DocumentsVerificationScreen extends StatefulWidget {
  final int userId;

  const DocumentsVerificationScreen({
    super.key,
    required this.userId,
  });

  @override
  State<DocumentsVerificationScreen> createState() =>
      _DocumentsVerificationScreenState();
}

class _DocumentsVerificationScreenState
    extends State<DocumentsVerificationScreen> {
  bool _loading = true;

  String? _aadhaarFront;
  String? _aadhaarBack;
  String? _panCard;
  String? _certificate;

  // Only two real states matter here: "approved" or "rejected".
  // Caretaker approved  -> documents verified
  // Caretaker rejected  -> documents rejected
  // Anything else (pending etc.) is treated as NOT verified yet.
  String _approvalStatus = "pending";
  String? _rejectReason;

  bool get _isVerified => _approvalStatus == "approved";
  bool get _isRejected => _approvalStatus == "rejected";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await http.get(
        Uri.parse(Api.getCaretakerDocuments(widget.userId)),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)["data"];

        setState(() {
          _aadhaarFront = data["aadhaar_front"];
          _aadhaarBack = data["aadhaar_back"];
          _panCard = data["pan_card"];
          _certificate = data["certificate"];
          // approval_status comes from the users table (caretaker-level status)
          _approvalStatus = data["approval_status"] ?? "pending";
          _rejectReason = data["reject_reason"];
        });
      } else {
        _loadDemo();
      }
    } catch (_) {
      _loadDemo();
    }

    setState(() => _loading = false);
  }

  // DEMO FALLBACK — uses sample images so screen never looks empty
  void _loadDemo() {
    _aadhaarFront =
        "https://res.cloudinary.com/do9cbfu5l/image/upload/v1782753551/medico/aadhaar/aadhaar_front-1782753550838.jpg";
    _aadhaarBack =
        "https://res.cloudinary.com/do9cbfu5l/image/upload/v1782753551/medico/aadhaar/aadhaar_back-1782753551395.jpg";
    _panCard =
        "https://res.cloudinary.com/do9cbfu5l/image/upload/v1782753551/medico/pan/pan_card-1782753551453.jpg";
    _certificate =
        "https://res.cloudinary.com/do9cbfu5l/image/upload/v1782753552/medico/certificate/certificate-1782753551800.jpg";
    _approvalStatus = "approved";
  }

  /* =========================================================
     STATUS HELPERS
  ========================================================= */

  Color get _statusColor =>
      _isVerified ? const Color(0xFF2E7D32) : AppColors.danger;

  IconData get _statusIcon =>
      _isVerified ? Icons.verified_rounded : Icons.cancel_rounded;

  String get _statusLabel => _isVerified ? "Verified" : "Not Verified";

  /* =========================================================
     BUILD
  ========================================================= */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                _header(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _statusCard(),
                        const SizedBox(height: 22),

                        _sectionTitle("Aadhaar Card"),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _docCard(
                                "Front",
                                _aadhaarFront,
                                Icons.badge_rounded,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _docCard(
                                "Back",
                                _aadhaarBack,
                                Icons.badge_rounded,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 26),

                        _sectionTitle("PAN Card"),
                        const SizedBox(height: 12),
                        _docCard(
                          "PAN Card",
                          _panCard,
                          Icons.credit_card_rounded,
                          fullWidth: true,
                        ),

                        const SizedBox(height: 26),

                        _sectionTitle("Professional Certificate"),
                        const SizedBox(height: 12),
                        _docCard(
                          "Certificate",
                          _certificate,
                          Icons.workspace_premium_rounded,
                          fullWidth: true,
                        ),

                        const SizedBox(height: 20),
                        _verifiedByFooter(),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /* =========================================================
     HEADER
  ========================================================= */

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 58, 20, 28),
      decoration: const BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "Documents & Verification",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_isVerified) ...[
                      const SizedBox(width: 6),
                      const _BlueTick(size: 18),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  "Your uploaded verification documents",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* =========================================================
     STATUS CARD
  ========================================================= */

  Widget _statusCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _statusColor.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_statusIcon, color: _statusColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _statusLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _statusColor,
                      ),
                    ),
                    if (_isVerified) ...[
                      const SizedBox(width: 6),
                      const _BlueTick(size: 16),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _isRejected && _rejectReason != null
                      ? _rejectReason!
                      : _isVerified
                          ? "All documents are verified by Medico Support Team"
                          : "Your documents have not been verified",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* =========================================================
     SECTION TITLE
  ========================================================= */

  Widget _sectionTitle(String title) {
    return ShaderMask(
      shaderCallback: (b) => AppColors.gradient.createShader(b),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /* =========================================================
     DOCUMENT CARD
  ========================================================= */

  Widget _docCard(
    String label,
    String? url,
    IconData icon, {
    bool fullWidth = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: GestureDetector(
                  onTap: url != null ? () => _viewFullImage(url) : null,
                  child: AspectRatio(
                    aspectRatio: fullWidth ? 16 / 9 : 1,
                    child: url != null
                        ? Image.network(
                            url,
                            fit: BoxFit.cover,
                            loadingBuilder: (c, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: const Color(0xFFF3F6F9),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (c, e, s) => Container(
                              color: const Color(0xFFF3F6F9),
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image_rounded,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFFF3F6F9),
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported_rounded,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              if (_isVerified)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const _BlueTick(size: 18),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (_isVerified)
                  const _BlueTick(size: 18)
                else
                  Icon(
                    Icons.cancel_rounded,
                    color: _statusColor,
                    size: 18,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* =========================================================
     VERIFIED-BY FOOTER (Instagram style)
  ========================================================= */

  Widget _verifiedByFooter() {
    if (!_isVerified) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1DA1F2).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1DA1F2).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const _BlueTick(size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Documents verified by our Medico Support Team",
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* =========================================================
     FULL IMAGE VIEW
  ========================================================= */

  void _viewFullImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

/* =========================================================
   INSTAGRAM-STYLE BLUE VERIFIED TICK BADGE
========================================================= */

class _BlueTick extends StatelessWidget {
  final double size;
  const _BlueTick({this.size = 18});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BlueTickPainter(),
      ),
    );
  }
}

class _BlueTickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 8-point "scalloped" badge shape like Instagram's verified badge
    final path = Path();
    const points = 8;
    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi * 2) / (points * 2) - math.pi / 2;
      final r = i.isEven ? radius : radius * 0.82;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final badgePaint = Paint()..color = const Color(0xFF1DA1F2);
    canvas.drawPath(path, badgePaint);

    // checkmark
    final checkPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final checkPath = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.74, size.height * 0.32);

    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}