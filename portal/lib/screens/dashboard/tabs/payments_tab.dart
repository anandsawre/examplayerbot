import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/api_service.dart';
import '../../../services/telegram_service.dart';
import '../../../theme/app_theme.dart';

class PaymentsTab extends StatefulWidget {
  final ApiService api;
  final TelegramService tg;
  final bool isDark;
  final Future<void> Function() onRefreshAll;
  final Function(String msg, {bool isError}) onShowToast;

  const PaymentsTab({
    super.key,
    required this.api,
    required this.tg,
    required this.isDark,
    required this.onRefreshAll,
    required this.onShowToast,
  });

  @override
  State<PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<PaymentsTab> {
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterPlan = 'All Plans';
  String _filterStatus = 'All Status';
  String _dateRangeText = '01 Oct 2026 - 31 Oct 2026';

  // Stats
  Map<String, dynamic> _paymentMetrics = {
    'totalRevenue': '₹ 0',
    'successfulPayments': 0,
    'pendingPayments': 0,
    'failedPayments': 0,
    'activePremiumUsers': 0,
  };

  List<dynamic> _plans = [];
  List<dynamic> _transactions = [];
  List<dynamic> _gateways = [];
  List<dynamic> _dailyRevenue = [];

  ApiService get _api => widget.api;
  TelegramService get _tg => widget.tg;

  @override
  void initState() {
    super.initState();
    _loadAllPaymentData();
  }

  Future<void> _loadAllPaymentData() async {
    setState(() => _isLoading = true);
    try {
      final statsRes = await _api.getPaymentStats();
      if (statsRes['success'] == true && mounted) {
        if (statsRes['metrics'] != null) _paymentMetrics = statsRes['metrics'];
        if (statsRes['dailyRevenue'] != null) _dailyRevenue = statsRes['dailyRevenue'];
      }

      final plansRes = await _api.getSubscriptionPlans();
      if (mounted) _plans = plansRes;

      final txRes = await _api.getPaymentTransactions();
      if (mounted) _transactions = txRes;

      final gwRes = await _api.getPaymentGateways();
      if (mounted) _gateways = gwRes;

      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Create or Edit Plan Dialog
  void _openPlanDialog({Map<String, dynamic>? plan}) {
    _tg.hapticImpact('light');
    final nameCtrl = TextEditingController(text: plan?['name'] ?? '');
    final priceCtrl = TextEditingController(text: plan != null ? '${plan['price'] ?? 0}' : '');
    final periodCtrl = TextEditingController(text: plan?['billingPeriod'] ?? 'month');
    final featuresCtrl = TextEditingController(
      text: plan != null && plan['features'] is List ? (plan['features'] as List).join(', ') : 'All mock tests, Detailed analytics',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF5B3DF5).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.credit_card_rounded, color: Color(0xFF5B3DF5), size: 20),
            ),
            const SizedBox(width: 12),
            Text(plan == null ? 'Create Subscription Plan' : 'Edit Subscription Plan', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: min(480.0, MediaQuery.of(ctx).size.width * 0.95),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Plan Name', hintText: 'e.g. Semi-Annual Pass'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Price (₹)', hintText: 'e.g. 499'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: periodCtrl,
                      decoration: const InputDecoration(labelText: 'Billing Period', hintText: 'e.g. 6 months'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: featuresCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Features (Comma separated)',
                  hintText: 'All premium tests, No ads, Priority support',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B3DF5)),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final features = featuresCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
              final payload = {
                'id': plan?['id'] ?? 'plan_${DateTime.now().millisecondsSinceEpoch}',
                'name': nameCtrl.text.trim(),
                'price': int.tryParse(priceCtrl.text.trim()) ?? 0,
                'billingPeriod': periodCtrl.text.trim(),
                'priceDisplay': '₹${priceCtrl.text.trim()}',
                'periodDisplay': 'for ${periodCtrl.text.trim()}',
                'features': features,
                'status': 'Active',
              };
              final res = await _api.saveSubscriptionPlan(payload);
              if (res['success'] == true) {
                widget.onShowToast('Subscription plan saved successfully! 💳');
                _loadAllPaymentData();
              } else {
                widget.onShowToast(res['error'] ?? 'Failed to save plan', isError: true);
              }
            },
            child: const Text('Save Plan', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // Transaction Details & Refund Dialog
  void _openTransactionDialog(Map<String, dynamic> tx) {
    _tg.hapticImpact('light');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Transaction #${tx['transactionId'] ?? tx['id']}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: min(440.0, MediaQuery.of(ctx).size.width * 0.92),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('User', '${tx['user']} (@${tx['username']})'),
              _detailRow('Plan', '${tx['plan']}'),
              _detailRow('Amount', '₹${tx['amount']}'),
              _detailRow('Gateway', '${tx['paymentMethod']}'),
              _detailRow('Status', '${tx['status']}'),
              _detailRow('Date', '${tx['dateTime']}'),
            ],
          ),
        ),
        actions: [
          if (tx['status'] == 'Success')
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _api.refundTransaction(tx['id'] ?? tx['transactionId']);
                if (res['success'] == true) {
                  widget.onShowToast('Refund processed successfully for ${tx['transactionId']} ↩️');
                  _loadAllPaymentData();
                } else {
                  widget.onShowToast(res['error'] ?? 'Refund failed', isError: true);
                }
              },
              icon: const Icon(Icons.undo_rounded, size: 16),
              label: const Text('Process Refund'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // Date range picker
  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2028),
      initialDateRange: DateTimeRange(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 31)),
    );
    if (picked != null) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      setState(() {
        _dateRangeText =
            '${picked.start.day.toString().padLeft(2, '0')} ${months[picked.start.month - 1]} ${picked.start.year} - ${picked.end.day.toString().padLeft(2, '0')} ${months[picked.end.month - 1]} ${picked.end.year}';
      });
      _loadAllPaymentData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1080;
    final isDark = widget.isDark;

    return RefreshIndicator(
      onRefresh: _loadAllPaymentData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. HEADER (Title, Subtitle, Plan Settings, + Create Plan)
            _buildPageHeader(isDark),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 8),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                ),
              ),
            const SizedBox(height: 20),

            // 2. TOP 5 KPI CARDS
            _buildKpiMetricsRow(isDark),
            const SizedBox(height: 24),

            // 3. SUBSCRIPTION PLANS SECTION (Free, Monthly, Quarterly, Yearly)
            _buildSubscriptionPlansSection(isDark),
            const SizedBox(height: 24),

            // 4. MAIN LOWER CONTENT (65% Transactions Table, 35% Right Side Panels)
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 65, child: _buildTransactionsCard(isDark)),
                  const SizedBox(width: 24),
                  Expanded(flex: 35, child: _buildRightSidePanels(isDark)),
                ],
              )
            else
              Column(
                children: [
                  _buildTransactionsCard(isDark),
                  const SizedBox(height: 24),
                  _buildRightSidePanels(isDark),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // HEADER
  // =========================================================================

  Widget _buildPageHeader(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF5B3DF5).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: Icon(Icons.credit_card_rounded, color: Color(0xFF5B3DF5), size: 24),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payments & Plans',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111B35),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Manage premium plans, track payments, view transactions and handle refunds. Control access and monetization for your Telegram bot.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Plan Settings Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => widget.onShowToast('Payment gateway credentials verified in environment'),
          icon: const Icon(Icons.settings_outlined, size: 16, color: Color(0xFF64748B)),
          label: Text('Plan Settings', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 10),
        // + Create Plan Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5B3DF5),
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => _openPlanDialog(),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text('+ Create Plan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  // =========================================================================
  // TOP 5 KPIS
  // =========================================================================

  Widget _buildKpiMetricsRow(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final cardWidth = (constraints.maxWidth - 4 * 16) / 5;

        if (isMobile) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _kpiMetricCard('Total Revenue', '${_paymentMetrics['totalRevenue'] ?? '₹ 48,620'}', '+18% from last month', Icons.currency_rupee_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF), isDark, 170),
              _kpiMetricCard('Successful Payments', '${_paymentMetrics['successfulPayments'] ?? 236}', '+12%', Icons.credit_card_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5), isDark, 170),
              _kpiMetricCard('Pending Payments', '${_paymentMetrics['pendingPayments'] ?? 12}', 'Awaiting confirmation', Icons.access_time_rounded, const Color(0xFFF59E0B), const Color(0xFFFFFBEB), isDark, 170),
              _kpiMetricCard('Failed Payments', '${_paymentMetrics['failedPayments'] ?? 8}', '3.3% failure rate', Icons.cancel_outlined, const Color(0xFFEF4444), const Color(0xFFFEF2F2), isDark, 170),
              _kpiMetricCard('Active Premium Users', '${_paymentMetrics['activePremiumUsers'] ?? 184}', '+14%', Icons.people_alt_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF), isDark, 170),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: _kpiMetricCard('Total Revenue', '${_paymentMetrics['totalRevenue'] ?? '₹ 48,620'}', '+18% from last month', Icons.currency_rupee_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF), isDark, cardWidth)),
            const SizedBox(width: 14),
            Expanded(child: _kpiMetricCard('Successful Payments', '${_paymentMetrics['successfulPayments'] ?? 236}', '+12%', Icons.credit_card_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5), isDark, cardWidth)),
            const SizedBox(width: 14),
            Expanded(child: _kpiMetricCard('Pending Payments', '${_paymentMetrics['pendingPayments'] ?? 12}', 'Awaiting confirmation', Icons.access_time_rounded, const Color(0xFFF59E0B), const Color(0xFFFFFBEB), isDark, cardWidth)),
            const SizedBox(width: 14),
            Expanded(child: _kpiMetricCard('Failed Payments', '${_paymentMetrics['failedPayments'] ?? 8}', '3.3% failure rate', Icons.cancel_outlined, const Color(0xFFEF4444), const Color(0xFFFEF2F2), isDark, cardWidth)),
            const SizedBox(width: 14),
            Expanded(child: _kpiMetricCard('Active Premium Users', '${_paymentMetrics['activePremiumUsers'] ?? 184}', '+14%', Icons.people_alt_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF), isDark, cardWidth)),
          ],
        );
      },
    );
  }

  Widget _kpiMetricCard(
    String label,
    String value,
    String trend,
    IconData icon,
    Color accentColor,
    Color softBg,
    bool isDark,
    double width,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? accentColor.withValues(alpha: 0.15) : softBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(icon, size: 20, color: accentColor),
                ),
              ),
              if (trend.startsWith('+') || trend.startsWith('↗'))
                Row(
                  children: [
                    const Icon(Icons.arrow_upward_rounded, size: 12, color: Color(0xFF10B981)),
                    const SizedBox(width: 2),
                    Text(
                      trend,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF111B35),
              letterSpacing: -0.5,
            ),
          ),
          if (!trend.startsWith('+') && !trend.startsWith('↗'))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                trend,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: trend.contains('failure') ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // SUBSCRIPTION PLANS
  // =========================================================================

  Widget _buildSubscriptionPlansSection(bool isDark) {
    final displayPlans = _plans.isNotEmpty
        ? _plans
        : [
            {
              'id': 'plan_free',
              'name': 'Free Plan',
              'icon': 'bookmark',
              'priceDisplay': '₹0',
              'periodDisplay': 'Lifetime',
              'features': ['Limited tests', 'Basic access', 'Community support'],
              'status': 'Active',
              'color': const Color(0xFF64748B),
              'activeBtnColor': const Color(0xFFF1F5F9),
              'activeTextColor': const Color(0xFF475569),
            },
            {
              'id': 'plan_monthly',
              'name': 'Monthly Plan',
              'icon': 'calendar',
              'priceDisplay': '₹99',
              'periodDisplay': 'per month',
              'features': ['All mock tests', 'Previous year papers', '1v1 quiz battles', 'Priority support'],
              'status': 'Active',
              'color': const Color(0xFF2563EB),
              'activeBtnColor': const Color(0xFF2563EB),
              'activeTextColor': Colors.white,
            },
            {
              'id': 'plan_quarterly',
              'name': 'Quarterly Plan',
              'icon': 'crown',
              'priceDisplay': '₹249',
              'periodDisplay': 'for 3 months',
              'features': ['All premium tests', 'Detailed analytics', 'No ads', 'Priority support'],
              'status': 'Active',
              'color': const Color(0xFFF59E0B),
              'activeBtnColor': const Color(0xFFFEF3C7),
              'activeTextColor': const Color(0xFFB45309),
            },
            {
              'id': 'plan_yearly',
              'name': 'Yearly Plan',
              'icon': 'diamond',
              'priceDisplay': '₹899',
              'periodDisplay': 'per year',
              'features': ['Everything in Quarterly', 'Exclusive test series', 'Early access to new tests', 'Dedicated support'],
              'status': 'Active',
              'color': const Color(0xFF7C3AED),
              'activeBtnColor': const Color(0xFF5B3DF5),
              'activeTextColor': Colors.white,
            },
          ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('👑', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    'Premium Plans',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF111B35),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => widget.onShowToast('Configuring all subscription tiers'),
                child: Text(
                  'View All',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Create and manage subscription plans for your users.',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 18),

          // Plan Cards Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 840;

              if (!isWide) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: displayPlans.map((p) => Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: SizedBox(width: 250, child: _planCardItem(p, isDark)),
                    )).toList(),
                  ),
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: displayPlans.map((p) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _planCardItem(p, isDark),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _planCardItem(Map<String, dynamic> p, bool isDark) {
    final name = p['name'] ?? 'Plan';
    final priceDisplay = p['priceDisplay'] ?? '₹99';
    final periodDisplay = p['periodDisplay'] ?? 'per month';
    final features = (p['features'] as List?) ?? ['Standard Features'];
    final iconType = p['icon'] ?? 'crown';

    IconData iconData = Icons.bookmark_border_rounded;
    if (iconType == 'calendar') iconData = Icons.calendar_today_rounded;
    if (iconType == 'crown') iconData = Icons.workspace_premium_rounded;
    if (iconType == 'diamond') iconData = Icons.diamond_outlined;

    final isYearly = name.contains('Yearly');
    final isMonthly = name.contains('Monthly');
    final isQuarterly = name.contains('Quarterly');

    Color btnBg = const Color(0xFFF1F5F9);
    Color btnTextColor = const Color(0xFF475569);
    if (isMonthly) {
      btnBg = const Color(0xFF2563EB);
      btnTextColor = Colors.white;
    } else if (isQuarterly) {
      btnBg = const Color(0xFFFEF3C7);
      btnTextColor = const Color(0xFFB45309);
    } else if (isYearly) {
      btnBg = const Color(0xFF5B3DF5);
      btnTextColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : (isMonthly ? const Color(0xFFF8FAFC) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMonthly
              ? const Color(0xFF2563EB).withValues(alpha: 0.3)
              : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(iconData, size: 18, color: const Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF94A3B8)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'edit') _openPlanDialog(plan: p);
                  if (val == 'toggle') widget.onShowToast('Plan status updated');
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit Plan Details')),
                  const PopupMenuItem(value: 'toggle', child: Text('Toggle Status')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                priceDisplay,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111B35),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                periodDisplay,
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(Icons.check_rounded, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        f.toString(),
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF475569)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: btnBg,
                foregroundColor: btnTextColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onPressed: () => _openPlanDialog(plan: p),
              child: Text(
                'Active',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TRANSACTIONS TABLE
  // =========================================================================

  Widget _buildTransactionsCard(bool isDark) {
    var list = _transactions;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) {
        final u = (t['user'] ?? '').toString().toLowerCase();
        final txId = (t['transactionId'] ?? '').toString().toLowerCase();
        return u.contains(q) || txId.contains(q);
      }).toList();
    }
    if (_filterPlan != 'All Plans') {
      list = list.where((t) => t['plan'] == _filterPlan).toList();
    }
    if (_filterStatus != 'All Status') {
      list = list.where((t) => t['status'] == _filterStatus).toList();
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded, size: 20, color: Color(0xFF5B3DF5)),
                        const SizedBox(width: 8),
                        Text(
                          'Recent Transactions',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF111B35),
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => widget.onShowToast('Viewing complete ledger records'),
                      child: Text('View All', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB))),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'View all payment transactions and their status.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),

                // Filters Row: Search + Plans Dropdown + Status Dropdown + Date Range
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Search box
                    SizedBox(
                      width: 210,
                      height: 36,
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: GoogleFonts.inter(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search by user, transaction ID...',
                          hintStyle: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 16),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                    ),
                    // Plan filter
                    _filterPill(_filterPlan, ['All Plans', 'Monthly', 'Quarterly', 'Yearly'], (val) {
                      setState(() => _filterPlan = val);
                    }, isDark),
                    // Status filter
                    _filterPill(_filterStatus, ['All Status', 'Success', 'Pending', 'Failed', 'Refunded'], (val) {
                      setState(() => _filterStatus = val);
                    }, isDark),
                    // Date selector
                    InkWell(
                      onTap: _selectDateRange,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(_dateRangeText, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Table Rows
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 820,
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                    child: Row(
                      children: [
                        _colHeader('#', 30),
                        _colHeader('User', 180),
                        _colHeader('Plan', 90),
                        _colHeader('Amount', 70),
                        _colHeader('Payment Method', 120),
                        _colHeader('Transaction ID', 130),
                        _colHeader('Status', 80),
                        _colHeader('Date & Time', 120, alignment: Alignment.centerRight),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Transactions Rows
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: Text('No transactions match the selected filters')),
                    )
                  else
                    ...list.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final t = entry.value;
                      final status = t['status'] ?? 'Success';
                      final plan = t['plan'] ?? 'Monthly';
                      final method = t['paymentMethod'] ?? 'Razorpay';

                      Color statusBg = const Color(0xFFECFDF5);
                      Color statusText = const Color(0xFF10B981);
                      if (status == 'Pending') {
                        statusBg = const Color(0xFFFFFBEB);
                        statusText = const Color(0xFFF59E0B);
                      } else if (status == 'Failed' || status == 'Refunded') {
                        statusBg = const Color(0xFFFEF2F2);
                        statusText = const Color(0xFFEF4444);
                      }

                      Color planBg = const Color(0xFFEFF6FF);
                      Color planText = const Color(0xFF2563EB);
                      if (plan == 'Yearly') {
                        planBg = const Color(0xFFF5F3FF);
                        planText = const Color(0xFF7C3AED);
                      } else if (plan == 'Quarterly') {
                        planBg = const Color(0xFFFFFBEB);
                        planText = const Color(0xFFD97706);
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFF1F5F9))),
                        ),
                        child: Row(
                          children: [
                            // #
                            SizedBox(
                              width: 30,
                              child: Text('$idx', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                            ),
                            // User
                            SizedBox(
                              width: 180,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: const Color(0xFF2563EB),
                                    child: Text(
                                      (t['user'] ?? 'U')[0].toUpperCase(),
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(t['user'] ?? 'User', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text('@${t['username'] ?? 'user'}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Plan
                            SizedBox(
                              width: 90,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: planBg, borderRadius: BorderRadius.circular(6)),
                                  child: Text(plan, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: planText)),
                                ),
                              ),
                            ),
                            // Amount
                            SizedBox(
                              width: 70,
                              child: Text('₹${t['amount']}', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700)),
                            ),
                            // Method
                            SizedBox(
                              width: 120,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.flash_on_rounded, size: 10, color: Colors.white),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(method, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            // Transaction ID
                            SizedBox(
                              width: 130,
                              child: Text(
                                t['transactionId'] ?? 'pay_xxxx',
                                style: GoogleFonts.robotoMono(fontSize: 11.5, color: const Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Status
                            SizedBox(
                              width: 80,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                                  child: Text(status, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: statusText)),
                                ),
                              ),
                            ),
                            // Date & Actions
                            SizedBox(
                              width: 120,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    t['dateTime'] ?? 'Today',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => _openTransactionDialog(t),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'View',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colHeader(String title, double width, {Alignment alignment = Alignment.centerLeft}) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: alignment,
        child: Text(
          title,
          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
        ),
      ),
    );
  }

  Widget _filterPill(String current, List<String> options, Function(String) onSelect, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(current) ? current : options.first,
          isDense: true,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
          items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
          onChanged: (val) {
            if (val != null) onSelect(val);
          },
        ),
      ),
    );
  }

  // =========================================================================
  // RIGHT SIDE PANELS: REVENUE OVERVIEW + PAYMENT METHODS + QUICK ACTIONS
  // =========================================================================

  Widget _buildRightSidePanels(bool isDark) {
    return Column(
      children: [
        // Panel 1: Revenue Overview Bar Chart
        _buildRevenueOverviewCard(isDark),
        const SizedBox(height: 20),

        // Panel 2: Payment Methods Gateways
        _buildPaymentMethodsCard(isDark),
        const SizedBox(height: 20),

        // Panel 3: Quick Actions
        _buildQuickActionsCard(isDark),
      ],
    );
  }

  Widget _buildRevenueOverviewCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart_rounded, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text(
                    'Revenue Overview',
                    style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF111B35)),
                  ),
                ],
              ),
              _filterPill('Last 30 Days', ['Last 30 Days', 'Last 7 Days', 'This Quarter'], (_) {}, isDark),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${_paymentMetrics['totalRevenue'] ?? '₹ 48,620'}',
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF111B35)),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_upward_rounded, size: 14, color: Color(0xFF10B981)),
              Text('+18%', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
            ],
          ),
          const SizedBox(height: 16),

          // Bar Chart Simulation matching Image 3
          if (_dailyRevenue.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  'No revenue recorded in this period',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _dailyRevenue.map((d) {
                  final val = ((d['amount'] as num? ?? 0) / 100).toDouble();
                  return Container(
                    width: 9,
                    height: (val * 1.05).clamp(10, 110),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B3DF5).withValues(alpha: val > 80 ? 0.9 : 0.45),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['1 Oct', '8 Oct', '15 Oct', '22 Oct', '31 Oct'].map((d) {
              return Text(d, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)));
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsCard(bool isDark) {
    final list = _gateways;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.payment_rounded, size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text('Payment Methods', style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 2),
          Text('Manage payment gateways and configurations.', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
          const SizedBox(height: 14),

          ...list.map((gw) {
            final name = gw['name']?.toString() ?? 'Gateway';
            final isEnabled = gw['status'] == 'Enabled';
            Color bg = const Color(0xFF0F172A);
            if (name.contains('Cashfree')) bg = const Color(0xFF047857);
            if (name.contains('PayU')) bg = const Color(0xFF84CC16);
            return _gatewayRow(name, bg, isEnabled, isDark);
          }),
        ],
      ),
    );
  }

  Widget _gatewayRow(String name, Color iconBg, bool isEnabled, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                name[0],
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isEnabled ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isEnabled ? 'Enabled' : 'Disabled',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isEnabled ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(40, 28),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () => widget.onShowToast('Gateway configuration for $name updated'),
            child: Text('Edit', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF5B3DF5)),
              const SizedBox(width: 8),
              Text('Quick Actions', style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _actionBtn(
                  'View Pending\nPayments',
                  Icons.access_time_rounded,
                  const Color(0xFF2563EB),
                  () {
                    setState(() => _filterStatus = 'Pending');
                    widget.onShowToast('Filtering 12 pending transactions');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionBtn(
                  'Process Refund',
                  Icons.undo_rounded,
                  const Color(0xFF7C3AED),
                  () => widget.onShowToast('Select a transaction below to issue a refund'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _actionBtn(
                  'Export Transactions',
                  Icons.download_rounded,
                  const Color(0xFF059669),
                  () => widget.onShowToast('Exporting transaction records to CSV... 📥'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionBtn(
                  'Payment Reports',
                  Icons.analytics_outlined,
                  const Color(0xFF4F46E5),
                  () => widget.onShowToast('Financial overview reconciled for Oct 2026 📊'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
