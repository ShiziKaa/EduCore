import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../core/admin_upload_service.dart';
import '../../core/ai_server_service.dart';
import '../../core/services/institute_logo_service.dart';
import '../shared/background_glow.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final AdminUploadService _uploadService = AdminUploadService();
  final AiServerService _serverService = AiServerService();

  bool _isProcessing = false;
  String _logMessage = '';

  Future<void> _importAndUploadFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: AppConstants.allowedUploadExtensions,
    );

    if (result == null) return;

    setState(() {
      _isProcessing = true;
      _logMessage = 'Faýllar ýüklenilýär...';
    });

    try {
      await _serverService.ensureRunning();
      await _uploadService.uploadFiles(result.files);

      setState(() {
        _logMessage = 'Maglumat bazasy täzelenýär...';
      });

      await _uploadService.rebuildDatabase();

      setState(() {
        _logMessage = 'Üstünlikli tamamlandy! Ähli maglumatlar taýýar.';
      });
    } catch (e) {
      setState(() {
        _logMessage = 'Ýalňyşlyk ýüze çykdy: $e';
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _importInstituteLogo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.instituteLogoExtensions,
    );

    if (result == null || result.files.single.path == null) return;

    setState(() {
      _isProcessing = true;
      _logMessage = 'Logo ýüklenilýär...';
    });

    try {
      await InstituteLogoService.importLogo(result.files.single.path!);
      setState(() {
        _logMessage = 'Institut logosy üstünlikli ýüklendi!';
      });
    } catch (e) {
      setState(() {
        _logMessage = 'Logo ýüklenmedi: $e';
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _rebuildDatabaseOnly() async {
    setState(() {
      _isProcessing = true;
      _logMessage = 'Maglumat bazasy täzelenýär...';
    });

    try {
      await _serverService.ensureRunning();
      await _uploadService.rebuildDatabase();

      setState(() {
        _logMessage =
            'Üstünlikli täzelendi! Papkalar bilen sinhronizasiýa tamamlandy.';
      });
    } catch (e) {
      setState(() {
        _logMessage = 'Ýalňyşlyk ýüze çykdy: $e';
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        children: [
          BackgroundGlow(isDark: isDark, colors: colors),
          SafeArea(
            child: Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          Text(
                            'EduCore AI — Admin Paneli',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          Icon(
                            Icons.admin_panel_settings_rounded,
                            size: 56,
                            color: colors.primary,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Faýllary saýlaň we import ediň',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Word, Excel, surat we wideo faýllaryny bir gezekde ýükläp bilersiňiz.',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          FilledButton.icon(
                            icon: const Icon(Icons.cloud_upload_rounded, size: 28),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Text(
                                'Täze faýllary import et',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                            onPressed:
                                _isProcessing ? null : _importAndUploadFiles,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.refresh_rounded, size: 24),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Text(
                                'Maglumat bazasyny täzele',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            onPressed:
                                _isProcessing ? null : _rebuildDatabaseOnly,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.image_rounded, size: 24),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Text(
                                'Institut logosyny import et',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            onPressed:
                                _isProcessing ? null : _importInstituteLogo,
                          ),
                          const SizedBox(height: 24),
                          if (_isProcessing) const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            _logMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Yza',
                    style: IconButton.styleFrom(
                      foregroundColor: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
