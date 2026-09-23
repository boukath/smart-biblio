import 'package:flutter/material.dart';

/// Supported application languages
enum AppLanguage { french, english }

class LocaleProvider extends ChangeNotifier {
  String _currentLanguage = 'fr'; // French default as requested

  String get currentLanguage => _currentLanguage;
  bool get isFrench => _currentLanguage == 'fr';
  bool get isEnglish => _currentLanguage == 'en';

  void setLanguage(String lang) {
    if (_currentLanguage != lang && (lang == 'fr' || lang == 'en')) {
      _currentLanguage = lang;
      notifyListeners();
    }
  }

  void toggleLanguage() {
    setLanguage(isFrench ? 'en' : 'fr');
  }

  /// Translation lookup helper
  String t(String key) {
    final map = _translations[key];
    if (map == null) return key;
    return map[_currentLanguage] ?? map['fr'] ?? key;
  }

  static const Map<String, Map<String, String>> _translations = {
    // === TOP BAR & HEADER ===
    'app_title': {
      'fr': 'SMART BIBLIO',
      'en': 'SMART BIBLIO',
    },
    'kiosk_subtitle': {
      'fr': 'Borne Libre-Service RFID Intelligente',
      'en': 'Intelligent RFID Self-Service Kiosk',
    },
    'rfid_connected': {
      'fr': 'Lecteur RFID Connecté',
      'en': 'RFID Reader Connected',
    },
    'rfid_disconnected': {
      'fr': 'Lecteur RFID Déconnecté',
      'en': 'RFID Reader Disconnected',
    },
    'exit_session': {
      'fr': 'TERMINER / QUITTER',
      'en': 'FINISH / EXIT',
    },
    'admin_access_tooltip': {
      'fr': 'Accès Administration (Ctrl+Maj+A)',
      'en': 'Admin Access (Ctrl+Shift+A)',
    },

    // === IDLE / WELCOME SCREEN ===
    'kiosk_badge': {
      'fr': 'BORNE SANS CONTACT SMART BIBLIO',
      'en': 'SMART BIBLIO CONTACTLESS KIOSK',
    },
    'welcome_title': {
      'fr': 'Bienvenue à la Bibliothèque',
      'en': 'Welcome to the Library',
    },
    'welcome_subtitle': {
      'fr': 'Veuillez approcher ou poser votre carte RFID sur le lecteur pour commencer.',
      'en': 'Please scan or place your RFID card on the reader to get started.',
    },
    'radar_scan_card': {
      'fr': 'APPROCHEZ VOTRE CARTE',
      'en': 'SCAN YOUR RFID CARD',
    },
    'step1': {
      'fr': 'Posez votre carte',
      'en': 'Scan your card',
    },
    'step2': {
      'fr': 'Emprunter ou Retourner',
      'en': 'Borrow or Return',
    },
    'step3': {
      'fr': 'Déposez les livres RFID',
      'en': 'Place RFID books',
    },
    'lang_switch_tooltip': {
      'fr': 'Changer la langue (Français / English)',
      'en': 'Switch Language (French / English)',
    },

    // === STUDENT HOME ===
    'student_greeting': {
      'fr': 'Bonjour',
      'en': 'Welcome',
    },
    'student_status_active': {
      'fr': 'CARTE ACTIVE',
      'en': 'ACTIVE CARD',
    },
    'student_status_suspended': {
      'fr': 'COMPTE SUSPENDU',
      'en': 'SUSPENDED ACCOUNT',
    },
    'borrow_action_title': {
      'fr': 'Emprunter des livres',
      'en': 'Borrow Books',
    },
    'borrow_action_subtitle': {
      'fr': 'Placez vos nouveaux livres sur le plateau RFID',
      'en': 'Place your new books on the RFID scanner',
    },
    'return_action_title': {
      'fr': 'Retourner des livres',
      'en': 'Return Books',
    },
    'return_action_subtitle': {
      'fr': 'Déposez vos livres empruntés pour les restituer',
      'en': 'Place your borrowed books to return them',
    },
    'current_loans_title': {
      'fr': 'Vos Emprunts Actuels',
      'en': 'Your Current Loans',
    },
    'no_current_loans': {
      'fr': 'Aucun livre emprunté pour le moment',
      'en': 'No books currently borrowed',
    },
    'max_allowed': {
      'fr': 'Limite autorisée',
      'en': 'Max allowed',
    },
    'fines_due': {
      'fr': 'Amendes dues',
      'en': 'Pending fines',
    },

    // === ADMIN NAVIGATION ===
    'admin_center': {
      'fr': 'CENTRE ADMIN',
      'en': 'ADMIN CENTER',
    },
    'admin_subtitle': {
      'fr': 'Gestion Smart Biblio',
      'en': 'Smart Biblio Backoffice',
    },
    'nav_dashboard': {
      'fr': 'Tableau de bord',
      'en': 'Dashboard',
    },
    'nav_catalog': {
      'fr': 'Catalogue & RFID',
      'en': 'Catalog & RFID',
    },
    'nav_students': {
      'fr': 'Étudiants & Cartes',
      'en': 'Students & Cards',
    },
    'nav_circulation': {
      'fr': 'Circulation & Retards',
      'en': 'Circulation & Fines',
    },
    'nav_rfid_center': {
      'fr': 'Centre RFID & Audit',
      'en': 'RFID Center & Audit',
    },
    'nav_settings': {
      'fr': 'Paramètres & Rapports',
      'en': 'Settings & Reports',
    },
    'fullscreen_btn': {
      'fr': 'Plein écran (F11)',
      'en': 'Fullscreen (F11)',
    },
    'student_kiosk_btn': {
      'fr': 'BORNE ÉTUDIANT',
      'en': 'STUDENT KIOSK',
    },

    // === ADMIN STUDENTS (MEMBERS) ===
    'students_badge': {
      'fr': 'ÉTUDIANTS & ACCÈS RFID',
      'en': 'STUDENTS & RFID ACCESS',
    },
    'students_title': {
      'fr': 'Gestion des Étudiants',
      'en': 'Student Management',
    },
    'register_student': {
      'fr': 'NOUVEL ÉTUDIANT',
      'en': 'REGISTER STUDENT',
    },
    'search_student_placeholder': {
      'fr': 'Rechercher par nom, matricule, département, ou tag RFID...',
      'en': 'Search by student name, ID number, department, or RFID tag...',
    },
    'no_students_found': {
      'fr': 'Aucun étudiant trouvé.',
      'en': 'No matching students found.',
    },
    'no_card_assigned': {
      'fr': 'Aucune carte associée',
      'en': 'No Card Assigned',
    },
    'assign_card': {
      'fr': 'ASSOCIER CARTE',
      'en': 'ASSIGN CARD',
    },
    'reassign_card': {
      'fr': 'RÉASSIGNER',
      'en': 'REASSIGN CARD',
    },
    'delete_student': {
      'fr': 'Supprimer cet étudiant',
      'en': 'Delete this student',
    },
    'delete_student_confirm_title': {
      'fr': 'Supprimer l\'étudiant',
      'en': 'Delete Student',
    },
    'delete_student_confirm_msg': {
      'fr': 'Êtes-vous sûr de vouloir supprimer définitivement cet étudiant et ses cartes RFID associées ?',
      'en': 'Are you sure you want to permanently delete this student and all linked RFID cards?',
    },
    'student_has_loans_warning': {
      'fr': 'Impossible de supprimer : cet étudiant a des emprunts en cours non retournés !',
      'en': 'Cannot delete: this student currently has active unreturned loans!',
    },
    'student_deleted_success': {
      'fr': 'Étudiant supprimé avec succès.',
      'en': 'Student successfully deleted.',
    },
    'empty_card_detected': {
      'fr': 'Carte RFID vierge / non encodée détectée',
      'en': 'Blank / Unprogrammed RFID Card Detected',
    },
    'empty_card_hint': {
      'fr': 'Cette carte est vide. Cliquez ci-dessous pour y graver le numéro étudiant et l\'activer.',
      'en': 'This card is blank. Click below to write the student ID onto the card and activate it.',
    },
    'write_and_activate_card': {
      'fr': 'ENCODER & ACTIVER LA CARTE',
      'en': 'ENCODE & ACTIVATE CARD',
    },
    'auto_activate_label': {
      'fr': 'Activer automatiquement les cartes vierges au passage',
      'en': 'Auto-program & activate empty cards on swipe',
    },
    'card_activated_success': {
      'fr': 'Carte activée avec succès ! Code gravé dans la puce RFID.',
      'en': 'Card activated successfully! Code encoded into RFID tag.',
    },
    'generate_card_code': {
      'fr': 'Générer Code EPC',
      'en': 'Generate EPC Code',
    },
    'card_not_activated_kiosk': {
      'fr': 'Carte non activée ou vierge. Veuillez vous adresser à l\'accueil.',
      'en': 'Card is not yet activated or is empty. Please visit the library desk.',
    },

    // === ADMIN CATALOG & BOOKS ===
    'catalog_badge': {
      'fr': 'CATALOGUE & INVENTAIRE RFID',
      'en': 'CATALOG & RFID INVENTORY',
    },
    'catalog_title': {
      'fr': 'Livres & Exemplaires Physiques',
      'en': 'Books & Physical Copies',
    },
    'new_book': {
      'fr': 'NOUVEAU LIVRE (RFID)',
      'en': 'NEW BOOK (RFID FIRST)',
    },
    'search_book_placeholder': {
      'fr': 'Rechercher par titre, auteur, ISBN, cote, catégorie...',
      'en': 'Search title, author, ISBN, call number, category...',
    },
    'no_books_found': {
      'fr': 'Aucun livre trouvé.',
      'en': 'No matching books found.',
    },
    'delete_book': {
      'fr': 'Supprimer ce livre',
      'en': 'Delete this book',
    },
    'delete_book_confirm_title': {
      'fr': 'Supprimer le livre',
      'en': 'Delete Book',
    },
    'delete_book_confirm_msg': {
      'fr': 'Êtes-vous sûr de vouloir supprimer ce livre ainsi que tous ses exemplaires physiques et tags RFID ?',
      'en': 'Are you sure you want to permanently delete this book and all its physical copies and RFID tags?',
    },
    'book_has_loans_warning': {
      'fr': 'Impossible de supprimer : un ou plusieurs exemplaires sont actuellement prêtés !',
      'en': 'Cannot delete: one or more copies are currently checked out!',
    },
    'book_deleted_success': {
      'fr': 'Livre et exemplaires supprimés avec succès.',
      'en': 'Book and copies successfully deleted.',
    },
    'copies_count': {
      'fr': 'Exemplaires',
      'en': 'Copies',
    },

    // === GENERAL BUTTONS & ACTIONS ===
    'confirm': {
      'fr': 'Confirmer',
      'en': 'Confirm',
    },
    'cancel': {
      'fr': 'Annuler',
      'en': 'Cancel',
    },
    'delete': {
      'fr': 'Supprimer',
      'en': 'Delete',
    },
    'save': {
      'fr': 'Enregistrer',
      'en': 'Save',
    },
    'close': {
      'fr': 'Fermer',
      'en': 'Close',
    },
  };
}
