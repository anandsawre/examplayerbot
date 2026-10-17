import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';

class SettingsTab extends StatefulWidget {
  final Map<String, dynamic> settings;
  final ApiService api;
  final bool isDark;
  final Future<void> Function() onRefreshAll;
  final Function(String msg, {bool isError}) onShowToast;

  const SettingsTab({
    super.key,
    required this.settings,
    required this.api,
    required this.isDark,
    required this.onRefreshAll,
    required this.onShowToast,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late TextEditingController _upiCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _channelCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _upiCtrl = TextEditingController(text: widget.settings['upi_id'] ?? '');
    _priceCtrl = TextEditingController(text: '${widget.settings['subscription_price'] ?? 199}');
    _channelCtrl = TextEditingController(text: widget.settings['mandatory_channel'] ?? '');
  }

  @override
  void didUpdateWidget(covariant SettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      if (_upiCtrl.text != (widget.settings['upi_id'] ?? '')) {
        _upiCtrl.text = widget.settings['upi_id'] ?? '';
      }
      if (_priceCtrl.text != '${widget.settings['subscription_price'] ?? 199}') {
        _priceCtrl.text = '${widget.settings['subscription_price'] ?? 199}';
      }
      if (_channelCtrl.text != (widget.settings['mandatory_channel'] ?? '')) {
        _channelCtrl.text = widget.settings['mandatory_channel'] ?? '';
      }
    }
  }

  @override
  void dispose() {
    _upiCtrl.dispose();
    _priceCtrl.dispose();
    _channelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isMobile = MediaQuery.of(context).size.width < 750;

    return ListView(
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      children: [
        Card(
          color: isDark ? AppTheme.darkCard : Colors.white,
          elevation: isDark ? 0 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Global Platform Settings', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'Manage payment coordinates, tariff charges, and compulsory subscription channels.',
                  style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: _upiCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Settlement UPI VPA Address',
                    hintText: 'e.g. examplayer@okhdfcbank',
                    helperText: 'Displayed on student invoice prompts when upgrading to Scholar Pass.',
                    prefixIcon: Icon(Icons.qr_code_2_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Scholar Pass Registration Fee (₹ INR)',
                    hintText: '99',
                    helperText: 'One-time or monthly subscription tariff fee charged in Indian Rupees.',
                    prefixIcon: Icon(Icons.currency_rupee_rounded, size: 19),
                  ),
                ),
                const SizedBox(height: 20),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Mandatory Telegram Announcement Channel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _channelCtrl.clear(),
                          child: const Text('Clear Channel', style: TextStyle(fontSize: 11, color: AppTheme.rose)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _channelCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. @ExamplayerAnnouncements (Leave blank to disable)',
                        helperText: 'If configured, students must join this channel before tests unlock.',
                        prefixIcon: Icon(Icons.campaign_outlined, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isSaving ? null : () async {
                    setState(() => _isSaving = true);
                    final res = await widget.api.updateSettings(
                      upiId: _upiCtrl.text.trim(),
                      price: _priceCtrl.text.trim(),
                      channel: _channelCtrl.text.trim(),
                    );
                    if (mounted) setState(() => _isSaving = false);
                    if (res['success'] == true) {
                      widget.onShowToast('Platform settings saved successfully! 💾');
                      widget.onRefreshAll();
                    } else {
                      widget.onShowToast(res['error'] ?? 'Save failed', isError: true);
                    }
                  },
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_isSaving ? 'Saving Configuration...' : '💾 Save Platform Configuration', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
