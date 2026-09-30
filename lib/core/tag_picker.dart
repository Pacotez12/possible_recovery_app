import 'epc_normalizer.dart';

class TagRead {
  final String epc;
  final double rssi;

  TagRead(String epc, this.rssi) : epc = normalizeEpc(epc);
}

sealed class PickResult {}

class Picked extends PickResult {
  final String epc;

  Picked(String epc) : epc = normalizeEpc(epc);
}

class NoTag extends PickResult {}

class Ambiguous extends PickResult {}

PickResult pickTag(List<TagRead> reads, {double marginDb = 3}) {
  if (reads.isEmpty) return NoTag();
  final sorted = [...reads]..sort((a, b) => b.rssi.compareTo(a.rssi));
  if (sorted.length > 1 && (sorted[0].rssi - sorted[1].rssi) < marginDb) {
    return Ambiguous();
  }
  return Picked(normalizeEpc(sorted[0].epc));
}
