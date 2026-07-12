import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api.dart';
import '../../utils/app_colors.dart';
import '../../models/rejection_reason.dart';

/// 🔥 Call this from wherever your "Reject" button lives
/// (e.g. admin_caregiver_details.dart):
///
/// final done = await showRejectCaregiverDialog(context, userId: caregiver["id"]);
/// if (done == true) fetchCaregivers(); // refresh
Future<bool?> showRejectCaregiverDialog(BuildContext context, {required int userId}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RejectCaregiverDialog(userId: userId),
  );
}

class RejectCaregiverDialog extends StatefulWidget {
  final int userId;
  const RejectCaregiverDialog({super.key, required this.userId});

  @override
  State<RejectCaregiverDialog> createState() => _RejectCaregiverDialogState();
}

class _RejectCaregiverDialogState extends State<RejectCaregiverDialog> {
  RejectionReason? _selected;
  bool _allowReuploadOverride = false; // used only when "Other" is selected
  final TextEditingController _otherText = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _otherText.dispose();
    super.dispose();
  }

  bool get _isOtherSelected => _selected?.isOther == true;

  bool get _effectiveAllowReupload =>
      _isOtherSelected ? _allowReuploadOverride : (_selected?.allowReuploadDefault ?? false);

  String? get _finalReason {
    if (_selected == null) return null;
    if (_isOtherSelected) {
      final remark = _otherText.text.trim();
      if (remark.isEmpty) return null;
      return "Other: $remark";
    }
    return _selected!.label;
  }

  Future<void> _submit() async {
    final reason = _finalReason;
    if (reason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selected == null
                ? "Please select a rejection reason"
                : "Please enter a remark for 'Other'",
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final res = await http.post(
        Uri.parse("${Api.adminCaregivers}/reject/${widget.userId}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "reason": reason,
          "allow_reupload": _effectiveAllowReupload ? 1 : 0,
        }),
      );

      if (res.statusCode == 200) {
        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to reject caregiver")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Server error")),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: const BoxDecoration(
                gradient: AppColors.headerGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.block_flipped, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "Reject Caregiver",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),

            // ── Reason list ──
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                itemCount: kRejectionReasons.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final r = kRejectionReasons[i];
                  final selected = _selected == r;
                  return _reasonTile(r, selected);
                },
              ),
            ),

            // ── "Other" remark + toggle ──
            if (_isOtherSelected)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Column(
                  children: [
                    TextField(
                      controller: _otherText,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: "Enter admin remark...",
                        filled: true,
                        fillColor: AppColors.lightBg,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _allowReuploadOverride,
                      onChanged: (v) => setState(() => _allowReuploadOverride = v),
                      activeColor: AppColors.primary,
                      title: const Text(
                        "Allow document re-upload",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        "Caregiver can fix & re-submit documents",
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Actions ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Reject",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reasonTile(RejectionReason r, bool selected) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _selected = r),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.08) : AppColors.lightBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? AppColors.primary : AppColors.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.primary : AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.description,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                  if (!r.isOther) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (r.allowReuploadDefault ? AppColors.secondary : AppColors.danger)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        r.allowReuploadDefault ? "Re-upload allowed" : "No re-upload",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: r.allowReuploadDefault ? AppColors.secondary : AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}