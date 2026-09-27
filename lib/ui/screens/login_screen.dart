import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_error.dart';
import '../../data/api_client.dart';
import '../../data/local_db.dart';
import '../theme/tokens.dart';
import '../widgets/error_banner.dart';
import '../widgets/pressable_scale.dart';
import 'scan_screen.dart';
import 'sync_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isHostExpanded = false;
  AppError? _currentError;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hostController.text =
          prefs.getString('api_host') ?? 'http://127.0.0.1:8005/api/';
      _emailController.text = prefs.getString('saved_email') ?? '';
    });
  }

  String get _displayHost {
    final text = _hostController.text.trim();
    if (text.isEmpty) return '127.0.0.1:8005';
    return text
        .replaceAll('http://', '')
        .replaceAll('https://', '')
        .replaceAll('/api/', '')
        .replaceAll('/', '');
  }

  Future<void> _login() async {
    final rawHost = _hostController.text.trim();
    if (!rawHost.startsWith('http://') && !rawHost.startsWith('https://')) {
      setState(() {
        _isHostExpanded = true;
        _currentError = const AppError(
          kind: AppErrorKind.validation,
          title: 'Dirección del servidor inválida',
          message: 'La dirección debe empezar con http:// y terminar en /api/',
          canRetry: false,
        );
      });
      return;
    }

    if (!rawHost.endsWith('/api/')) {
      setState(() {
        _isHostExpanded = true;
        _currentError = const AppError(
          kind: AppErrorKind.validation,
          title: 'Dirección del servidor inválida',
          message: 'La dirección debe empezar con http:// y terminar en /api/',
          canRetry: false,
        );
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _currentError = null;
    });

    final apiClient = context.read<ApiClient>();
    final localDb = context.read<LocalDb>();

    try {
      final host = ApiClient.normalizeBaseUrl(_hostController.text);
      await apiClient.login(
        _emailController.text.trim(),
        _passwordController.text,
        customHost: host,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_email', _emailController.text.trim());

      final productCount = await localDb.getProductsCount();

      if (!mounted) return;

      if (productCount == 0) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const SyncScreen(initialSyncPrompt: true),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ScanScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentError = mapError(
          e,
          host: _displayHost,
          isLogin: true,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.xl,
              vertical: AppSpace.lg,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Image.asset(
                        'lib/assets/images/RECOVERY.png',
                        width: 180,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  const Center(
                    child: Text(
                      'Re-asociación de etiquetas RFID',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xxl),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Ingrese su correo electrónico';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpace.md),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Ingrese su contraseña';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpace.md),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isHostExpanded = !_isHostExpanded;
                      });
                    },
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpace.xs,
                        horizontal: AppSpace.xs,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.dns_outlined,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpace.xs),
                          Expanded(
                            child: Text(
                              'Servidor: $_displayHost · ${_isHostExpanded ? "Ocultar" : "Cambiar"}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isHostExpanded) ...[
                    const SizedBox(height: AppSpace.sm),
                    TextFormField(
                      controller: _hostController,
                      decoration: const InputDecoration(
                        labelText: 'URL del Servidor',
                        hintText: 'http://127.0.0.1:8005/api/',
                        prefixIcon: Icon(Icons.cloud_outlined),
                      ),
                      keyboardType: TextInputType.url,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Ingrese la URL del servidor';
                        }
                        final s = val.trim();
                        if (!s.startsWith('http://') && !s.startsWith('https://')) {
                          return 'La dirección debe empezar con http:// y terminar en /api/';
                        }
                        if (!s.endsWith('/api/')) {
                          return 'La dirección debe empezar con http:// y terminar en /api/';
                        }
                        return null;
                      },
                    ),
                  ],
                  if (_currentError != null) ...[
                    const SizedBox(height: AppSpace.md),
                    ErrorBanner(
                      error: _currentError!,
                      onRetry: _currentError!.canRetry ? _login : null,
                      onDismiss: () => setState(() => _currentError = null),
                    ),
                  ],
                  const SizedBox(height: AppSpace.xl),
                  PressableScale(
                    onPressed: _isLoading ? null : _login,
                    enabled: !_isLoading,
                    child: Container(
                      height: AppSize.primaryButton,
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      alignment: Alignment.center,
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
