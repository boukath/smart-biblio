import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/kiosk_provider.dart';

class SuccessReceiptView extends StatelessWidget {
  const SuccessReceiptView({super.key});

  @override
  Widget build(BuildContext context) {
    final kiosk = context.watch<KioskProvider>();
    final student = kiosk.currentStudent;
    final loans = kiosk.lastProcessedLoans;
    final isReturn = loans.isNotEmpty && loans.first.isReturned;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing Success Circle
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.success, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.success,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),

            Text(
              isReturn ? 'RETOURS EFFECTUÉS AVEC SUCCÈS !' : 'EMPRUNTS EFFECTUÉS AVEC SUCCÈS !',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isReturn
                  ? 'Votre retour a bien été enregistré. Merci !'
                  : 'Pensez à retourner vos livres avant la date d\'échéance.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),

            // Digital Receipt Card
            Container(
              width: 520,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Receipt Header
                  const Center(
                    child: Text(
                      'SMART BIBLIO • REÇU DE TRANSACTION',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      DateFormat('dd/MM/yyyy  •  HH:mm:ss').format(DateTime.now()),
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 12),

                  _buildReceiptRow('Emprunteur :', student?.fullName ?? 'N/D'),
                  _buildReceiptRow('N° Étudiant :', student?.studentNumber ?? 'N/D'),
                  _buildReceiptRow('Département :', student?.gradeDepartment ?? 'N/D'),
                  if (loans.isNotEmpty)
                    _buildReceiptRow('N° Transaction :', loans.first.transactionNo),

                  const SizedBox(height: 16),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 12),

                  const Text(
                    'ARTICLES TRAITÉS :',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),

                  ...loans.map((loan) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.bookmark_added_rounded,
                              size: 16, color: AppColors.success),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Exemplaire : ${loan.copyId}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            isReturn
                                ? 'RETOURNÉ'
                                : 'Retour avant le : ${DateFormat('dd/MM/yyyy').format(loan.dueAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isReturn ? AppColors.success : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 16),

                  const Center(
                    child: Text(
                      'Merci d\'utiliser la Borne Libre-Service Smart Biblio',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => kiosk.backToStudentHome(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('AUTRE TRANSACTION'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    side: const BorderSide(color: AppColors.borderLight),
                  ),
                ),
                const SizedBox(width: 20),
                FilledButton.icon(
                  onPressed: () => kiosk.exitSession(),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('TERMINER ET QUITTER'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
