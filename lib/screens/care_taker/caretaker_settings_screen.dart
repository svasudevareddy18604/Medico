import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'help_support_screen.dart';
import 'about_app_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';
import 'caretaker_profile_screen.dart';
import 'payment_details_screen.dart';
import 'live_chat_screen.dart';
import 'ratings_reviews_screen.dart';
import 'emergency_sos_screen.dart';

import '../../login_page.dart';

import 'package:medico/utils/app_colors.dart';

class CareTakerSettingsScreen extends StatelessWidget {
  final int userId;

  const CareTakerSettingsScreen({
    super.key,
    required this.userId,
  });

  /* =========================================================
     LOGOUT
  ========================================================= */

  Future<void> _logout(BuildContext ctx) async {
    await (await SharedPreferences.getInstance())
        .clear();

    if (!ctx.mounted) return;

    Navigator.pushAndRemoveUntil(
      ctx,

      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),

      (_) => false,
    );
  }

  void _confirmLogout(BuildContext ctx) {
    showDialog(
      context: ctx,

      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),

        title: const Text("Logout"),

        content: const Text(
          "You will be logged out. Continue?",
        ),

        actions: [

          // CANCEL

          TextButton(
            onPressed: () => Navigator.pop(ctx),

            child: Text(
              "Cancel",

              style: TextStyle(
                color: AppColors.muted,
              ),
            ),
          ),

          // LOGOUT

          DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.gradient,

              borderRadius:
                  BorderRadius.circular(8),
            ),

            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.transparent,

                shadowColor:
                    Colors.transparent,

                foregroundColor: Colors.white,

                elevation: 0,
              ),

              onPressed: () {
                Navigator.pop(ctx);
                _logout(ctx);
              },

              child: const Text("Logout"),
            ),
          ),
        ],
      ),
    );
  }

  /* =========================================================
     NAVIGATION
  ========================================================= */

  void _go(BuildContext ctx, Widget screen) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => screen,
      ),
    );
  }

  /* =========================================================
     TILE
  ========================================================= */

  Widget _tile(
    BuildContext ctx, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,

    Color? overrideIconBg,
    Color? overrideIconColor,

    bool useGradient = true,
  }) {
    final isDark =
        Theme.of(ctx).brightness ==
            Brightness.dark;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 2,
      ),

      leading: Container(
        width: 42,
        height: 42,

        decoration: BoxDecoration(
          gradient:
              useGradient
                  ? AppColors.gradient
                  : null,

          color:
              useGradient
                  ? null
                  : (overrideIconBg ??
                      AppColors.primary
                          .withOpacity(0.12)),

          borderRadius:
              BorderRadius.circular(12),

          boxShadow:
              useGradient
                  ? AppColors.glowShadow
                  : [],
        ),

        child: Icon(
          icon,

          color:
              useGradient
                  ? Colors.white
                  : (overrideIconColor ??
                      AppColors.primary),

          size: 20,
        ),
      ),

      title: Text(
        title,

        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,

          color:
              isDark
                  ? Colors.white
                  : Colors.black87,
        ),
      ),

      trailing: Icon(
        Icons.arrow_forward_ios_rounded,

        size: 14,

        color:
            isDark
                ? Colors.white38
                : AppColors.muted,
      ),

      onTap: onTap,
    );
  }

  /* =========================================================
     SECTION
  ========================================================= */

  Widget _section(
    BuildContext ctx,
    String label,
    List<Widget> tiles,
  ) {
    final isDark =
        Theme.of(ctx).brightness ==
            Brightness.dark;

    return Container(
      margin:
          const EdgeInsets.only(bottom: 18),

      decoration: BoxDecoration(
        color:
            isDark
                ? const Color(0xFF1C1C1E)
                : AppColors.cardBg,

        borderRadius:
            BorderRadius.circular(20),

        border: Border.all(
          color:
              isDark
                  ? Colors.white12
                  : AppColors.border,
        ),

        boxShadow:
            isDark
                ? []
                : AppColors.cardShadow,
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          // SECTION TITLE

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              14,
              16,
              10,
            ),

            child: ShaderMask(
              shaderCallback:
                  (b) => AppColors.gradient
                      .createShader(b),

              child: Text(
                label,

                style: const TextStyle(
                  color: Colors.white,

                  fontWeight:
                      FontWeight.bold,

                  fontSize: 11,

                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),

          Divider(
            height: 1,
            color:
                isDark
                    ? Colors.white12
                    : AppColors.border,
          ),

          ...tiles.expand(
            (t) => [

              t,

              if (t != tiles.last)
                Divider(
                  height: 1,

                  indent: 14,
                  endIndent: 14,

                  color:
                      isDark
                          ? Colors.white
                              .withOpacity(0.06)
                          : AppColors.border,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /* =========================================================
     BUILD
  ========================================================= */

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        20,
        16,
        30,
      ),

      children: [

        /* ===================================================
           PROFILE HEADER
        =================================================== */

        Container(
          padding: const EdgeInsets.all(18),

          decoration: BoxDecoration(
            gradient: AppColors.gradient,

            borderRadius:
                BorderRadius.circular(24),

            boxShadow:
                AppColors.glowShadow,
          ),

          child: Row(
            children: [

              // PROFILE IMAGE

              Container(
                width: 68,
                height: 68,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  border: Border.all(
                    color: Colors.white,
                    width: 2.5,
                  ),

                  color: Colors.white
                      .withOpacity(0.18),
                ),

                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),

              const SizedBox(width: 16),

              // TEXTS

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    const Text(
                      "Caretaker",

                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.white
                            .withOpacity(0.18),

                        borderRadius:
                            BorderRadius.circular(
                                20),
                      ),

                      child: const Text(
                        "Professional Caregiver",

                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,

                          fontWeight:
                              FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // EDIT BUTTON

              GestureDetector(
                onTap: () => _go(
                  context,
                  CareTakerProfileScreen(
                    userId: userId,
                  ),
                ),

                child: Container(
                  width: 34,
                  height: 34,

                  decoration: BoxDecoration(
                    color: Colors.white
                        .withOpacity(0.18),

                    shape: BoxShape.circle,
                  ),

                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        /* ===================================================
           ACCOUNT
        =================================================== */

        _section(
          context,
          "ACCOUNT",

          [

            _tile(
              context,

              icon: Icons.person_rounded,

              title: "Profile",

              onTap: () => _go(
                context,

                CareTakerProfileScreen(
                  userId: userId,
                ),
              ),
            ),

            _tile(
              context,

              icon:
                  Icons
                      .account_balance_wallet_rounded,

              title: "Payment Details",

              onTap: () => _go(
                context,

                PaymentDetailsScreen(
                  userId: userId,
                ),
              ),
            ),

            _tile(
              context,

              icon: Icons.verified_rounded,

              title:
                  "Documents & Verification",

              onTap: () {},
            ),

            _tile(
              context,

              icon:
                  Icons.account_balance_rounded,

              title: "Bank Account",

              onTap: () {},
            ),
          ],
        ),

        /* ===================================================
           CARETAKER
        =================================================== */

        _section(
          context,
          "CARETAKER",

          [

            _tile(
              context,

              icon:
                  Icons.calendar_month_rounded,

              title: "My Bookings",

              onTap: () {},
            ),

            _tile(
              context,

              icon: Icons.schedule_rounded,

              title:
                  "Availability Schedule",

              onTap: () {},
            ),

            _tile(
              context,

              icon: Icons.payments_rounded,

              title:
                  "Earnings & Payments",

              onTap: () {},
            ),

            _tile(
              context,

              icon: Icons.star_rounded,

              title: "Ratings & Reviews",

              onTap: () => _go(
                context,

                RatingsReviewsScreen(
                  userId: userId,
                ),
              ),
            ),

            _tile(
              context,

              icon: Icons.insights_rounded,

              title:
                  "Performance Analytics",

              onTap: () {},
            ),

            _tile(
              context,

              icon:
                  Icons.medical_services_rounded,

              title: "Services Offered",

              onTap: () {},
            ),
          ],
        ),

        /* ===================================================
           SUPPORT
        =================================================== */

        _section(
          context,
          "SUPPORT",

          [

            // LIVE CHAT

            _tile(
              context,

              icon:
                  Icons.chat_bubble_rounded,

              title: "Live Chat",

              onTap: () => _go(
                context,
                const LiveChatScreen(),
              ),
            ),

            // HELP CENTER

            _tile(
              context,

              icon: Icons.help_rounded,

              title: "Help & Support",

              onTap: () => _go(
                context,
                const HelpCenterScreen(),
              ),
            ),

            // EMERGENCY SOS

            _tile(
              context,

              icon: Icons.sos_rounded,

              title: "Emergency SOS",

              onTap: () => _go(
                context,
                const EmergencySOSScreen(),
              ),

              useGradient: false,

              overrideIconBg:
                  AppColors.danger
                      .withOpacity(0.12),

              overrideIconColor:
                  AppColors.danger,
            ),

            // ABOUT APP

            _tile(
              context,

              icon: Icons.info_rounded,

              title: "About App",

              onTap: () => _go(
                context,
                const AboutAppScreen(),
              ),
            ),
          ],
        ),

        /* ===================================================
           LEGAL
        =================================================== */

        _section(
          context,
          "LEGAL",

          [

            _tile(
              context,

              icon:
                  Icons.privacy_tip_rounded,

              title: "Privacy Policy",

              onTap: () => _go(
                context,
                const PrivacyScreen(),
              ),
            ),

            _tile(
              context,

              icon:
                  Icons.description_rounded,

              title:
                  "Terms & Conditions",

              onTap: () => _go(
                context,
                const TermsConditionsScreen(),
              ),
            ),
          ],
        ),

        /* ===================================================
           LOGOUT
        =================================================== */

        Container(
          decoration: BoxDecoration(
            color: AppColors.danger
                .withOpacity(
                    isDark ? 0.10 : 0.06),

            borderRadius:
                BorderRadius.circular(20),

            border: Border.all(
              color: AppColors.danger
                  .withOpacity(0.18),
            ),
          ),

          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 2,
            ),

            leading: Container(
              width: 40,
              height: 40,

              decoration: BoxDecoration(
                color: AppColors.danger
                    .withOpacity(0.12),

                borderRadius:
                    BorderRadius.circular(
                        12),
              ),

              child: Icon(
                Icons.logout_rounded,
                color: AppColors.danger,
                size: 20,
              ),
            ),

            title: Text(
              "Logout",

              style: TextStyle(
                color: AppColors.danger,

                fontWeight:
                    FontWeight.bold,

                fontSize: 14,
              ),
            ),

            trailing: Icon(
              Icons.arrow_forward_ios_rounded,

              size: 14,

              color: AppColors.danger
                  .withOpacity(0.5),
            ),

            onTap: () =>
                _confirmLogout(context),
          ),
        ),
      ],
    );
  }
}