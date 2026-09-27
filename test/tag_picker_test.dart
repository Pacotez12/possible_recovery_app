import 'package:flutter_test/flutter_test.dart';
import 'package:possible_recovery/core/tag_picker.dart';

void main() {
  group('pickTag', () {
    test('returns NoTag when list of reads is empty', () {
      final result = pickTag([]);
      expect(result, isA<NoTag>());
    });

    test('returns Picked with uppercase EPC when single tag read', () {
      final result = pickTag([TagRead('309373e167b0610bdce43394', -45.0)]);
      expect(result, isA<Picked>());
      expect((result as Picked).epc, '309373E167B0610BDCE43394');
    });

    test('returns Ambiguous when top two reads are within marginDb (default 3 dB)', () {
      final reads = [
        TagRead('EPC_ONE', -40.0),
        TagRead('EPC_TWO', -41.5), // 1.5 dB difference < 3.0 dB
      ];
      final result = pickTag(reads);
      expect(result, isA<Ambiguous>());
    });

    test('returns Picked strongest when top two reads are separated by at least marginDb', () {
      final reads = [
        TagRead('EPC_WEAK', -55.0),
        TagRead('EPC_STRONG', -42.0), // 13 dB difference > 3.0 dB
      ];
      final result = pickTag(reads);
      expect(result, isA<Picked>());
      expect((result as Picked).epc, 'EPC_STRONG');
    });

    test('returns Picked strongest when 6 dB apart', () {
      final reads = [
        TagRead('EPC_A', -46.0),
        TagRead('EPC_B', -40.0), // 6 dB difference
      ];
      final result = pickTag(reads);
      expect(result, isA<Picked>());
      expect((result as Picked).epc, 'EPC_B');
    });

    test('custom marginDb parameter is respected', () {
      final reads = [
        TagRead('EPC_A', -40.0),
        TagRead('EPC_B', -44.0), // 4 dB difference
      ];
      // With margin 5 dB, 4 dB difference is ambiguous
      expect(pickTag(reads, marginDb: 5.0), isA<Ambiguous>());
      // With margin 3 dB, 4 dB difference is picked
      expect(pickTag(reads, marginDb: 3.0), isA<Picked>());
    });
  });
}
