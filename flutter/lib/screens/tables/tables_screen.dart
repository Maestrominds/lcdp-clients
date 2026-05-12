import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/status_badge.dart';
import '../../models/table_model.dart';
import '../../models/order.dart';
import 'table_detail_screen.dart';
import '../auth/phone_login_screen.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});
  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  List<TableModel> _tables = [];
  List<Order> _allOrders = [];
  bool _loading = true;
  Timer? _pollingTimer;

  @override
  void initState() { 
    super.initState(); 
    _refreshData(); 
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshData());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshData() async {
    try {
      final tablesData = await ApiService().getTables();
      final ordersData = await ApiService().getOrders();
      if (!mounted) return;
      setState(() { 
        _tables = (tablesData as List).map<TableModel>((t) => TableModel.fromJson(t as Map<String, dynamic>)).toList(); 
        _allOrders = (ordersData as List).map<Order>((o) => Order.fromJson(o as Map<String, dynamic>)).toList();
        _loading = false; 
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  bool _hasReadyOrder(String tableId) {
    return _allOrders.any((o) => o.tableId == tableId && o.status == OrderStatus.ready);
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Logout', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ApiService().clearToken();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PhoneLoginScreen()), (route) => false);
            },
            child: const Text('Logout', style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background, elevation: 0,
        title: Text('Cafe De Paris', style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryTeal)),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.rightFromBracket, size: 18, color: AppColors.errorRed),
            onPressed: _showLogoutDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal))
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: AppColors.primaryTeal,
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 20, mainAxisSpacing: 20, childAspectRatio: 0.72,
                ),
                itemCount: _tables.length,
                itemBuilder: (ctx, i) {
                  final table = _tables[i];
                  final isReady = _hasReadyOrder(table.id);

                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TableDetailScreen(table: table))).then((_) => _refreshData()),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isReady ? AppColors.readyText : AppColors.border, 
                          width: isReady ? 2.5 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (isReady)
                                  Positioned(
                                    top: 15, right: 15,
                                    child: Container(
                                      width: 12, height: 12,
                                      decoration: const BoxDecoration(color: AppColors.readyText, shape: BoxShape.circle),
                                    ),
                                  ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isReady ? AppColors.readyBg : AppColors.primaryTeal.withValues(alpha: 0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: FaIcon(
                                        FontAwesomeIcons.chair, 
                                        color: isReady ? AppColors.readyText : AppColors.primaryTeal, 
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      table.name, 
                                      style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 8),
                                    StatusBadge.fromTableStatus(table.status),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _buildActionArea(table),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildActionArea(TableModel table) {
    if (table.status == TableStatus.available) return const SizedBox(height: 16);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          if (table.status == TableStatus.ready)
            Expanded(
              child: _boutiqueButton('SERVE', AppColors.successGreen, () async {
                await ApiService().updateTableStatus(table.id, 'eating');
                _refreshData();
              }),
            ),
          if (table.status == TableStatus.ordered || table.status == TableStatus.preparing)
            Expanded(
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.preparingBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.preparingText.withValues(alpha: 0.2)),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 10, height: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.preparingText.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PREPARING',
                      style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.preparingText, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          if (table.status == TableStatus.eating)
            Expanded(
              child: _boutiqueButton('CLEAR', AppColors.primaryTeal, () async {
                await ApiService().updateTableStatus(table.id, 'available');
                _refreshData();
              }),
            ),
        ],
      ),
    );
  }

  Widget _boutiqueButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
        ),
      ),
    );
  }
}

