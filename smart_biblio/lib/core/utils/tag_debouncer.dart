/// TagDebouncer prevents repeated fast RFID reads of the same physical tag
/// from overwhelming the UI or creating duplicate transactions.
class TagDebouncer {
  final Duration debounceWindow;
  final Map<String, DateTime> _lastSeen = {};
  final Map<String, int> _readCounts = {};

  TagDebouncer({Duration? debounceWindow})
      : debounceWindow = debounceWindow ?? const Duration(milliseconds: 1200);

  /// Checks if a tag EPC is fresh (not seen within debounce window).
  /// If fresh, updates timestamp and returns true.
  /// If seen recently within window, increments count and returns false.
  bool shouldProcess(String epc) {
    final cleanEpc = epc.trim().toUpperCase();
    final now = DateTime.now();
    _readCounts[cleanEpc] = (_readCounts[cleanEpc] ?? 0) + 1;

    final last = _lastSeen[cleanEpc];
    if (last == null || now.difference(last) > debounceWindow) {
      _lastSeen[cleanEpc] = now;
      return true;
    }
    return false;
  }

  /// Returns total read count of a given EPC in this session.
  int getReadCount(String epc) => _readCounts[epc.trim().toUpperCase()] ?? 0;

  /// Clears cache for a single tag so it can be re-scanned immediately.
  void clearTag(String epc) {
    final cleanEpc = epc.trim().toUpperCase();
    _lastSeen.remove(cleanEpc);
    _readCounts.remove(cleanEpc);
  }

  /// Clears all debounced tags (e.g. at start of a new scan session).
  void reset() {
    _lastSeen.clear();
    _readCounts.clear();
  }

  /// Remove entries that have expired past the debounce window to prevent memory leaks.
  void purgeExpired() {
    final now = DateTime.now();
    _lastSeen.removeWhere((_, time) => now.difference(time) > debounceWindow * 3);
  }
}
