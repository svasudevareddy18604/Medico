import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../utils/app_colors.dart';
import '../../config/api.dart'; // adjust path to wherever your Api class lives

enum TermsAudience { both, careseekers, caretakers }

class AdminTermsConditionsScreen extends StatefulWidget {
  const AdminTermsConditionsScreen({super.key});

  @override
  State<AdminTermsConditionsScreen> createState() => _AdminTermsConditionsScreenState();
}

class _AdminTermsConditionsScreenState extends State<AdminTermsConditionsScreen> {
  TermsAudience _audience = TermsAudience.both;
  bool _sending = false;

  Future<void> _notifyUsers() async {
    final confirmed = await _confirmDialog();
    if (confirmed != true) return;

    setState(() => _sending = true);
    try {
      final res = await http.post(
        Uri.parse(Api.notifyTermsUpdate),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"audience": _audience.name}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _showSnack(
          "Notified ${data['totalUsers'] ?? ''} users • "
          "${data['emailSent'] ?? 0} emails, ${data['pushSent'] ?? 0} push sent",
        );
      } else {
        _showSnack("Failed to notify users (${res.statusCode}).", isError: true);
      }
    } catch (e) {
      _showSnack("Network error while sending notifications.", isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<bool?> _confirmDialog() {
    final audienceLabel = switch (_audience) {
      TermsAudience.both => "all careseekers and caretakers",
      TermsAudience.careseekers => "careseekers only",
      TermsAudience.caretakers => "caretakers only",
    };
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirm Notification", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          "This will send an email and in-app push notification to $audienceLabel, "
          "informing them that the Terms & Conditions have been updated. Continue?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Send Notification"),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      body: Column(
        children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _codeNote(),
                  const SizedBox(height: 22),
                  _sectionTitle("Notify Which Users?"),
                  const SizedBox(height: 10),
                  _audienceSelector(),
                  const SizedBox(height: 22),
                  _infoNote(),
                  const SizedBox(height: 24),
                  _sendButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: const BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Terms & Conditions",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 5),
                Text(
                  "Notify users of the latest update",
                  style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  Widget _codeNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.code_rounded, color: Colors.indigo.shade400, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Terms & Conditions content is managed directly in code. "
              "This screen only sends an update notification to users after you've "
              "deployed the change.",
              style: TextStyle(fontSize: 12, color: Colors.indigo.shade900, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _audienceSelector() {
    final options = [
      (TermsAudience.both, "All Users", "Careseekers + Caretakers", Icons.groups_rounded, Colors.indigo),
      (TermsAudience.careseekers, "Careseekers Only", "Only careseeker accounts", Icons.person_rounded, Colors.teal),
      (TermsAudience.caretakers, "Caretakers Only", "Only caretaker accounts", Icons.medical_services_rounded, Colors.orange),
    ];

    return Column(
      children: options.map((opt) {
        final (value, title, subtitle, icon, color) = opt;
        final selected = _audience == value;
        return GestureDetector(
          onTap: () => setState(() => _audience = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(0.10) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? color : Colors.grey.shade200, width: selected ? 1.6 : 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: selected ? color : Colors.grey.shade300,
                  size: 22,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _infoNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.amber.shade700, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "This immediately sends an email and push notification to the selected "
              "audience above. This action can't be undone once sent.",
              style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sendButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _sending ? null : _notifyUsers,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _sending
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
              )
            : const Text(
                "Notify Users of Update",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
      ),
    );
  }
}