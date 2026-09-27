import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/rfid_service.dart';
import '../../data/api_client.dart';
import '../../utils/device_helper.dart';
import '../theme/tokens.dart';
import '../widgets/pressable_scale.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _hostController = TextEditingController();
  final _rfidService = RfidService();

  int _power = 10;
  double _marginDb = 3.0;
  String _deviceId = '';
  bool _isLoading = true;
  String? _saveMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await DeviceHelper.getDeviceId();
    final power = prefs.getInt('rfid_power') ?? 10;
    final marginDb = prefs.getDouble('rfid_margin_db') ?? 3.0;
    final host = prefs.getString('api_host') ?? 'http://127.0.0.1:8005/api/';

    if (mounted) {
      setState(() {
        _power = power;
        _marginDb = marginDb;
        _deviceId = deviceId;
        _hostController.text = host;
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePower(int newPower) async {
    setState(() {
      _power = newPower;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('rfid_power', newPower);
    await _rfidService.setPower(newPower);
  }

  Future<void> _updateMarginDb(double newMargin) async {
    setState(() {
      _marginDb = newMargin;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('rfid_margin_db', newMargin);
  }

  Future<void> _saveHost() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) return;

    final formatted = ApiClient.normalizeBaseUrl(host);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_host', formatted);

    if (!mounted) return;
    final apiClient = context.read<ApiClient>();
    await apiClient.updateBaseUrl(formatted);

    setState(() {
      _hostController.text = formatted;
      _saveMessage = 'Servidor actualizado correctamente.';
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _saveMessage = null;
        });
      }
    });
  }

  Future<void> _copyDeviceId() async {
    await Clipboard.setData(ClipboardData(text: _deviceId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ID del dispositivo copiado al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cerrar sesión', style: AppTypography.title),
        content: const Text(
          '¿Está seguro de que desea cerrar la sesión actual?',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.conflict,
              minimumSize: const Size(120, 48),
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    _rfidService.dispose();
    super.dispose();
  }

  Widget _buildPresetChip(String label, int value) {
    final isSelected = _power == value;
    return Expanded(
      child: PressableScale(
        onPressed: () => _updatePower(value),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brandSoft : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: isSelected ? AppColors.brand : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.brand : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Image.asset(
          'lib/assets/images/RECOVERY_DARK_TIGHT.png',
          height: 28,
          fit: BoxFit.contain,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.lg),
        children: [
          Text('LECTOR RFID', style: AppTypography.label),
          const SizedBox(height: AppSpace.sm),
          Container(
            padding: const EdgeInsets.all(AppSpace.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Potencia de lectura',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '$_power dBm',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brand,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                Row(
                  children: [
                    _buildPresetChip('Corto 5', 5),
                    const SizedBox(width: AppSpace.sm),
                    _buildPresetChip('Normal 10', 10),
                    const SizedBox(width: AppSpace.sm),
                    _buildPresetChip('Largo 20 dBm', 20),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.brand,
                    thumbColor: AppColors.brand,
                    inactiveTrackColor: AppColors.brandSoft,
                    overlayColor: AppColors.brand.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _power.toDouble(),
                    min: 5,
                    max: 30,
                    divisions: 25,
                    label: '$_power dBm',
                    onChanged: (val) => _updatePower(val.round()),
                  ),
                ),
                const Divider(color: AppColors.border, height: 1),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'Avanzado',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.xs, bottom: AppSpace.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Margen de ambigüedad',
                                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                                ),
                                Text(
                                  '${_marginDb.toStringAsFixed(1)} dB',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.brand,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: AppColors.brand,
                                thumbColor: AppColors.brand,
                                inactiveTrackColor: AppColors.brandSoft,
                                overlayColor: AppColors.brand.withValues(alpha: 0.2),
                              ),
                              child: Slider(
                                value: _marginDb,
                                min: 1.0,
                                max: 10.0,
                                divisions: 18,
                                label: '${_marginDb.toStringAsFixed(1)} dB',
                                onChanged: (val) => _updateMarginDb(val),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Text('CONEXIÓN Y SERVIDOR', style: AppTypography.label),
          const SizedBox(height: AppSpace.sm),
          Container(
            padding: const EdgeInsets.all(AppSpace.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Host de la API',
                    hintText: 'http://127.0.0.1:8005/api/',
                  ),
                ),
                if (_saveMessage != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    _saveMessage!,
                    style: const TextStyle(
                      color: AppColors.created,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.md),
                PressableScale(
                  onPressed: _saveHost,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.brandSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.brand.withValues(alpha: 0.3),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Guardar servidor',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Text('DISPOSITIVO', style: AppTypography.label),
          const SizedBox(height: AppSpace.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg,
              vertical: AppSpace.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ID del Dispositivo',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        _deviceId,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Copiar ID',
                  onPressed: _copyDeviceId,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xxl),
          Center(
            child: PressableScale(
              onPressed: _logout,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg,
                  vertical: AppSpace.md,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      color: AppColors.conflict,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Text(
                      'Cerrar sesión',
                      style: const TextStyle(
                        color: AppColors.conflict,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xl),
        ],
      ),
    );
  }
}
