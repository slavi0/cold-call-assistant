import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/contact_field.dart';
import '../models/contact_source.dart';
import '../models/contact_source_test_result.dart';
import '../providers/contact_source_provider.dart';

/// Form screen for creating or editing a [GoogleSheetsSource] configuration.
///
/// **Route argument**: an existing [GoogleSheetsSource] to edit, or `null`
/// to create a new source.
///
/// The form collects:
/// - A display name for the source.
/// - The spreadsheet URL and worksheet (tab) name.
/// - A column mapping: one text field per [ContactField] mapping the field
///   to a spreadsheet column letter (A, B, C, ...).
///
/// ## Phase 2 notes
/// The "Test Connection" button currently calls a placeholder that returns
/// [ContactSourceTestResult.notImplemented]. When the Google Sheets API is
/// integrated, only [ContactSourceProvider.testSource] needs to be updated —
/// this screen does not need to change.
class GoogleSheetsConfigScreen extends StatefulWidget {
  const GoogleSheetsConfigScreen({super.key});

  @override
  State<GoogleSheetsConfigScreen> createState() =>
      _GoogleSheetsConfigScreenState();
}

class _GoogleSheetsConfigScreenState
    extends State<GoogleSheetsConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _urlController = TextEditingController();
  final _worksheetController = TextEditingController();

  // One controller per ContactField, so new fields are picked up automatically.
  late final Map<ContactField, TextEditingController> _mappingControllers;

  GoogleSheetsSource? _existingSource;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;

      // Allocate a controller for every ContactField.
      _mappingControllers = {
        for (final field in ContactField.values)
          field: TextEditingController(),
      };

      // Pre-populate if editing an existing source.
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is GoogleSheetsSource) {
        _existingSource = args;
        _displayNameController.text = args.displayName;
        _urlController.text = args.spreadsheetUrl;
        _worksheetController.text = args.worksheetName;
        for (final entry in args.columnMapping.entries) {
          _mappingControllers[entry.key]?.text = entry.value;
        }
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _urlController.dispose();
    _worksheetController.dispose();
    for (final c in _mappingControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isEditing => _existingSource != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Google Sheets' : 'New Google Sheets Source',
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _SectionHeader(
              icon: Icons.badge_rounded,
              label: 'Source Details',
            ),
            const SizedBox(height: 12),
            _buildDisplayNameField(),
            const SizedBox(height: 24),
            _SectionHeader(
              icon: Icons.table_chart_rounded,
              label: 'Spreadsheet',
            ),
            const SizedBox(height: 12),
            _buildUrlField(),
            const SizedBox(height: 16),
            _buildWorksheetField(),
            const SizedBox(height: 28),
            _SectionHeader(
              icon: Icons.swap_horiz_rounded,
              label: 'Column Mapping',
            ),
            const SizedBox(height: 6),
            Text(
              'Enter the spreadsheet column letter (A, B, C…) '
              'that contains each contact field.\n'
              'Fields marked with • are required.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 16),
            ..._buildColumnMappingRows(),
            const SizedBox(height: 32),
            _buildActionButtons(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Form fields ─────────────────────────────────────────────────────────────

  Widget _buildDisplayNameField() {
    return TextFormField(
      controller: _displayNameController,
      decoration: const InputDecoration(
        labelText: 'Source name',
        hintText: 'e.g. Q3 Leads',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.label_rounded),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Please enter a name.' : null,
    );
  }

  Widget _buildUrlField() {
    return TextFormField(
      controller: _urlController,
      decoration: const InputDecoration(
        labelText: 'Spreadsheet URL',
        hintText: 'https://docs.google.com/spreadsheets/d/…',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.link_rounded),
      ),
      keyboardType: TextInputType.url,
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return 'Please enter the spreadsheet URL.';
        }
        final uri = Uri.tryParse(v.trim());
        if (uri == null || !uri.hasScheme) {
          return 'Please enter a valid URL.';
        }
        return null;
      },
    );
  }

  Widget _buildWorksheetField() {
    return TextFormField(
      controller: _worksheetController,
      decoration: const InputDecoration(
        labelText: 'Worksheet (tab) name',
        hintText: 'e.g. Sheet1',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.tab_rounded),
      ),
      validator: (v) => (v == null || v.trim().isEmpty)
          ? 'Please enter the worksheet name.'
          : null,
    );
  }

  List<Widget> _buildColumnMappingRows() {
    // Renders one row per ContactField. Because the list is derived from the
    // enum, new fields automatically appear here without UI changes.
    return ContactField.values.map((field) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            SizedBox(
              width: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (field.isRequired)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 6, top: 1),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    )
                  else
                    const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      field.displayLabel,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _mappingControllers[field],
                decoration: const InputDecoration(
                  labelText: 'Column',
                  hintText: 'A',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 3,
                // Only required fields produce a validation error; optional
                // fields are skipped if left blank.
                validator: field.isRequired
                    ? (v) => (v == null || v.trim().isEmpty)
                        ? 'Required'
                        : null
                    : null,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ── Action buttons ──────────────────────────────────────────────────────────

  Widget _buildActionButtons(BuildContext context) {
    return Consumer<ContactSourceProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed:
                  provider.isTesting ? null : () => _testConnection(context),
              icon: provider.isTesting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering_rounded),
              label: Text(
                provider.isTesting ? 'Testing…' : 'Test Connection',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _save(context),
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Handlers ────────────────────────────────────────────────────────────────

  Future<void> _testConnection(BuildContext context) async {
    // Build the source from the current form state without requiring valid
    // required fields — the user may want to test before completing the form.
    final source = _buildSourceUnvalidated(context);
    if (source == null) return;

    final provider = context.read<ContactSourceProvider>();
    // Capture messenger before the async gap so the context is not used
    // after the await when the widget tree may have changed.
    final messenger = ScaffoldMessenger.of(context);

    final result = await provider.testSource(source);

    if (!mounted) return;

    final (message, color) = switch (result) {
      ContactSourceTestResult.success => (
          'Connection successful!',
          Colors.green,
        ),
      ContactSourceTestResult.failed => (
          'Connection failed. Please check your settings.',
          Colors.red,
        ),
      ContactSourceTestResult.notImplemented => (
          'Test connection is not yet available for Google Sheets. '
              'It will be enabled when the import feature is added.',
          Colors.orange,
        ),
    };

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final source = _buildSourceFromForm(context);
    final provider = context.read<ContactSourceProvider>();
    // Capture refs before the async gap.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_isEditing) {
      await provider.updateSource(source);
    } else {
      await provider.addSource(source);
    }

    if (!mounted) return;

    if (provider.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      navigator.pop();
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Builds a [GoogleSheetsSource] from the current form values after
  /// running validation. Returns null if the form is invalid.
  GoogleSheetsSource? _buildSourceUnvalidated(BuildContext context) {
    final mapping = _buildColumnMapping();
    final provider = context.read<ContactSourceProvider>();
    return GoogleSheetsSource(
      id: _existingSource?.id ?? provider.generateId(),
      displayName: _displayNameController.text.trim().isEmpty
          ? 'Untitled Source'
          : _displayNameController.text.trim(),
      spreadsheetUrl: _urlController.text.trim(),
      worksheetName: _worksheetController.text.trim(),
      columnMapping: mapping,
    );
  }

  /// Builds a [GoogleSheetsSource] assuming the form has already been validated.
  GoogleSheetsSource _buildSourceFromForm(BuildContext context) {
    final mapping = _buildColumnMapping();
    final provider = context.read<ContactSourceProvider>();
    return GoogleSheetsSource(
      id: _existingSource?.id ?? provider.generateId(),
      displayName: _displayNameController.text.trim(),
      spreadsheetUrl: _urlController.text.trim(),
      worksheetName: _worksheetController.text.trim(),
      columnMapping: mapping,
    );
  }

  Map<ContactField, String> _buildColumnMapping() {
    final mapping = <ContactField, String>{};
    for (final field in ContactField.values) {
      final value = _mappingControllers[field]?.text.trim() ?? '';
      if (value.isNotEmpty) {
        mapping[field] = value;
      }
    }
    return mapping;
  }
}

// ── Shared widget ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blue),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}
