import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_state.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../models/models.dart';

class ResourceFormScreen extends StatefulWidget {
  const ResourceFormScreen({super.key, this.resourceId});

  final String? resourceId;

  @override
  State<ResourceFormScreen> createState() => _ResourceFormScreenState();
}

class _ResourceFormScreenState extends State<ResourceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _author = TextEditingController();
  final _url = TextEditingController();
  ResourceType _type = ResourceType.pdf;
  PlatformFile? _file;
  bool _replaceFile = false;
  bool _busy = false;
  String? _error;
  List<Category> _categories = [];
  final Set<String> _selectedCats = {};
  Resource? _existing;

  bool get _isEdit => widget.resourceId != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final app = AppStateScope.of(context);
    _categories = await app.resources.categories();
    if (_isEdit) {
      _existing = await app.resources.get(widget.resourceId!);
      _title.text = _existing!.title;
      _description.text = _existing!.description ?? '';
      _author.text = _existing!.author ?? '';
      _url.text = _existing!.externalUrl ?? '';
      _type = _existing!.resourceType;
      _selectedCats.addAll(_existing!.categories.map((c) => c.id));
    }
    _loadedCats = true;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _author, _url]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFile() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: FileRules.allowedExtensions,
    );
    if (f == null) return;
    final len = await f.length() ?? 0;
    if (len > FileRules.maxFileSizeMb * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'File too large (max ${FileRules.maxFileSizeMb} MB).'),
        ));
      }
      return;
    }
    setState(() {
      _file = f;
      _replaceFile = true;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final app = AppStateScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final autoApprove = app.canApprove;
      if (_isEdit) {
        // Update path
        await app.resources.update(
          widget.resourceId!,
          title: _title.text.trim(),
          description: _description.text.trim(),
          author: _author.text.trim(),
          type: _type,
          externalUrl: _url.text.trim().isEmpty ? null : _url.text.trim(),
          file: _file,
          replaceFile: _replaceFile,
          categoryIds: _selectedCats.toList(),
        );
        messenger.showSnackBar(const SnackBar(
            content: Text('Resource updated.')));
      } else {
        await app.resources.create(
          title: _title.text.trim(),
          description: _description.text.trim(),
          author: _author.text.trim(),
          type: _type,
          externalUrl: _url.text.trim().isEmpty ? null : _url.text.trim(),
          file: _file,
          categoryIds: _selectedCats.toList(),
          autoApprove: autoApprove,
        );
        messenger.showSnackBar(SnackBar(
            content: Text(autoApprove
                ? 'Resource published.'
                : 'Resource submitted for approval.')));
        if (mounted) context.go(Routes.myUploads);
        return;
      }
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final isNew = !_isEdit;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Upload resource' : 'Edit resource'),
      ),
      body: !_initDone
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _title,
                          decoration:
                              const InputDecoration(labelText: 'Title *'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _author,
                          decoration: const InputDecoration(
                              labelText: 'Author (optional)'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _description,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: 'Description (optional)'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<ResourceType>(
                          initialValue: _type,
                          decoration:
                              const InputDecoration(labelText: 'Resource type *'),
                          items: [
                            for (final t in ResourceType.values)
                              DropdownMenuItem(value: t, child: Text(t.label)),
                          ],
                          onChanged: (v) =>
                              setState(() => _type = v ?? ResourceType.pdf),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        if (_type == ResourceType.link) ...[
                          TextFormField(
                            controller: _url,
                            decoration: const InputDecoration(
                              labelText: 'External URL *',
                              hintText: 'https://…',
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ] else ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.attach_file),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _file?.name ??
                                              _existing?.fileName ??
                                              'No file selected',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: _pickFile,
                                        icon: const Icon(Icons.upload),
                                        label: Text(
                                            _existing?.fileName == null || _replaceFile
                                                ? 'Choose file'
                                                : 'Replace file'),
                                      ),
                                    ],
                                  ),
                                  if (_file != null)
                                    FutureBuilder<int?>(
                                      future: _file!.length(),
                                      builder: (context, snap) => Text(
                                        '${formatBytes(snap.data)} · ${_file!.extension ?? ''}',
                                        style:
                                            Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ),
                                  if (isNew && _file == null)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text(
                                        'A file is required (or choose the Link type).',
                                        style: TextStyle(color: Colors.redAccent),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (_categories.isNotEmpty) ...[
                          Text('Categories',
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final c in _categories)
                                FilterChip(
                                  label: Text('${c.type}: ${c.name}'),
                                  selected: _selectedCats.contains(c.id),
                                  onSelected: (v) => setState(() {
                                    v ? _selectedCats.add(c.id)
                                     : _selectedCats.remove(c.id);
                                  }),
                                ),
                            ],
                          ),
                        ],
                        if (!isNew && app.canApprove) ...[
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Replace file (creates a new version)'),
                            value: _replaceFile,
                            onChanged: (v) => setState(() => _replaceFile = v),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!,
                              style: const TextStyle(color: Colors.redAccent)),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _busy ? null : _submit,
                          icon: _busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.save_outlined),
                          label: Text(isNew ? 'Submit' : 'Save changes'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  bool get _initDone => _isEdit ? _existing != null : _loadedCats;
  bool _loadedCats = false;
}
