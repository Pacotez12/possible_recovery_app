import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'barcode_deduper.dart';
import 'epc_normalizer.dart';
import 'tag_picker.dart';

class RfidService {
  static const MethodChannel _channel = MethodChannel('com.segel.possible_recovery/rfid');

  final _triggerController = StreamController<void>.broadcast();
  Stream<void> get onTrigger => _triggerController.stream;

  final _tagReadController = StreamController<TagRead>.broadcast();
  Stream<TagRead> get onTagRead => _tagReadController.stream;

  final _barcodeController = StreamController<String>.broadcast();
  Stream<String> get onBarcode => _barcodeController.stream;
  Stream<String> get onBarcodeRead => _barcodeController.stream;

  final _keyController = StreamController<int>.broadcast();
  Stream<int> get onKeyEvent => _keyController.stream;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  final BarcodeDeduper _barcodeDeduper;

  RfidService({BarcodeDeduper? barcodeDeduper})
      : _barcodeDeduper = barcodeDeduper ?? BarcodeDeduper() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  void resetBarcodeDedupe() {
    _barcodeDeduper.reset();
    _channel.invokeMethod<bool>('resetBarcodeDedupe').catchError((_) => false);
  }

  @visibleForTesting
  Future<void> handleNativeCallForTest(MethodCall call) => _handleNativeCall(call);

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onTriggerPressed':
      case 'trigger':
        _triggerController.add(null);
        break;
      case 'onTagRead':
        if (call.arguments is Map) {
          final map = Map<String, dynamic>.from(call.arguments as Map);
          final rawEpc = map['epc']?.toString() ?? '';
          final epc = normalizeEpc(rawEpc);
          final rssi = (map['rssi'] is num)
              ? (map['rssi'] as num).toDouble()
              : double.tryParse(map['rssi']?.toString() ?? '') ?? -100.0;
          if (epc.isNotEmpty) {
            _tagReadController.add(TagRead(epc, rssi));
          }
        }
        break;
      case 'onBarcodeRead':
      case 'barcode':
        final code = call.arguments?.toString() ?? '';
        final trimmed = code.trim();
        final lower = trimmed.toLowerCase();
        if (lower == 'cancel' || lower == 'failuer' || lower == 'failure' || lower == 'timeout') {
          debugPrint('RfidService: ignorando estado del escáner "$code"');
          break;
        }
        if (trimmed.isNotEmpty) {
          if (_barcodeDeduper.shouldDeliver(trimmed)) {
            _barcodeController.add(trimmed);
          } else {
            debugPrint('RfidService: ignorando barcode duplicado "$trimmed" (< 1.5s)');
          }
        }
        break;
      case 'onKeyDown':
        final keyCode = (call.arguments is Map)
            ? call.arguments['keyCode']
            : call.arguments;
        if (keyCode is int) {
          debugPrint('KeyCode recibido en colector: $keyCode');
          _keyController.add(keyCode);
        }
        break;
    }
  }

  Future<bool> initReader() async {
    try {
      final res = await _channel.invokeMethod<bool>('initReader');
      _isInitialized = res ?? false;
      return _isInitialized;
    } catch (e) {
      debugPrint('RfidService initReader error: $e');
      _isInitialized = false;
      return false;
    }
  }

  Future<bool> freeReader() async {
    try {
      final res = await _channel.invokeMethod<bool>('freeReader');
      _isInitialized = false;
      return res ?? false;
    } catch (e) {
      debugPrint('RfidService freeReader error: $e');
      return false;
    }
  }

  Future<int> getPower() async {
    try {
      final res = await _channel.invokeMethod<int>('getPower');
      return res ?? 10;
    } catch (e) {
      debugPrint('RfidService getPower error: $e');
      return 10;
    }
  }

  Future<bool> setPower(int power) async {
    try {
      final res = await _channel.invokeMethod<bool>('setPower', power);
      return res ?? false;
    } catch (e) {
      debugPrint('RfidService setPower error: $e');
      return false;
    }
  }

  Future<List<TagRead>> readBurst({int durationMs = 1000}) async {
    try {
      final res = await _channel.invokeMethod<List<dynamic>>('readBurst', durationMs);
      if (res == null) return [];

      final list = <TagRead>[];
      for (final item in res) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final epc = normalizeEpc(map['epc']?.toString() ?? '');
          final rssi = (map['rssi'] is num)
              ? (map['rssi'] as num).toDouble()
              : double.tryParse(map['rssi']?.toString() ?? '') ?? -100.0;
          if (epc.isNotEmpty) {
            list.add(TagRead(epc, rssi));
          }
        }
      }
      return list;
    } catch (e) {
      debugPrint('RfidService readBurst error: $e');
      return [];
    }
  }

  Future<bool> openScanner() async {
    try {
      final res = await _channel.invokeMethod<bool>('openScanner');
      return res ?? false;
    } catch (e) {
      debugPrint('RfidService openScanner error: $e');
      return false;
    }
  }

  Future<bool> startScan() async {
    try {
      final res = await _channel.invokeMethod<bool>('startScan');
      return res ?? false;
    } catch (e) {
      debugPrint('RfidService startScan error: $e');
      return false;
    }
  }

  Future<bool> stopScan() async {
    try {
      final res = await _channel.invokeMethod<bool>('stopScan');
      return res ?? false;
    } catch (e) {
      debugPrint('RfidService stopScan error: $e');
      return false;
    }
  }

  Future<bool> closeScanner() async {
    try {
      final res = await _channel.invokeMethod<bool>('closeScanner');
      return res ?? false;
    } catch (e) {
      debugPrint('RfidService closeScanner error: $e');
      return false;
    }
  }

  Future<bool> setWaitingSku(bool waiting) async {
    try {
      final res = await _channel.invokeMethod<bool>('setWaitingSku', waiting);
      return res ?? false;
    } catch (e) {
      debugPrint('RfidService setWaitingSku error: $e');
      return false;
    }
  }

  Future<bool> setKeyMode(String mode) async {
    try {
      final res = await _channel.invokeMethod<bool>('setKeyMode', mode);
      return res ?? false;
    } catch (e) {
      debugPrint('RfidService setKeyMode error: $e');
      return false;
    }
  }

  void dispose() {
    _triggerController.close();
    _tagReadController.close();
    _barcodeController.close();
    _keyController.close();
  }
}
