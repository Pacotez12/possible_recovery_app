/// Parses the EPC length in 16-bit words from a Gen2 Protocol Control (PC) word.
///
/// In Gen2 RFID, bits 15..11 of the 16-bit PC word specify the EPC length in words:
/// (pcVal >> 11) & 0x1F.
/// Returns null if [pc] is null, empty, invalid hex, or evaluates to 0 words.
int? parsePcWords(String? pc) {
  if (pc == null) return null;
  final clean = pc.replaceAll(' ', '').trim();
  if (clean.isEmpty) return null;
  final val = int.tryParse(clean, radix: 16);
  if (val == null || val == 0) return null;
  final words = (val >> 11) & 0x1F;
  return words > 0 ? words : null;
}

/// Normalizes an RFID EPC string.
///
/// 1. Strips leading/trailing whitespace, internal spaces, and converts to uppercase.
/// 2. If [pcWords] is provided and > 0, calculates target hex length = [pcWords] * 4.
///    If the cleaned EPC length is greater than target length, truncates to target length.
///    If the cleaned EPC length is <= target length, keeps it unchanged.
/// 3. Fallback (when [pcWords] is null or <= 0):
///    If the cleaned EPC has exactly 32 hex characters, starts with '30' and ends with
///    '00000000' (8 trailing zeros), truncates to 24 hex characters.
/// 4. Otherwise, returns the cleaned EPC unchanged.
String normalizeEpc(String epc, {int? pcWords}) {
  final clean = epc.replaceAll(' ', '').trim().toUpperCase();
  if (clean.isEmpty) return '';

  if (pcWords != null && pcWords > 0) {
    final targetLen = pcWords * 4;
    if (clean.length > targetLen) {
      return clean.substring(0, targetLen);
    }
    return clean;
  }

  // Fallback when no usable PC is available
  if (clean.length == 32 && clean.startsWith('30') && clean.endsWith('00000000')) {
    return clean.substring(0, 24);
  }

  return clean;
}
