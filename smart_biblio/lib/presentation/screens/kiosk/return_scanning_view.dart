import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/kiosk_provider.dart';

class ReturnScanningView extends StatelessWidget {
  const ReturnScanningView({super.key});

  @override
  Widget build(BuildContext context) {
    final kiosk = context.watch<KioskProvider>();
    final items = kiosk.returnItems;
    final validCount = kiosk.validReturnCount;
    final totalFines = kiosk.pendingFinesOnReturn;

    return Column(
      children: [
        // Navigation & Status Top Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => kiosk.backToStudentHome(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('BACK'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderLight),
                ),
              ),
              const SizedBox(width: 20),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RETURN BOOKS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Place the books you wish to return on the RFID antenna pad',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sensors_rounded, color: AppColors.secondary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${items.length} Books Detected ($validCount Ready)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Live Scanning Instructions / Empty State
        if (items.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(
                      Icons.assignment_return_rounded,
                      size: 48,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Place returned books near the RFID reader',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'The reader will identify your active loan and verify return status automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          // Scanned Items List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(32),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final item = items[index];
                final book = item.book;
                final copy = item.copy;

                Color badgeColor = AppColors.success;
                if (!item.isValid) {
                  badgeColor = AppColors.danger;
                } else if (item.isOverdue) {
                  badgeColor = AppColors.warning;
                }

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.isValid
                              ? (item.isOverdue ? Icons.warning_amber_rounded : Icons.check_circle_rounded)
                              : Icons.error_rounded,
                          color: badgeColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 20),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book?.title ?? 'Unknown Item (${item.epc})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (book != null)
                              Text(
                                'Author: ${book.author}',
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              'Copy: ${copy?.copyBarcode ?? 'N/A'}  •  EPC: ${item.epc}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: badgeColor),
                            ),
                            child: Text(
                              item.reason,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                          ),
                          if (item.isOverdue && item.fineAmount > 0) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Fine: ${item.fineAmount.toStringAsFixed(0)} DZD',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        // Bottom Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              if (totalFines > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Total Overdue Fine: ${totalFines.toStringAsFixed(0)} DZD',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Text(
                  'No overdue fines assessed.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => kiosk.backToStudentHome(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  side: const BorderSide(color: AppColors.borderLight),
                ),
                child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: validCount > 0 && !kiosk.isProcessing
                    ? () => kiosk.confirmReturn()
                    : null,
                icon: kiosk.isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, size: 20),
                label: Text(
                  validCount > 0 ? 'CONFIRM RETURN ($validCount BOOKS)' : 'NO VALID BOOKS',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
