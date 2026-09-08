import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/admin_document_service.dart';
import '../../core/admin_messages.dart';
import '../../core/ai_server_service.dart';
import '../../core/app_constants.dart';
import '../../core/models/admin_paragraph.dart';
import '../../core/models/kb_stats.dart';
import 'admin_confirm_dialog.dart';
import 'admin_media_preview.dart';

enum _KbMediaType { image, video, audio }

class AdminKbPanel extends StatefulWidget {
  const AdminKbPanel({
    super.key,
    required this.colors,
    required this.onToast,
    required this.onDirtyChanged,
    required this.onProcessingChanged,
  });

  final ColorScheme colors;
  final void Function(String message, {bool error}) onToast;
  final ValueChanged<bool> onDirtyChanged;
  final ValueChanged<bool> onProcessingChanged;

  @override
  State<AdminKbPanel> createState() => AdminKbPanelState();
}

class AdminKbPanelState extends State<AdminKbPanel> {
  final AdminDocumentService _documentService = AdminDocumentService();
  final AiServerService _serverService = AiServerService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _editorController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _editorFocus = FocusNode();
  Timer? _searchDebounce;

  List<AdminParagraph> _allParagraphs = [];
  List<AdminParagraph> _visible = [];
  KbStats _stats = KbStats.empty;
  String? _selectedKey;
  bool _newsOnly = false;
  bool _isLoading = true;
  bool _isProcessing = false;
  final Set<String> _selectedExportKeys = {};

  bool get hasUnsavedChanges => _allParagraphs.any((p) => !p.isSaved);

  AdminParagraph? get _selected {
    final key = _selectedKey;
    if (key == null) return null;
    for (final paragraph in _allParagraphs) {
      if (_keyOf(paragraph) == key) return paragraph;
    }
    return null;
  }

  String _keyOf(AdminParagraph paragraph) =>
      '${paragraph.source ?? ''}#${paragraph.index}';

  @override
  void initState() {
    super.initState();
    _loadParagraphs();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _editorController.dispose();
    _searchFocus.dispose();
    _editorFocus.dispose();
    super.dispose();
  }

  Future<void> _ensureServer() async {
    await _serverService.ensureRunning();
  }

  void _setProcessing(bool value) {
    _isProcessing = value;
    widget.onProcessingChanged(value);
    if (mounted) setState(() {});
  }

  void _notifyDirty() {
    widget.onDirtyChanged(hasUnsavedChanges);
  }

  void _applyEditorToSelected() {
    final selected = _selected;
    if (selected == null) return;
    final nextText = _editorController.text;
    if (selected.text != nextText) {
      selected.text = nextText;
      selected.isSaved = false;
      _notifyDirty();
    }
  }

  void _syncEditorFromSelection() {
    final selected = _selected;
    _editorController.text = selected?.text ?? '';
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (hasUnsavedChanges) {
        widget.onToast('Ilki üýtgetmeleri ýazyň.', error: true);
        return;
      }
      _loadParagraphs(preferKey: _selectedKey);
    });
  }

  Future<void> _runSearchNow() async {
    _searchDebounce?.cancel();
    if (hasUnsavedChanges) {
      widget.onToast('Ilki üýtgetmeleri ýazyň.', error: true);
      return;
    }
    await _loadParagraphs(preferKey: _selectedKey);
  }

  Future<void> _loadParagraphs({String? preferKey}) async {
    setState(() => _isLoading = true);
    try {
      await _ensureServer();
      final result = await _documentService.listKbParagraphs(
        query: _searchController.text.trim(),
        newsOnly: _newsOnly,
      );
      if (!mounted) return;
      setState(() {
        _allParagraphs = result.paragraphs;
        _stats = result.stats;
        _visible = List<AdminParagraph>.from(_allParagraphs);
        _isLoading = false;
        if (_allParagraphs.isEmpty) {
          _selectedKey = null;
        } else {
          final prefer = preferKey;
          final stillExists = prefer != null &&
              _allParagraphs.any((p) => _keyOf(p) == prefer);
          _selectedKey = stillExists ? prefer : _keyOf(_allParagraphs.first);
        }
      });
      _syncEditorFromSelection();
      _notifyDirty();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      widget.onToast(AdminMessages.friendlyError(e), error: true);
    }
  }

  void _selectParagraph(AdminParagraph paragraph) {
    _applyEditorToSelected();
    setState(() => _selectedKey = _keyOf(paragraph));
    _syncEditorFromSelection();
  }

  Future<void> _saveCurrent() async {
    _applyEditorToSelected();
    final selected = _selected;
    if (selected == null || selected.source == null) return;

    if (selected.text.trim().isEmpty) {
      widget.onToast('Abzas boş bolup bilmez.', error: true);
      return;
    }
    if (selected.isNews && (selected.newsPreview ?? '').isEmpty) {
      widget.onToast('Möhüm habar üçin preview suraty hökmany.', error: true);
      return;
    }

    _setProcessing(true);
    try {
      await _ensureServer();
      final updated = await _documentService.updateKbParagraph(selected);
      final key = _keyOf(updated);
      await _loadParagraphs(preferKey: key);
      widget.onToast('Abzas ýazyldy.');
    } catch (e) {
      widget.onToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> _saveAllDirty() async {
    _applyEditorToSelected();
    final dirty = _allParagraphs.where((p) => !p.isSaved).toList();
    if (dirty.isEmpty) {
      widget.onToast('Ýazylmadyk üýtgetme ýok.');
      return;
    }

    for (final paragraph in dirty) {
      if (paragraph.text.trim().isEmpty) {
        widget.onToast('Boş abzas bar — ilki düzediň.', error: true);
        return;
      }
      if (paragraph.isNews && (paragraph.newsPreview ?? '').isEmpty) {
        widget.onToast('Möhüm habar üçin preview hökmany.', error: true);
        return;
      }
    }

    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Ähli üýtgetmeleri ýaz',
      message: '${dirty.length} abzas faýllara ýazylar. Dowam etmeli mi?',
      confirmLabel: 'Ýaz',
    );
    if (!confirmed || !mounted) return;

    _setProcessing(true);
    try {
      await _ensureServer();
      for (final paragraph in dirty) {
        await _documentService.updateKbParagraph(paragraph);
      }
      await _loadParagraphs(preferKey: _selectedKey);
      widget.onToast('${dirty.length} abzas ýazyldy.');
    } catch (e) {
      widget.onToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> rebuildDatabase() async {
    if (hasUnsavedChanges) {
      widget.onToast('Ilki üýtgetmeleri ýazyň.', error: true);
      return;
    }

    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Bazany täzele',
      message:
          'Awto-backup edilip, gözleg bazasy täzeden gurlar. Birnäçe minut alýar.',
      confirmLabel: 'Täzele',
    );
    if (!confirmed || !mounted) return;

    _setProcessing(true);
    try {
      await _ensureServer();
      final result = await _documentService.rebuildDatabase();
      final backup = result['backup']?.toString();
      if (backup != null && backup.isNotEmpty) {
        widget.onToast('Backup: $backup. Baza täzelenýär...');
      } else {
        widget.onToast('Maglumat bazasy täzelenýär...');
      }
      await Future<void>.delayed(const Duration(seconds: 2));
      await _loadParagraphs(preferKey: _selectedKey);
      if (_stats.newsCount == 0) {
        widget.onToast(
          'Karusel üçin abzasy Möhüm habar edip preview saýlaň.',
        );
      }
    } catch (e) {
      widget.onToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> _addParagraph() async {
    final selected = _selected;
    final source = selected?.source ??
        (_stats.sources.isNotEmpty ? _stats.sources.first : null);
    if (source == null) {
      widget.onToast('Ilki .txt faýl gerek.', error: true);
      return;
    }
    if (hasUnsavedChanges) {
      widget.onToast('Ilki üýtgetmeleri ýazyň.', error: true);
      return;
    }

    _setProcessing(true);
    try {
      await _ensureServer();
      final list = await _documentService.addKbParagraph(
        source: source,
        afterIndex: selected?.index ?? -1,
      );
      final inserted = list.isNotEmpty
          ? list[(((selected?.index ?? -1) + 1).clamp(0, list.length - 1))]
          : null;
      await _loadParagraphs(
        preferKey: inserted == null ? null : _keyOf(inserted),
      );
      widget.onToast('Täze abzas goşuldy.');
    } catch (e) {
      widget.onToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> _deleteParagraph() async {
    final selected = _selected;
    if (selected == null || selected.source == null) return;
    if (hasUnsavedChanges) {
      widget.onToast('Ilki üýtgetmeleri ýazyň.', error: true);
      return;
    }

    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Abzasy öçür',
      message: 'Bu abzas faýldan öçüriler. Dowam etmeli mi?',
      confirmLabel: 'Öçür',
    );
    if (!confirmed || !mounted) return;

    _setProcessing(true);
    try {
      await _ensureServer();
      await _documentService.deleteKbParagraph(
        source: selected.source!,
        index: selected.index,
      );
      await _loadParagraphs();
      widget.onToast('Abzas öçürildi.');
    } catch (e) {
      widget.onToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> _duplicateParagraph() async {
    final selected = _selected;
    if (selected == null || selected.source == null) return;
    if (hasUnsavedChanges) {
      widget.onToast('Ilki üýtgetmeleri ýazyň.', error: true);
      return;
    }

    _setProcessing(true);
    try {
      await _ensureServer();
      final list = await _documentService.duplicateKbParagraph(
        source: selected.source!,
        index: selected.index,
      );
      final cloneIndex = (selected.index + 1).clamp(0, list.length - 1);
      await _loadParagraphs(
        preferKey: list.isEmpty ? null : _keyOf(list[cloneIndex]),
      );
      widget.onToast('Abzas göçürildi.');
    } catch (e) {
      widget.onToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> _exportSelected() async {
    _applyEditorToSelected();
    var toExport = _allParagraphs
        .where((p) => _selectedExportKeys.contains(_keyOf(p)))
        .toList();
    if (toExport.isEmpty) {
      final selected = _selected;
      if (selected != null) {
        toExport = [selected];
      }
    }
    if (toExport.isEmpty) {
      widget.onToast('Eksport üçin abzas saýlaň.', error: true);
      return;
    }

    final savePath = await FilePicker.saveFile(
      dialogTitle: 'Abzaslary eksport et',
      fileName: 'paragraphs_export.txt',
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (savePath == null) return;

    _setProcessing(true);
    try {
      await _ensureServer();
      final text = await _documentService.exportKbParagraphsText(toExport);
      final normalized =
          savePath.toLowerCase().endsWith('.txt') ? savePath : '$savePath.txt';
      await File(normalized).writeAsString(text, encoding: utf8);
      widget.onToast('${toExport.length} abzas eksport edildi.');
    } catch (e) {
      widget.onToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> _addMedia(_KbMediaType type) async {
    final selected = _selected;
    if (selected == null) {
      widget.onToast('Ilki abzas saýlaň.', error: true);
      return;
    }
    if (type == _KbMediaType.audio && selected.audios.isNotEmpty) {
      widget.onToast('Bir abzasda diňe 1 audio bolup bilýär.', error: true);
      return;
    }

    final allowed = switch (type) {
      _KbMediaType.video => AppConstants.allowedVideoExtensions,
      _KbMediaType.audio => AppConstants.allowedAudioExtensions,
      _KbMediaType.image => AppConstants.allowedImageExtensions,
    };

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowed,
    );
    if (result == null || result.files.single.path == null) return;

    _setProcessing(true);
    try {
      await _ensureServer();
      final file = result.files.single;
      final filename = await _documentService.uploadMedia(file.path!, file.name);
      setState(() {
        if (type == _KbMediaType.video) {
          selected.videos = [...selected.videos, filename];
        } else if (type == _KbMediaType.audio) {
          selected.audios = [filename];
        } else {
          selected.images = [...selected.images, filename];
        }
        selected.isSaved = false;
      });
      _notifyDirty();
      widget.onToast('Mediýa goşuldy.');
    } catch (e) {
      widget.onToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> _pickPreview() async {
    final selected = _selected;
    if (selected == null) return;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.allowedImageExtensions,
    );
    if (result == null || result.files.single.path == null) return;

    _setProcessing(true);
    try {
      await _ensureServer();
      final file = result.files.single;
      final filename = await _documentService.uploadMedia(file.path!, file.name);
      setState(() {
        selected.newsPreview = filename;
        selected.isSaved = false;
      });
      _notifyDirty();
      widget.onToast('Preview suraty saýlandy.');
    } catch (e) {
      widget.onToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      _setProcessing(false);
    }
  }

  void _toggleNews(bool value) {
    final selected = _selected;
    if (selected == null) return;
    setState(() {
      selected.isNews = value;
      if (!value) {
        selected.newsPreview = null;
        selected.newsOrder = null;
      } else if (selected.newsOrder == null) {
        final maxOrder = _allParagraphs
            .where((p) => p.isNews && p.newsOrder != null)
            .map((p) => p.newsOrder!)
            .fold<int>(0, (a, b) => a > b ? a : b);
        selected.newsOrder = maxOrder + 1;
      }
      selected.isSaved = false;
    });
    _notifyDirty();
  }

  void _removeAudio(String name) {
    final selected = _selected;
    if (selected == null) return;
    setState(() {
      selected.audios = selected.audios.where((item) => item != name).toList();
      selected.isSaved = false;
    });
    _notifyDirty();
  }

  void _removeImage(String name) {
    final selected = _selected;
    if (selected == null) return;
    setState(() {
      selected.images = selected.images.where((item) => item != name).toList();
      selected.isSaved = false;
    });
    _notifyDirty();
  }

  void _removeVideo(String name) {
    final selected = _selected;
    if (selected == null) return;
    setState(() {
      selected.videos = selected.videos.where((item) => item != name).toList();
      selected.isSaved = false;
    });
    _notifyDirty();
  }

  void _removeNewsPreview() {
    final selected = _selected;
    if (selected == null) return;
    setState(() {
      selected.newsPreview = null;
      selected.isSaved = false;
    });
    _notifyDirty();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _visible.length) return;
    final moved = _visible[oldIndex];
    if (!moved.isNews) return;

    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _visible.removeAt(oldIndex);
      _visible.insert(newIndex, item);

      var order = 1;
      for (final paragraph in _visible) {
        if (!paragraph.isNews) continue;
        paragraph.newsOrder = order++;
        paragraph.isSaved = false;
      }
    });
    _notifyDirty();

    _setProcessing(true);
    try {
      await _ensureServer();
      for (final paragraph in _visible.where((p) => p.isNews)) {
        await _documentService.updateKbParagraph(paragraph);
      }
      await _loadParagraphs(preferKey: _selectedKey);
      widget.onToast('Karusel tertibi ýazyldy.');
    } catch (e) {
      widget.onToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      _setProcessing(false);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    if (!isCtrl) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.keyS) {
      _saveCurrent();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyF) {
      _searchFocus.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildParagraphList() {
    if (_visible.isEmpty) {
      return Center(
        child: Text(
          'Abzas tapylmady',
          style: TextStyle(color: widget.colors.onSurfaceVariant),
        ),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: _visible.length,
      onReorder: (oldIndex, newIndex) {
        if (_isProcessing) return;
        _onReorder(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final paragraph = _visible[index];
        final key = ValueKey(_keyOf(paragraph));
        return _KbParagraphTile(
          key: key,
          colors: widget.colors,
          paragraph: paragraph,
          index: index,
          selected: _selectedKey == _keyOf(paragraph),
          exportSelected: _selectedExportKeys.contains(_keyOf(paragraph)),
          onSelect: () => _selectParagraph(paragraph),
          onToggleExport: (value) {
            setState(() {
              final itemKey = _keyOf(paragraph);
              if (value) {
                _selectedExportKeys.add(itemKey);
              } else {
                _selectedExportKeys.remove(itemKey);
              }
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        children: [
          _KbStatsBar(
            colors: widget.colors,
            stats: _stats,
            newsOnly: _newsOnly,
            onToggleNewsOnly: (value) async {
              if (hasUnsavedChanges) {
                widget.onToast('Ilki üýtgetmeleri ýazyň.', error: true);
                return;
              }
              setState(() => _newsOnly = value);
              await _loadParagraphs(preferKey: _selectedKey);
            },
            onSaveAll: _isProcessing ? null : _saveAllDirty,
            onRebuild: _isProcessing ? null : rebuildDatabase,
            onExport: _isProcessing ? null : _exportSelected,
            onAdd: _isProcessing ? null : _addParagraph,
            onRefresh: _isProcessing
                ? null
                : () {
                    if (hasUnsavedChanges) {
                      widget.onToast('Ilki üýtgetmeleri ýazyň.', error: true);
                      return;
                    }
                    _loadParagraphs(preferKey: _selectedKey);
                  },
          ),
          if (_stats.newsCount == 0)
            Material(
              color: widget.colors.tertiaryContainer.withValues(alpha: 0.55),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      size: 18,
                      color: widget.colors.onTertiaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Karusel üçin abzasy Möhüm habar edip preview saýlaň. Tertibi süýräp üýtgedip bilersiňiz.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: widget.colors.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: [
                      SizedBox(
                        width: 300,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocus,
                                decoration: InputDecoration(
                                  hintText: 'Abzas boýunça gözle...',
                                  prefixIcon: const Icon(Icons.search, size: 20),
                                  suffixIcon: _searchController.text.isEmpty
                                      ? null
                                      : IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            if (hasUnsavedChanges) {
                                              widget.onToast(
                                                'Ilki üýtgetmeleri ýazyň.',
                                                error: true,
                                              );
                                              return;
                                            }
                                            _searchController.clear();
                                            setState(() {});
                                            _runSearchNow();
                                          },
                                        ),
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onSubmitted: (_) => _runSearchNow(),
                                onChanged: (_) {
                                  setState(() {});
                                  _scheduleSearch();
                                },
                              ),
                            ),
                            Expanded(child: _buildParagraphList()),
                          ],
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        color: widget.colors.outlineVariant,
                      ),
                      Expanded(
                        child: selected == null
                            ? Center(
                                child: Text(
                                  'Abzas saýlaň',
                                  style: TextStyle(
                                    color: widget.colors.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      '${selected.source} • abzas ${selected.index + 1}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    if (selected.missingMedia.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Ýitirimli mediýa: ${selected.missingMedia.join(', ')}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: widget.colors.error,
                                            ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _editorController,
                                        focusNode: _editorFocus,
                                        onChanged: (_) {
                                          final current = _selected;
                                          if (current != null) {
                                            current.isSaved = false;
                                            _notifyDirty();
                                            setState(() {});
                                          }
                                        },
                                        maxLines: null,
                                        expands: true,
                                        textAlignVertical:
                                            TextAlignVertical.top,
                                        decoration: InputDecoration(
                                          hintText:
                                              'Abzas tekstini redaktirläň...',
                                          filled: true,
                                          fillColor: widget
                                              .colors
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.45),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      VerticalDivider(
                        width: 1,
                        color: widget.colors.outlineVariant,
                      ),
                      SizedBox(
                        width: 300,
                        child: selected == null
                            ? const SizedBox.shrink()
                            : ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  Text(
                                    'Hereketler',
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    onPressed: _isProcessing
                                        ? null
                                        : () => _addMedia(_KbMediaType.image),
                                    icon: const Icon(
                                      Icons.add_photo_alternate_outlined,
                                    ),
                                    label: const Text('Surat goş'),
                                  ),
                                  const SizedBox(height: 8),
                                  FilledButton.icon(
                                    onPressed: _isProcessing
                                        ? null
                                        : () => _addMedia(_KbMediaType.video),
                                    icon: const Icon(
                                      Icons.video_library_outlined,
                                    ),
                                    label: const Text('Wideo goş'),
                                  ),
                                  if (selected.audios.isEmpty) ...[
                                    const SizedBox(height: 8),
                                    FilledButton.icon(
                                      onPressed: _isProcessing
                                          ? null
                                          : () => _addMedia(_KbMediaType.audio),
                                      icon: const Icon(
                                        Icons.audiotrack_outlined,
                                      ),
                                      label: const Text('Audio goş'),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Möhüm habar'),
                                    subtitle: const Text(
                                      'Baş sahypadaky karusel — tertibi çep sanawda süýräň',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    value: selected.isNews,
                                    onChanged:
                                        _isProcessing ? null : _toggleNews,
                                  ),
                                  if (selected.isNews) ...[
                                    OutlinedButton.icon(
                                      onPressed:
                                          _isProcessing ? null : _pickPreview,
                                      icon: const Icon(Icons.preview_outlined),
                                      label: Text(
                                        selected.newsPreview == null
                                            ? 'Preview suraty saýla *'
                                            : 'Preview suraty üýtget',
                                      ),
                                    ),
                                    if (selected.newsOrder != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Karusel tertibi: ${selected.newsOrder}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: widget
                                                  .colors
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ],
                                  const SizedBox(height: 12),
                                  if (selected.images.isNotEmpty ||
                                      selected.videos.isNotEmpty ||
                                      selected.audios.isNotEmpty ||
                                      (selected.isNews &&
                                          (selected.newsPreview ?? '')
                                              .isNotEmpty))
                                    AdminMediaPreviewGrid(
                                      imageNames: selected.images,
                                      videoNames: selected.videos,
                                      audioNames: selected.audios,
                                      newsPreview: selected.isNews
                                          ? selected.newsPreview
                                          : null,
                                      colors: widget.colors,
                                      onRemoveAudio:
                                          _isProcessing ? null : _removeAudio,
                                      onRemoveImage:
                                          _isProcessing ? null : _removeImage,
                                      onRemoveVideo:
                                          _isProcessing ? null : _removeVideo,
                                      onRemoveNewsPreview: _isProcessing
                                          ? null
                                          : _removeNewsPreview,
                                    ),
                                  const SizedBox(height: 12),
                                  FilledButton.tonalIcon(
                                    onPressed:
                                        _isProcessing ? null : _saveCurrent,
                                    icon: const Icon(Icons.save_as_outlined),
                                    label: const Text('Abzasy ýatda sakla'),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: _isProcessing
                                        ? null
                                        : _duplicateParagraph,
                                    icon: const Icon(Icons.copy_outlined),
                                    label: const Text('Abzasy göçür'),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed:
                                        _isProcessing ? null : _deleteParagraph,
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: widget.colors.error,
                                    ),
                                    label: Text(
                                      'Abzasy öçür',
                                      style: TextStyle(
                                        color: widget.colors.error,
                                      ),
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
    );
  }
}

class _KbStatsBar extends StatelessWidget {
  const _KbStatsBar({
    required this.colors,
    required this.stats,
    required this.newsOnly,
    required this.onToggleNewsOnly,
    required this.onSaveAll,
    required this.onRebuild,
    required this.onExport,
    required this.onAdd,
    required this.onRefresh,
  });

  final ColorScheme colors;
  final KbStats stats;
  final bool newsOnly;
  final ValueChanged<bool> onToggleNewsOnly;
  final VoidCallback? onSaveAll;
  final VoidCallback? onRebuild;
  final VoidCallback? onExport;
  final VoidCallback? onAdd;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Text(
              'Abzas: ${stats.paragraphCount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: 12),
            Text(
              'Möhüm: ${stats.newsCount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: 12),
            Text(
              'Mediýa: ${stats.mediaRefs}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (stats.missingMedia > 0) ...[
              const SizedBox(width: 12),
              Text(
                'Ýitirimli: ${stats.missingMedia}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.error,
                ),
              ),
            ],
            const SizedBox(width: 16),
            FilterChip(
              label: const Text('Diňe möhüm'),
              selected: newsOnly,
              onSelected: onToggleNewsOnly,
              visualDensity: VisualDensity.compact,
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Täzele',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 20),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Abzas goş'),
            ),
            TextButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('Eksport'),
            ),
            TextButton.icon(
              onPressed: onSaveAll,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Ählisini ýaz'),
            ),
            FilledButton.tonalIcon(
              onPressed: onRebuild,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Bazany täzele'),
            ),
          ],
        ),
      ),
    );
  }
}

class _KbParagraphTile extends StatelessWidget {
  const _KbParagraphTile({
    super.key,
    required this.colors,
    required this.paragraph,
    required this.index,
    required this.selected,
    required this.exportSelected,
    required this.onSelect,
    required this.onToggleExport,
  });

  final ColorScheme colors;
  final AdminParagraph paragraph;
  final int index;
  final bool selected;
  final bool exportSelected;
  final VoidCallback onSelect;
  final ValueChanged<bool> onToggleExport;

  @override
  Widget build(BuildContext context) {
    final preview = paragraph.text.trim().isEmpty
        ? 'Boş abzas'
        : paragraph.text.trim().replaceAll('\n', ' ');

    return ListTile(
      selected: selected,
      selectedTileColor: colors.primaryContainer.withValues(alpha: 0.35),
      dense: true,
      leading: Checkbox(
        value: exportSelected,
        onChanged: (value) => onToggleExport(value ?? false),
      ),
      title: Text(
        preview,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      subtitle: Row(
        children: [
          if ((paragraph.source ?? '').isNotEmpty)
            Flexible(
              child: Text(
                paragraph.source!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          if (!paragraph.isSaved) ...[
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 14, color: colors.tertiary),
          ],
          if (paragraph.isNews) ...[
            const SizedBox(width: 4),
            Icon(Icons.campaign_outlined, size: 14, color: colors.tertiary),
            if (paragraph.newsOrder != null) ...[
              const SizedBox(width: 2),
              Text(
                '#${paragraph.newsOrder}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.tertiary,
                ),
              ),
            ],
          ],
          if (paragraph.missingMedia.isNotEmpty) ...[
            const SizedBox(width: 4),
            Icon(Icons.warning_amber_rounded, size: 14, color: colors.error),
          ],
        ],
      ),
      trailing: paragraph.isNews
          ? ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle_rounded,
                color: colors.onSurfaceVariant,
              ),
            )
          : null,
      onTap: onSelect,
    );
  }
}
