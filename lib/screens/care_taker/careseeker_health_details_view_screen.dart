import 'package:flutter/material.dart';

class CareseekerHealthDetailsViewScreen extends StatefulWidget {
  final int userId;
  final int orderId;
  final int caretakerId;
  const CareseekerHealthDetailsViewScreen({
    super.key,
    required this.userId,
    required this.orderId,
    required this.caretakerId,
  });

  @override
  State<CareseekerHealthDetailsViewScreen> createState() =>
      _CareseekerHealthDetailsViewScreenState();
}

class _CareseekerHealthDetailsViewScreenState
    extends State<CareseekerHealthDetailsViewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Health Details")),
      body: Center(
        child: Text(
          "TODO: fetch /api/health-profile/${widget.userId} and render it here.",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}