import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/kiosk_provider.dart';

class BorrowScanningView extends StatelessWidget {
  const BorrowScanningView({super.key});

  @override
  Widget build(BuildContext context) {
    final kiosk = context.watch<KioskProvider>();
    final student = kiosk.currentStudent;
    final items = kiosk.borrowItems;
    final validCount = kiosk.validBorrowCount;

    // Expected return date = 14 days from now
    final expectedDue = DateTime.now().add(const Duration(days: 14));

    return Column(
      children: [
        // View Top Navigation Bar
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
                label: const Text('RETOUR'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderLight),
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EMPRUNT DE LIVRES',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Emprunteur : ${student?.fullName ?? ''} (${student?.studentNumber ?? ''})',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const Spacer(),
              // Real-time Scanned Count Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sensors_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${items.length} détecté(s) ($validCount prêt(s))',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
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
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Déposez vos livres RFID sur le plateau de lecture',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Vous pouvez poser plusieurs livres en même temps.\nLe système identifie automatiquement chaque exemplaire.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          // Scanned Books List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(32),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final item = items[index];
                final book = item.book;
                final copy = item.copy;

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: item.isValid
                          ? AppColors.success.withValues(alpha: 0.4)
                          : AppColors.danger.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Status Icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: item.isValid
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.danger.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.isValid ? Icons.check_circle_rounded : Icons.error_rounded,
                          color: item.isValid ? AppColors.success : AppColors.danger,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Book details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book?.title ?? 'Livre inconnu (${item.epc})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (book != null)
                              Text(
                                'Auteur : ${book.author}  •  ISBN : ${book.isbn}',
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              'Code-barres : ${copy?.copyBarcode ?? 'N/D'}  •  EPC : ${item.epc}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Validation Status Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: item.isValid
                              ? AppColors.success.withValues(alpha: 0.12)
                              : AppColors.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: item.isValid ? AppColors.success : AppColors.danger,
                          ),
                        ),
                        child: Text(
                          item.reason,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: item.isValid ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        // Bottom Confirmation Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              // Loan details summary
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date d\'échéance du retour : ${DateFormat('dd/MM/yyyy').format(expectedDue)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Durée standard du prêt : 14 jours',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => kiosk.backToStudentHome(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  side: const BorderSide(color: AppColors.borderLight),
                ),
                child: const Text('ANNULER', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: validCount > 0 && !kiosk.isProcessing
                    ? () => kiosk.confirmBorrow()
                    : null,
                icon: kiosk.isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, size: 20),
                label: Text(
                  validCount > 0 ? 'VALIDER L\'EMPRUNT ($validCount LIVRES)' : 'AUCUN LIVRE VALIDE',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
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
