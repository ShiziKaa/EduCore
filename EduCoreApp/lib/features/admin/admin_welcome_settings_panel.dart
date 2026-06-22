import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/admin_messages.dart';
import '../../core/models/welcome_settings.dart';
import '../../core/services/welcome_settings_service.dart';

class AdminWelcomeSettingsPanel extends StatefulWidget {
  const AdminWelcomeSettingsPanel({
    super.key,
    required this.colors,
    required this.onSaved,
    required this.onToast,
    required this.onImportLogo,
    this.instituteLogo,
  });

  final ColorScheme colors;
  final VoidCallback onSaved;
  final void Function(String message, {bool error}) onToast;
  final Future<void> Function() onImportLogo;
  final File? instituteLogo;

  @override
  State<AdminWelcomeSettingsPanel> createState() =>
      _AdminWelcomeSettingsPanelState();
}

class _AdminWelcomeSettingsPanelState extends State<AdminWelcomeSettingsPanel> {
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final List<TextEditingController> _tagControllers = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await WelcomeSettingsService.load();
    if (!mounted) return;

    _titleController.text = settings.title;
    _subtitleController.text = settings.subtitle;
    _setTagControllers(settings.quickTags);
    setState(() => _loading = false);
  }

  void _setTagControllers(List<String> tags) {
    for (final controller in _tagControllers) {
      controller.dispose();
    }
    _tagControllers
      ..clear()
      ..addAll(tags.map((tag) => TextEditingController(text: tag)));
  }

  void _addTag() {
    setState(() => _tagControllers.add(TextEditingController()));
  }

  void _removeTag(int index) {
    setState(() {
      _tagControllers[index].dispose();
      _tagControllers.removeAt(index);
    });
  }

  WelcomeSettings _collectSettings() {
    return WelcomeSettings(
      title: _titleController.text.trim(),
      subtitle: _subtitleController.text.trim(),
      quickTags: _tagControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList(),
    );
  }

  Future<void> _save() async {
    final settings = _collectSettings();
    if (settings.title.isEmpty || settings.subtitle.isEmpty) {
      widget.onToast('Salgylanma we düşündiriş boş bolup bilmez.', error: true);
      return;
    }

    setState(() => _saving = true);

    try {
      await WelcomeSettingsService.save(settings);
      widget.onToast('Baş sahypa üstünlikli ýazyldy.');
      widget.onSaved();
    } catch (e) {
      widget.onToast(AdminMessages.friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetDefaults() async {
    _titleController.text = WelcomeSettings.defaults.title;
    _subtitleController.text = WelcomeSettings.defaults.subtitle;
    setState(() {
      _setTagControllers(WelcomeSettings.defaults.quickTags);
    });
    widget.onToast('Standart tekstler ýüklendi. Ýazmak üçin «Sakla» basyň.');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    for (final controller in _tagControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            children: [
              Text(
                'Baş sahypanyň tekstleri',
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Logo, salamlaşma, düşündiriş we çip tekstlerini redaktirläň.',
                style: textTheme.bodyMedium?.copyWith(
                  color: widget.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.instituteLogo != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          widget.instituteLogo!,
                          width: 120,
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                      )
                    else
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.colors.outline.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          color: widget.colors.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : widget.onImportLogo,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Institut logosyny goş'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Salamlaşma',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _subtitleController,
                decoration: const InputDecoration(
                  labelText: 'Düşündiriş',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Text(
                    'Çipler (${_tagControllers.length})',
                    style: textTheme.titleMedium,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _saving ? null : _addTag,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Çip goş'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_tagControllers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Çip ýok. «Çip goş» basyň.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: widget.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ...List.generate(_tagControllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagControllers[index],
                          decoration: InputDecoration(
                            labelText: 'Çip ${index + 1}',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _saving ? null : () => _removeTag(index),
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: 'Poz',
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: widget.colors.onPrimary,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Sakla'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _resetDefaults,
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Standart'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
