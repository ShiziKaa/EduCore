import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/admin_messages.dart';
import '../../core/admin_document_service.dart';
import '../../core/admin_upload_service.dart';
import '../../core/ai_server_service.dart';
import '../../core/app_constants.dart';
import '../../core/models/admin_draft.dart';
import '../../core/models/admin_paragraph.dart';
import '../../core/services/institute_logo_service.dart';
import '../../core/services/desktop_window_service.dart';
import 'admin_confirm_dialog.dart';
import 'admin_media_preview.dart';
import 'admin_toast_stack.dart';
import 'admin_welcome_settings_panel.dart';
import '../shared/background_glow.dart';

enum _AdminMode { constructor, welcome }
enum _MediaType { image, video, audio }

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final AdminDocumentService _documentService = AdminDocumentService();
  final AdminUploadService _uploadService = AdminUploadService();
  final AiServerService _serverService = AiServerService();
  final TextEditingController _editorController = TextEditingController();

  AdminDraft? _draft;
  int? _selectedIndex;
  bool _isProcessing = false;
  bool _isDraftFinalized = false;
  _AdminMode _mode = _AdminMode.constructor;
  File? _instituteLogoPreview;
  final List<AdminToastData> _toasts = [];
  int _toastCounter = 0;

  @override
  void initState() {
    super.initState();
    _loadLogoPreview();
  }

  @override
  void dispose() {
    _editorController.dispose();
    super.dispose();
  }

  AdminParagraph? get _selectedParagraph {
    final index = _selectedIndex;
    final draft = _draft;
    if (index == null || draft == null || index >= draft.paragraphs.length) {
      return null;
    }
    return draft.paragraphs[index];
  }

  bool get _isEditingDraft => _draft != null && !_isDraftFinalized;

  bool get _allParagraphsSaved {
    final draft = _draft;
    if (draft == null || draft.paragraphs.isEmpty) return false;
    return draft.paragraphs.every((paragraph) => paragraph.isSaved);
  }

  bool get _canImportDocument => _draft == null;

  bool get _canShowRebuild => !_isEditingDraft;

  Future<void> _ensureServer() async {
    await _serverService.ensureRunning();
  }

  void _loadLogoPreview() {
    setState(() => _instituteLogoPreview = InstituteLogoService.resolve());
  }

  void _showToast(String message, {bool error = false}) {
    setState(() {
      _toastCounter++;
      _toasts.insert(
        0,
        AdminToastData(
          id: 'toast_$_toastCounter',
          message: message,
          isError: error,
        ),
      );
    });
  }

  void _dismissToast(String id) {
    setState(() => _toasts.removeWhere((toast) => toast.id == id));
  }

  Future<void> _importDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.allowedDocumentExtensions,
    );

    if (result == null || result.files.single.path == null) return;

    setState(() => _isProcessing = true);

    try {
      await _ensureServer();
      final file = result.files.single;
      final draft = await _documentService.parseDocument(file.path!, file.name);

      setState(() {
        _draft = draft;
        _selectedIndex = draft.paragraphs.isEmpty ? null : 0;
        _isDraftFinalized = false;
      });
      _syncEditorFromSelection();
      _showToast(
        '${draft.paragraphs.length} abzas tapyldy. Birini saýlap redaktirläň.',
      );
    } catch (e) {
      _showToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _selectParagraph(int index) {
    _applyEditorToSelectedParagraph();
    setState(() => _selectedIndex = index);
    _syncEditorFromSelection();
  }

  void _syncEditorFromSelection() {
    final paragraph = _selectedParagraph;
    _editorController.text = paragraph?.text ?? '';
  }

  void _applyEditorToSelectedParagraph() {
    final paragraph = _selectedParagraph;
    if (paragraph == null) return;
    paragraph.text = _editorController.text;
  }

  Future<bool> _validateParagraphs(AdminDraft draft) async {
    _applyEditorToSelectedParagraph();

    for (var i = 0; i < draft.paragraphs.length; i++) {
      final paragraph = draft.paragraphs[i];
      if (paragraph.text.trim().isEmpty) {
        _showToast('Abzas ${i + 1} boş bolup bilmez.', error: true);
        return false;
      }
      if (paragraph.isNews && (paragraph.newsPreview ?? '').isEmpty) {
        _showToast(
          'Abzas ${i + 1}: möhüm habar üçin preview suraty hökmany.',
          error: true,
        );
        return false;
      }
    }

    return true;
  }

  Future<void> _saveAllParagraphs() async {
    final draft = _draft;
    if (draft == null || _isDraftFinalized) return;

    if (!await _validateParagraphs(draft)) return;
    if (!mounted) return;

    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Ähli abzaslary ýaz',
      message:
          '${draft.paragraphs.length} abzasy draft-a ýazmak isleýärsiňizmi? Bu ädimden soň resminamany baza goşup bilersiňiz.',
      confirmLabel: 'Hemmesini ýaz',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      await _ensureServer();
      var updated = draft;
      for (var i = 0; i < updated.paragraphs.length; i++) {
        updated = await _documentService.saveParagraph(
          draftId: updated.id,
          index: i,
          paragraph: updated.paragraphs[i],
        );
      }

      if (!mounted) return;
      setState(() => _draft = updated);
      _showToast('Ähli abzaslar ýazyldy (${updated.paragraphs.length}).');
    } catch (e) {
      _showToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveCurrentParagraph() async {
    final draft = _draft;
    final index = _selectedIndex;
    if (draft == null || index == null) return;

    _applyEditorToSelectedParagraph();
    final paragraph = draft.paragraphs[index];

    if (paragraph.text.trim().isEmpty) {
      _showToast('Abzas boş bolup bilmez.', error: true);
      return;
    }

    if (paragraph.isNews && (paragraph.newsPreview ?? '').isEmpty) {
      _showToast('Möhüm habar üçin preview suraty hökmany.', error: true);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await _ensureServer();
      final updated = await _documentService.saveParagraph(
        draftId: draft.id,
        index: index,
        paragraph: paragraph,
      );
      setState(() => _draft = updated);
      _showToast('Abzas ${index + 1} ýazyldy.');
    } catch (e) {
      _showToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _finalizeDocument() async {
    final draft = _draft;
    if (draft == null || _isDraftFinalized) return;

    if (!await _validateParagraphs(draft)) return;
    if (!mounted) return;

    if (!_allParagraphsSaved) {
      _showToast(
        'Ilki ähli abzaslary ýazyň («Ähli abzaslary ýaz»).',
        error: true,
      );
      return;
    }
    if (!mounted) return;

    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Resminamany baza goş',
      message:
          '«${draft.outputFilename}» faýly data/ papkasyna ýazylar. Soň «Bazany täzele» basmaly.',
      confirmLabel: 'Baza goş',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      await _ensureServer();
      final result = await _documentService.finalizeDraft(draft.id);
      if (!mounted) return;
      setState(() => _isDraftFinalized = true);
      _showToast('${result['filename']} taýýar. Indi «Bazany täzele» basyň.');
    } catch (e) {
      _showToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _addMedia({required _MediaType type}) async {
    final paragraph = _selectedParagraph;
    if (paragraph == null) {
      _showToast('Ilki abzas saýlaň.', error: true);
      return;
    }

    if (type == _MediaType.audio && paragraph.audios.isNotEmpty) {
      _showToast('Bir abzasda diňe 1 audio bolup bilýär.', error: true);
      return;
    }

    final allowedExtensions = switch (type) {
      _MediaType.video => AppConstants.allowedVideoExtensions,
      _MediaType.audio => AppConstants.allowedAudioExtensions,
      _MediaType.image => AppConstants.allowedImageExtensions,
    };

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    if (result == null || result.files.single.path == null) return;

    setState(() => _isProcessing = true);

    try {
      await _ensureServer();
      final file = result.files.single;
      final filename = await _documentService.uploadMedia(
        file.path!,
        file.name,
      );

      setState(() {
        if (type == _MediaType.video) {
          paragraph.videos = [...paragraph.videos, filename];
        } else if (type == _MediaType.audio) {
          paragraph.audios = [filename];
        } else {
          paragraph.images = [...paragraph.images, filename];
        }
        paragraph.isSaved = false;
      });
      final msg = switch (type) {
        _MediaType.video => 'Wideo goşuldy.',
        _MediaType.audio => 'Audio goşuldy.',
        _MediaType.image => 'Surat goşuldy.',
      };
      _showToast(msg);
    } catch (e) {
      _showToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _removeAudio(String fileName) {
    final paragraph = _selectedParagraph;
    if (paragraph == null) return;

    setState(() {
      paragraph.audios = paragraph.audios
          .where((name) => name != fileName)
          .toList();
      paragraph.isSaved = false;
    });
    _showToast('Audio öçürildi.');
  }

  Future<void> _pickNewsPreview() async {
    final paragraph = _selectedParagraph;
    if (paragraph == null) {
      _showToast('Ilki abzas saýlaň.', error: true);
      return;
    }

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.allowedImageExtensions,
    );

    if (result == null || result.files.single.path == null) return;

    setState(() => _isProcessing = true);

    try {
      await _ensureServer();
      final file = result.files.single;
      final filename = await _documentService.uploadMedia(
        file.path!,
        file.name,
      );

      setState(() {
        paragraph.newsPreview = filename;
        paragraph.isSaved = false;
      });
      _showToast('Preview suraty saýlandy.');
    } catch (e) {
      _showToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _toggleNews(bool value) {
    final paragraph = _selectedParagraph;
    if (paragraph == null) return;

    setState(() {
      paragraph.isNews = value;
      if (!value) {
        paragraph.newsPreview = null;
      }
      paragraph.isSaved = false;
    });
  }

  Future<void> _rebuildDatabaseOnly() async {
    if (!mounted) return;

    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Bazany täzele',
      message:
          'Maglumat bazasy täzeden gurlar. Bu birnäçe minut alýar. Dowam etmek isleýärsiňizmi?',
      confirmLabel: 'Täzele',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      await _ensureServer();
      await _uploadService.rebuildDatabase();
      if (!mounted) return;
      setState(() {
        _draft = null;
        _selectedIndex = null;
        _isDraftFinalized = false;
        _editorController.clear();
      });
      _showToast('Maglumat bazasy üstünlikli täzelendi.');
    } catch (e) {
      _showToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _importInstituteLogo() async {
    if (_isProcessing) return;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.instituteLogoExtensions,
    );

    if (result == null || result.files.single.path == null) return;

    setState(() => _isProcessing = true);

    try {
      await InstituteLogoService.importLogo(result.files.single.path!);
      _loadLogoPreview();
      _showToast('Institut logosy ýüklendi.');
    } catch (e) {
      _showToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _exportDatabase() async {
    final savePath = await FilePicker.saveFile(
      dialogTitle: 'Bazany eksport et (Zip)',
      fileName: 'BilimCesmesi_DB_Export.zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (savePath == null) return;

    setState(() => _isProcessing = true);

    try {
      await _ensureServer();
      await _documentService.exportDatabase(savePath);
      _showToast('Baza üstünlikli eksport edildi.');
    } catch (e) {
      _showToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _importDatabase() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.single.path == null) return;
    if (!mounted) return;

    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Bazany import et',
      message: 'Üns beriň! Häzirki baza doly öçürilip, täzesi bilen çalşyrylar. Dowam etmeli mi?',
      confirmLabel: 'Import et',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      await _ensureServer();
      final file = result.files.single;
      await _documentService.importDatabase(file.path!, file.name);
      if (!mounted) return;
      setState(() {
        _draft = null;
        _selectedIndex = null;
        _isDraftFinalized = false;
      });
      _showToast('Baza üstünlikli import edildi.');
    } catch (e) {
      _showToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final paragraph = _selectedParagraph;
    final draft = _draft;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        children: [
          BackgroundGlow(isDark: isDark, colors: colors),
          SafeArea(
            top: !DesktopWindowService.isDesktop,
            bottom: true,
            child: Column(
              children: [
                _AdminToolbar(
                  colors: colors,
                  isProcessing: _isProcessing,
                  mode: _mode,
                  draftName: draft?.sourceFilename,
                  isDraftFinalized: _isDraftFinalized,
                  onBack: () => Navigator.of(context).maybePop(),
                  onModeChanged: (mode) => setState(() => _mode = mode),
                  onImportDocument: _importDocument,
                  onExportDatabase: _exportDatabase,
                  onImportDatabase: _importDatabase,
                  onSaveAllParagraphs: _saveAllParagraphs,
                  onFinalizeDocument: _finalizeDocument,
                  onRebuild: _rebuildDatabaseOnly,
                  canImportDocument: _canImportDocument,
                  canShowRebuild: _canShowRebuild,
                  canSaveAllParagraphs: _isEditingDraft,
                  canFinalize: _isEditingDraft,
                ),
                Expanded(
                  child: _mode == _AdminMode.welcome
                      ? AdminWelcomeSettingsPanel(
                          colors: colors,
                          instituteLogo: _instituteLogoPreview,
                          onImportLogo: _importInstituteLogo,
                          onSaved: () {},
                          onToast: _showToast,
                        )
                      : draft == null
                      ? _EmptyConstructorState(colors: colors)
                      : Row(
                          children: [
                            _ParagraphExplorer(
                              colors: colors,
                              paragraphs: draft.paragraphs,
                              selectedIndex: _selectedIndex,
                              onSelect: _selectParagraph,
                            ),
                            VerticalDivider(
                              width: 1,
                              color: colors.outlineVariant,
                            ),
                            Expanded(
                              child: _ParagraphEditor(
                                colors: colors,
                                controller: _editorController,
                                selectedIndex: _selectedIndex,
                                paragraph: paragraph,
                                onChanged: () {
                                  final current = _selectedParagraph;
                                  if (current != null) {
                                    current.isSaved = false;
                                  }
                                },
                              ),
                            ),
                            VerticalDivider(
                              width: 1,
                              color: colors.outlineVariant,
                            ),
                            _ParagraphActions(
                              colors: colors,
                              paragraph: paragraph,
                              isProcessing: _isProcessing,
                              onAddImage: () => _addMedia(type: _MediaType.image),
                              onAddVideo: () => _addMedia(type: _MediaType.video),
                              onAddAudio: () => _addMedia(type: _MediaType.audio),
                              onRemoveAudio: _removeAudio,
                              onToggleNews: _toggleNews,
                              onPickPreview: _pickNewsPreview,
                              onSaveParagraph: _saveCurrentParagraph,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 52,
            right: 16,
            child: AdminToastStack(toasts: _toasts, onDismiss: _dismissToast),
          ),
          if (_isProcessing)
            const Positioned(
              left: 16,
              bottom: 16,
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminToolbar extends StatelessWidget {
  const _AdminToolbar({
    required this.colors,
    required this.isProcessing,
    required this.mode,
    required this.draftName,
    required this.isDraftFinalized,
    required this.onBack,
    required this.onModeChanged,
    required this.onImportDocument,
    required this.onExportDatabase,
    required this.onImportDatabase,
    required this.onSaveAllParagraphs,
    required this.onFinalizeDocument,
    required this.onRebuild,
    required this.canImportDocument,
    required this.canShowRebuild,
    required this.canSaveAllParagraphs,
    required this.canFinalize,
  });

  final ColorScheme colors;
  final bool isProcessing;
  final _AdminMode mode;
  final String? draftName;
  final bool isDraftFinalized;
  final VoidCallback onBack;
  final ValueChanged<_AdminMode> onModeChanged;
  final VoidCallback onImportDocument;
  final VoidCallback onExportDatabase;
  final VoidCallback onImportDatabase;
  final VoidCallback onSaveAllParagraphs;
  final VoidCallback onFinalizeDocument;
  final VoidCallback onRebuild;
  final bool canImportDocument;
  final bool canShowRebuild;
  final bool canSaveAllParagraphs;
  final bool canFinalize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Yza',
            ),
            const SizedBox(width: 4),
            SegmentedButton<_AdminMode>(
              segments: const [
                ButtonSegment(
                  value: _AdminMode.constructor,
                  label: Text('Konstruktor'),
                  icon: Icon(Icons.account_tree_outlined, size: 18),
                ),
                ButtonSegment(
                  value: _AdminMode.welcome,
                  label: Text('Baş sahypa'),
                  icon: Icon(Icons.home_outlined, size: 18),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (selection) => onModeChanged(selection.first),
            ),
            if (mode == _AdminMode.constructor && draftName != null) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  isDraftFinalized ? '$draftName • baza taýýar' : draftName!,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (mode == _AdminMode.constructor) ...[
              if (canImportDocument)
                _ToolbarButton(
                  icon: Icons.description_outlined,
                  label: 'Resminamany Import etmek',
                  onPressed: isProcessing ? null : onImportDocument,
                ),
              if (canSaveAllParagraphs)
                _ToolbarButton(
                  icon: Icons.save_outlined,
                  label: 'Ähli abzaslary ýatda sakla',
                  onPressed: isProcessing ? null : onSaveAllParagraphs,
                ),
              if (canFinalize)
                _ToolbarButton(
                  icon: Icons.publish_outlined,
                  label: 'Resminamany Baza goş',
                  onPressed: isProcessing ? null : onFinalizeDocument,
                ),
              if (canShowRebuild) ...[
                _ToolbarButton(
                  icon: Icons.refresh_rounded,
                  label: 'Bazany täzele',
                  onPressed: isProcessing ? null : onRebuild,
                ),
                _ToolbarButton(
                  icon: Icons.upload_file_outlined,
                  label: 'Bazany import et',
                  onPressed: isProcessing ? null : onImportDatabase,
                ),
                _ToolbarButton(
                  icon: Icons.download_outlined,
                  label: 'Bazany eksport et',
                  onPressed: isProcessing ? null : onExportDatabase,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _EmptyConstructorState extends StatelessWidget {
  const _EmptyConstructorState({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined, size: 72, color: colors.primary),
            const SizedBox(height: 16),
            Text(
              'Word ýa-da Excel resminamasyny import ediň',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Abzaslar awtomatik ýagdaýda bölünýär. Soňra ähli abzaslary redaktirläp, resminamany baza goşuň.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParagraphExplorer extends StatelessWidget {
  const _ParagraphExplorer({
    required this.colors,
    required this.paragraphs,
    required this.selectedIndex,
    required this.onSelect,
  });

  final ColorScheme colors;
  final List<AdminParagraph> paragraphs;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Abzalar (${paragraphs.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: paragraphs.length,
              itemBuilder: (context, index) {
                final paragraph = paragraphs[index];
                final selected = selectedIndex == index;
                final preview = paragraph.text.trim().isEmpty
                    ? 'Boş abzas'
                    : paragraph.text.trim().replaceAll('\n', ' ');

                return ListTile(
                  selected: selected,
                  selectedTileColor: colors.primaryContainer.withValues(
                    alpha: 0.35,
                  ),
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: paragraph.isSaved
                        ? colors.primary
                        : colors.surfaceContainerHighest,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        color: paragraph.isSaved
                            ? colors.onPrimary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  title: Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  subtitle: Row(
                    children: [
                      if (paragraph.isSaved)
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: colors.primary,
                        ),
                      if (paragraph.isNews) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.campaign_outlined,
                          size: 14,
                          color: colors.tertiary,
                        ),
                      ],
                      if (paragraph.images.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.image_outlined,
                          size: 14,
                          color: colors.outline,
                        ),
                      ],
                      if (paragraph.videos.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.videocam_outlined,
                          size: 14,
                          color: colors.outline,
                        ),
                      ],
                      if (paragraph.audios.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.audiotrack_outlined,
                          size: 14,
                          color: colors.outline,
                        ),
                      ],
                    ],
                  ),
                  onTap: () => onSelect(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ParagraphEditor extends StatelessWidget {
  const _ParagraphEditor({
    required this.colors,
    required this.controller,
    required this.selectedIndex,
    required this.paragraph,
    required this.onChanged,
  });

  final ColorScheme colors;
  final TextEditingController controller;
  final int? selectedIndex;
  final AdminParagraph? paragraph;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (paragraph == null) {
      return Center(
        child: Text(
          'Abzas saýlaň',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Abzas ${(selectedIndex ?? 0) + 1}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: 'Abzas tekstini redaktirläň...',
                filled: true,
                fillColor: colors.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParagraphActions extends StatelessWidget {
  const _ParagraphActions({
    required this.colors,
    required this.paragraph,
    required this.isProcessing,
    required this.onAddImage,
    required this.onAddVideo,
    required this.onAddAudio,
    required this.onRemoveAudio,
    required this.onToggleNews,
    required this.onPickPreview,
    required this.onSaveParagraph,
  });

  final ColorScheme colors;
  final AdminParagraph? paragraph;
  final bool isProcessing;
  final VoidCallback onAddImage;
  final VoidCallback onAddVideo;
  final VoidCallback onAddAudio;
  final ValueChanged<String> onRemoveAudio;
  final ValueChanged<bool> onToggleNews;
  final VoidCallback onPickPreview;
  final VoidCallback onSaveParagraph;

  @override
  Widget build(BuildContext context) {
    final hasAudio = paragraph?.audios.isNotEmpty ?? false;

    return SizedBox(
      width: 300,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: paragraph == null
            ? Center(
                child: Text(
                  'Hereketler',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
            : ListView(
                children: [
                  Text(
                    'Hereketler',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 16),
                  _ActionButton(
                    label: 'Surat goş',
                    icon: Icons.add_photo_alternate_outlined,
                    isProcessing: isProcessing,
                    onPressed: onAddImage,
                  ),
                  const SizedBox(height: 10),
                  _ActionButton(
                    label: 'Wideo goş',
                    icon: Icons.video_library_outlined,
                    isProcessing: isProcessing,
                    onPressed: onAddVideo,
                  ),
                  if (!hasAudio) ...[
                    const SizedBox(height: 10),
                    _ActionButton(
                      label: 'Audio goş',
                      icon: Icons.audiotrack_outlined,
                      isProcessing: isProcessing,
                      onPressed: onAddAudio,
                    ),
                  ],
                  const SizedBox(height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Möhüm habar'),
                    subtitle: const Text(
                      'Möhüm habarlar Baş sahypadaky karuselde görünýär',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: paragraph!.isNews,
                    onChanged: isProcessing ? null : onToggleNews,
                  ),
                  if (paragraph!.isNews) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: isProcessing ? null : onPickPreview,
                        icon: const Icon(Icons.preview_outlined),
                        label: Text(
                          paragraph!.newsPreview == null
                              ? 'Preview suraty saýla *'
                              : 'Preview suraty üýtget',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Baş sahypadaky karusel üçin preview suraty hökmany.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (paragraph!.images.isNotEmpty ||
                      paragraph!.videos.isNotEmpty ||
                      paragraph!.audios.isNotEmpty ||
                      (paragraph!.isNews &&
                          (paragraph!.newsPreview ?? '').isNotEmpty))
                    AdminMediaPreviewGrid(
                      imageNames: paragraph!.images,
                      videoNames: paragraph!.videos,
                      audioNames: paragraph!.audios,
                      newsPreview: paragraph!.isNews
                          ? paragraph!.newsPreview
                          : null,
                      colors: colors,
                      onRemoveAudio: isProcessing ? null : onRemoveAudio,
                    ),
                  if (paragraph!.images.isNotEmpty ||
                      paragraph!.videos.isNotEmpty ||
                      paragraph!.audios.isNotEmpty ||
                      (paragraph!.isNews &&
                          (paragraph!.newsPreview ?? '').isNotEmpty))
                    const SizedBox(height: 16),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: isProcessing ? null : onSaveParagraph,
                    icon: const Icon(Icons.save_as_outlined),
                    label: const Text('Abzasy ýatda sakla'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isProcessing,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isProcessing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        onPressed: isProcessing ? null : onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
