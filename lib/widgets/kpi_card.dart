import 'package:flutter/material.dart';
import '../constants/colors.dart';

class KpiCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String value;
  final double valueFontSize;
  final String? sub1Text;
  final IconData? sub1Icon;
  final Color? sub1Color;
  final String? sub2Text;
  final IconData? sub2Icon;
  final Color? sub2Color;
  final Color accentColor;
  final bool hasProgress;
  final double progressValue;
  final Color? borderColor;

  const KpiCard({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    this.valueFontSize = 26,
    this.sub1Text,
    this.sub1Icon,
    this.sub1Color,
    this.sub2Text,
    this.sub2Icon,
    this.sub2Color,
    required this.accentColor,
    required this.hasProgress,
    this.progressValue = 0.0,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final leftBorderColor = borderColor ?? accentColor;
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 12.0 : 18.0;
    final titleSize = isMobile ? 11.0 : 13.0;
    final valueSize = isMobile
        ? (valueFontSize > 20 ? 20.0 : valueFontSize)
        : valueFontSize;
    final subSize = isMobile ? 10.0 : 12.0;
    final iconSize = isMobile ? 16.0 : 20.0;

    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: leftBorderColor, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title + icon ────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: kTextSub,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: accentColor, size: iconSize),
            ],
          ),

          SizedBox(height: isMobile ? 8 : 10),

          // ── Value ───────────────────────────────────────────────────────
          Text(
            value,
            style: TextStyle(
              fontSize: valueSize,
              fontWeight: FontWeight.w800,
              color: kTextMain,
            ),
            overflow: TextOverflow.ellipsis,
          ),

          SizedBox(height: isMobile ? 6 : 8),

          // ── Bottom ──────────────────────────────────────────────────────
          if (hasProgress)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 5,
                backgroundColor: const Color(0xFFE0E0E0),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            )
          else if (sub1Text != null || sub2Text != null)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (sub1Icon != null || sub1Text != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sub1Icon != null)
                        Icon(sub1Icon, color: sub1Color, size: subSize),
                      if (sub1Icon != null) const SizedBox(width: 3),
                      if (sub1Text != null)
                        Text(
                          sub1Text!,
                          style: TextStyle(
                            color: sub1Color ?? kTextSub,
                            fontSize: subSize,
                          ),
                        ),
                    ],
                  ),
                if (sub2Text != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sub2Icon != null)
                        Icon(sub2Icon, color: sub2Color, size: subSize),
                      if (sub2Icon != null) const SizedBox(width: 3),
                      Text(
                        sub2Text!,
                        style: TextStyle(
                          color: sub2Color ?? kTextSub,
                          fontSize: subSize,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
