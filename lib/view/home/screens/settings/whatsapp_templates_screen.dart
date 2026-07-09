import 'package:community_material_icon/community_material_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/core/utils/whatsapp_helper.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/models/whatsapp_template_model.dart';
import 'package:pos/data/services/whatsapp_template_service.dart';
import 'package:shimmer/shimmer.dart';

const _green = Color(0xFF25D366);
const _darkGreen = Color(0xFF0C6B0F);
const _waBackground = Color(0xFFECE5DD);
const _waBubble = Color(0xFFDCF8C6);

class WhatsappTemplatesScreen extends StatefulWidget {
  const WhatsappTemplatesScreen({super.key});

  @override
  State<WhatsappTemplatesScreen> createState() => _WhatsappTemplatesScreenState();
}

class _WhatsappTemplatesScreenState extends State<WhatsappTemplatesScreen> {
  final _service = WhatsappTemplateService();
  List<WhatsappTemplateModel> _templates = [];
  bool _isLoading = true;
  bool _isSettingDefault = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      setState(() => _isLoading = true);
      final templates = await _service.getAll();
      if (mounted) {
        templates.sort((a, b) => (b.isDefault ? 1 : 0) - (a.isDefault ? 1 : 0));
        setState(() => _templates = templates);
      }
    } catch (e) {
      if (mounted) SnackBarUtils.showError(context, 'Failed to load templates: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openEditor({WhatsappTemplateModel? template}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WhatsappTemplateEditorPage(service: _service, template: template),
      ),
    );
    if (saved == true && mounted) _loadTemplates();
  }

  Future<void> _setDefault(WhatsappTemplateModel t) async {
    if (t.isDefault) return;
    setState(() => _isSettingDefault = true);
    try {
      final currentDefault = _templates.where((tmpl) => tmpl.isDefault).toList();
      if (currentDefault.isNotEmpty) {
        final old = currentDefault.first;
        await _service.update(old.id, old.name, old.message, isDefault: false);
      }
      await _service.update(t.id, t.name, t.message, isDefault: true);
      if (mounted) {
        SnackBarUtils.showSuccess(context, '"${t.name}" set as default');
        _loadTemplates();
      }
    } catch (e) {
      if (mounted) SnackBarUtils.showError(context, '$e');
    } finally {
      if (mounted) setState(() => _isSettingDefault = false);
    }
  }

  Future<void> _confirmDelete(WhatsappTemplateModel t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 22),
            SizedBox(width: 8),
            MyText(text: 'Delete Template', fontWeight: FontWeight.bold),
          ],
        ),
        content: MyText(
          text: 'Delete "${t.name}"? This action cannot be undone.',
          color: Colors.grey.shade600,
          fontSize: 14,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: MyText(text: 'Cancel', color: Colors.grey.shade600),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const MyText(text: 'Delete', color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.delete(t.id);
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Template deleted');
        _loadTemplates();
      }
    } catch (e) {
      if (mounted) SnackBarUtils.showError(context, '$e');
    }
  }

  Future<void> _copyTemplate(WhatsappTemplateModel t) async {
    await Clipboard.setData(ClipboardData(text: t.message));
    if (mounted) SnackBarUtils.showSuccess(context, '"${t.name}" copied to clipboard');
  }

  void _showPreviewSheet(WhatsappTemplateModel t) {
    final filled = WhatsappHelper.fillTemplate(
      t.message,
      shopName: 'Billing Sphere',
      customerName: 'Rahul Sharma',
      billNumber: 'BILL-2026-0001',
      amount: 850,
      dateTime: DateTime.now(),
      orderType: 'Dine-In',
      paymentMethod: 'UPI',
      items: [
        {'name': 'Butter Chicken', 'quantity': 2, 'price': 250},
        {'name': 'Naan', 'quantity': 4, 'price': 25},
      ],
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              // WhatsApp-style header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 14),
                color: _darkGreen,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CommunityMaterialIcons.whatsapp, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MyText(text: t.name, color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          const MyText(text: 'Preview with sample data', color: Colors.white70, fontSize: 12),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              // Chat bubble area
              Expanded(
                child: Container(
                  color: _waBackground,
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: MyText(
                            text: DateFormat('dd MMM yyyy').format(DateTime.now()),
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(ctx).size.width * 0.80,
                          ),
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                          decoration: const BoxDecoration(
                            color: _waBubble,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                              bottomLeft: Radius.circular(14),
                              bottomRight: Radius.circular(2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                filled,
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13.5,
                                  height: 1.55,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MyText(
                                    text: DateFormat('hh:mm a').format(DateTime.now()),
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.done_all, size: 14, color: Color(0xFF53BDEB)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: MyText(
                          text: '* Sample data — real values filled at send time',
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Actions
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _copyTemplate(t);
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text(
                          'Copy',
                          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _darkGreen,
                          side: const BorderSide(color: _darkGreen),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openEditor(template: t);
                        },
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text(
                          'Edit',
                          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _darkGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: _darkGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CommunityMaterialIcons.whatsapp, color: Colors.white, size: 22),
            SizedBox(width: 8),
            MyText(
              text: 'WhatsApp Templates',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ],
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: _darkGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const MyText(text: 'New Template', color: Colors.white, fontWeight: FontWeight.w600),
      ),
      body: _isLoading
          ? _buildSkeleton()
          : _templates.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9))),
                    const SizedBox(width: 10),
                    Expanded(child: Container(height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)))),
                    const SizedBox(width: 30),
                    Container(width: 22, height: 22, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 70, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                const SizedBox(height: 12),
                Container(height: 36, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(CommunityMaterialIcons.whatsapp, size: 60, color: _green),
            ),
            const SizedBox(height: 24),
            const MyText(text: 'No Templates Yet', fontSize: 22, fontWeight: FontWeight.bold),
            const SizedBox(height: 10),
            MyText(
              text: 'Create ready-to-use WhatsApp message templates with personalized placeholders.',
              fontSize: 14,
              color: Colors.grey.shade500,
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const MyText(text: 'Create First Template', color: Colors.white, fontWeight: FontWeight.bold),
              style: ElevatedButton.styleFrom(
                backgroundColor: _darkGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final hasDefault = _templates.any((t) => t.isDefault);
    return Column(
      children: [
        // Stats bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_darkGreen.withValues(alpha: 0.07), _green.withValues(alpha: 0.04)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(CommunityMaterialIcons.whatsapp, color: _green, size: 16),
              const SizedBox(width: 8),
              MyText(
                text: '${_templates.length} template${_templates.length == 1 ? '' : 's'}',
                fontWeight: FontWeight.w600,
                color: _darkGreen,
                fontSize: 13,
              ),
              if (hasDefault) ...[
                MyText(text: '  ·  ', color: Colors.grey.shade400, fontSize: 13),
                const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 14),
                const SizedBox(width: 4),
                const MyText(text: '1 default set', fontSize: 12, color: _darkGreen, fontWeight: FontWeight.w500),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: _templates.length,
            itemBuilder: (_, i) => _buildCard(_templates[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(WhatsappTemplateModel t) {
    final isDefault = t.isDefault;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: isDefault ? _green : Colors.grey.shade300, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: isDefault ? _green.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDefault)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.07),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(16),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: _green, size: 14),
                  SizedBox(width: 6),
                  MyText(text: 'DEFAULT TEMPLATE', fontSize: 11, fontWeight: FontWeight.bold, color: _green),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + star
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(CommunityMaterialIcons.whatsapp, color: _green, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MyText(
                        text: t.name,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: _isSettingDefault ? null : () => _setDefault(t),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          isDefault ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 22,
                          color: isDefault ? const Color(0xFFFFB800) : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // WhatsApp bubble preview
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: _waBubble,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(2),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: MyText(
                    text: t.message,
                    fontSize: 12,
                    color: Colors.black87,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 12),
                // Action row
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      _cardBtn(Icons.visibility_outlined, 'Preview', () => _showPreviewSheet(t), color: _green),
                      _cardDivider(),
                      _cardBtn(Icons.copy_rounded, 'Copy', () => _copyTemplate(t), color: Colors.grey.shade600),
                      const Spacer(),
                      _cardBtn(Icons.edit_outlined, 'Edit', () => _openEditor(template: t), color: _darkGreen),
                      _cardDivider(),
                      _cardBtn(Icons.delete_outline, 'Delete', () => _confirmDelete(t), color: Colors.red),
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

  Widget _cardBtn(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color ?? _darkGreen),
            const SizedBox(width: 5),
            MyText(text: label, fontSize: 12, color: color ?? _darkGreen, fontWeight: FontWeight.w600),
          ],
        ),
      ),
    );
  }

  Widget _cardDivider() => Container(
        width: 1,
        height: 18,
        color: Colors.grey.shade200,
        margin: const EdgeInsets.symmetric(horizontal: 2),
      );
}

// ─── Full-page editor ────────────────────────────────────────────────────────

class WhatsappTemplateEditorPage extends StatefulWidget {
  final WhatsappTemplateService service;
  final WhatsappTemplateModel? template;

  const WhatsappTemplateEditorPage({
    super.key,
    required this.service,
    this.template,
  });

  @override
  State<WhatsappTemplateEditorPage> createState() => _WhatsappTemplateEditorPageState();
}

class _WhatsappTemplateEditorPageState extends State<WhatsappTemplateEditorPage> {
  static const _placeholders = [
    '{shopName}',
    '{customerName}',
    '{billNumber}',
    '{amount}',
    '{date}',
    '{orderType}',
    '{paymentMethod}',
    '{items}',
  ];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _msgCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  bool get _isEdit => widget.template != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.template?.name ?? '');
    _msgCtrl = TextEditingController(text: widget.template?.message ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  void _insertPlaceholder(String p) {
    final sel = _msgCtrl.selection;
    final text = _msgCtrl.text;
    final start = sel.start < 0 ? text.length : sel.start;
    final end = sel.end < 0 ? text.length : sel.end;
    final newText = text.replaceRange(start, end, p);
    _msgCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + p.length),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      if (!_isEdit) {
        await widget.service.create(_nameCtrl.text.trim(), _msgCtrl.text.trim());
      } else {
        await widget.service.update(
          widget.template!.id,
          _nameCtrl.text.trim(),
          _msgCtrl.text.trim(),
          isDefault: widget.template!.isDefault,
        );
      }
      if (mounted) {
        SnackBarUtils.showSuccess(context, _isEdit ? 'Template updated' : 'Template created');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) SnackBarUtils.showError(context, '$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: _darkGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CommunityMaterialIcons.whatsapp, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            MyText(
              text: _isEdit ? 'Edit Template' : 'New Template',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MyText(text: 'Template Name', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Order Confirmation',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  prefixIcon: const Icon(Icons.label_outline, color: _darkGreen, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _darkGreen, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),
              const MyText(text: 'Message', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
              const SizedBox(height: 8),
              TextFormField(
                controller: _msgCtrl,
                maxLines: 8,
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, height: 1.6),
                decoration: InputDecoration(
                  hintText: 'Hi {customerName}, your bill of ₹{amount} is ready...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _darkGreen, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Message is required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  MyText(text: 'Tap a placeholder to insert at cursor', fontSize: 12, color: Colors.grey.shade500),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _placeholders
                    .map((p) => GestureDetector(
                          onTap: () => _insertPlaceholder(p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _green.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _green.withValues(alpha: 0.3)),
                            ),
                            child: MyText(text: p, fontSize: 12, color: _darkGreen, fontWeight: FontWeight.w600),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _darkGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : MyText(
                          text: _isEdit ? 'Update Template' : 'Create Template',
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
