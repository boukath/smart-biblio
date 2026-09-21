import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../providers/kiosk_provider.dart';

class SimulatedActionsDock extends StatefulWidget {
  const SimulatedActionsDock({super.key});

  @override
  State<SimulatedActionsDock> createState() => _SimulatedActionsDockState();
}

class _SimulatedActionsDockState extends State<SimulatedActionsDock> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final kiosk = context.watch<KioskProvider>();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withValues(alpha: 0.95),
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar / Collapse Toggle
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: AppColors.surface,
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'VIRTUAL RFID HARDWARE SIMULATOR & TEST HARNESS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    kiosk.rfid.isSimulated ? '(Simulated Mode Active)' : '(Hardware Mode Active)',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Mode Toggle Button
                  OutlinedButton.icon(
                    onPressed: () {
                      kiosk.rfid.setSimulationMode(!kiosk.rfid.isSimulated);
                    },
                    icon: Icon(
                      kiosk.rfid.isSimulated ? Icons.memory_rounded : Icons.usb_rounded,
                      size: 14,
                    ),
                    label: Text(
                      kiosk.rfid.isSimulated ? 'Use Native DLL' : 'Use Simulator',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderLight),
                    ),
                  ),

                  const SizedBox(
                    height: 24,
                    child: VerticalDivider(color: AppColors.border),
                  ),

                  // Student Card Simulation
                  const Text(
                    'Simulate Card Tap:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),

                  _SimButton(
                    label: 'Ahmed (STU-001)',
                    icon: Icons.person_rounded,
                    color: AppColors.primary,
                    onPressed: () {
                      kiosk.handleCardTapped('E28068940000501234567890');
                    },
                  ),

                  _SimButton(
                    label: 'Sarah (STU-002)',
                    icon: Icons.person_rounded,
                    color: AppColors.secondary,
                    onPressed: () {
                      kiosk.handleCardTapped('CARD00000000000000000002');
                    },
                  ),

                  _SimButton(
                    label: 'Yasmine (Suspended)',
                    icon: Icons.person_off_rounded,
                    color: AppColors.warning,
                    onPressed: () {
                      kiosk.handleCardTapped('CARD00000000000000000004');
                    },
                  ),

                  const SizedBox(
                    height: 24,
                    child: VerticalDivider(color: AppColors.border),
                  ),

                  // Book Tag Simulation
                  const Text(
                    'Simulate Book Scan:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),

                  _SimButton(
                    label: 'Place 2 Available Books',
                    icon: Icons.menu_book_rounded,
                    color: AppColors.success,
                    onPressed: () {
                      final epcs = [
                        'E28068940000000000000002', // Clean Code Copy 2
                        'E28068940000000000000003', // Database Systems Copy 1
                      ];
                      kiosk.rfid.simulateTagScan(epcs);
                    },
                  ),

                  _SimButton(
                    label: "Place Ahmed's Book (Return)",
                    icon: Icons.assignment_return_rounded,
                    color: AppColors.primary,
                    onPressed: () {
                      kiosk.rfid.simulateTagScan(['E28068940000000000000001']);
                    },
                  ),

                  _SimButton(
                    label: 'Place Unknown Tag',
                    icon: Icons.help_outline_rounded,
                    color: AppColors.danger,
                    onPressed: () {
                      kiosk.rfid.simulateTagScan(['UNKNOWN_TAG_999999']);
                    },
                  ),

                  _SimButton(
                    label: 'Remove All Books',
                    icon: Icons.clear_all_rounded,
                    color: AppColors.textMuted,
                    onPressed: () {
                      kiosk.rfid.simulateClearTags();
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SimButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _SimButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14, color: color),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      ),
    );
  }
}
