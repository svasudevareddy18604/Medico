/// 🔥 Predefined rejection reasons.
/// `allowReuploadDefault` decides whether the RejectedScreen shows
/// the "Re-upload Documents" button for this reason.
/// For "Other", the admin manually toggles it in the dialog.
class RejectionReason {
  final String label;
  final String description;
  final bool allowReuploadDefault;
  final bool isOther;

  const RejectionReason({
    required this.label,
    required this.description,
    required this.allowReuploadDefault,
    this.isOther = false,
  });
}

const List<RejectionReason> kRejectionReasons = [
  RejectionReason(
    label: "Incomplete Profile",
    description: "Missing required information or documents.",
    allowReuploadDefault: true,
  ),
  RejectionReason(
    label: "Invalid or Unverified Identity",
    description: "ID proof is invalid, expired, or cannot be verified.",
    allowReuploadDefault: true,
  ),
  RejectionReason(
    label: "Invalid Professional Qualification",
    description: "Required certificates, licenses, or training are missing or invalid.",
    allowReuploadDefault: true,
  ),
  RejectionReason(
    label: "Failed Background Verification",
    description: "Criminal background check or reference verification fails.",
    allowReuploadDefault: false,
  ),
  RejectionReason(
    label: "Insufficient Experience",
    description: "Does not meet the minimum experience requirement.",
    allowReuploadDefault: false,
  ),
  RejectionReason(
    label: "Failed Interview or Skill Assessment",
    description: "Does not meet the platform's quality or competency standards.",
    allowReuploadDefault: false,
  ),
  RejectionReason(
    label: "Other / Not Eligible",
    description: "Any other reason that doesn't fit the above categories.",
    allowReuploadDefault: false,
    isOther: true,
  ),
];