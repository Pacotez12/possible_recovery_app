/// Deduplicates scanned barcodes within a configurable window (default 1500ms).
///
/// Only actual deliveries update [lastDeliveredBarcode] and [lastDeliveredAt].
/// Discards (repeated identical barcode within the window) do NOT update the timestamp
/// and do NOT extend the window.
class BarcodeDeduper {
  final Duration window;
  final DateTime Function() _clock;

  String? _lastDeliveredBarcode;
  DateTime _lastDeliveredAt = DateTime.fromMillisecondsSinceEpoch(0);

  BarcodeDeduper({
    this.window = const Duration(milliseconds: 1500),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  String? get lastDeliveredBarcode => _lastDeliveredBarcode;
  DateTime get lastDeliveredAt => _lastDeliveredAt;

  /// Returns true if [code] should be delivered, or false if it is a duplicate within [window].
  ///
  /// Only returns true if:
  /// 1. [code] trimmed is non-empty, and
  /// 2. [code] is different from [lastDeliveredBarcode], OR
  ///    the elapsed time since [lastDeliveredAt] is >= [window].
  ///
  /// If it returns true, updates [lastDeliveredBarcode] and [lastDeliveredAt].
  /// If it returns false, does NOT update [lastDeliveredAt] (discards do not extend the window).
  bool shouldDeliver(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return false;

    final now = _clock();
    if (trimmed == _lastDeliveredBarcode &&
        now.difference(_lastDeliveredAt) < window) {
      return false;
    }

    _lastDeliveredBarcode = trimmed;
    _lastDeliveredAt = now;
    return true;
  }

  /// Clears deduplication state so any barcode will pass.
  void reset() {
    _lastDeliveredBarcode = null;
    _lastDeliveredAt = DateTime.fromMillisecondsSinceEpoch(0);
  }
}
