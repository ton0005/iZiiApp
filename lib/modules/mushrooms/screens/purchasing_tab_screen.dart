// lib/modules/mushrooms/screens/purchasing_tab_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/purchasing_models.dart';
import '../services/purchasing_service.dart';
import '../services/employee_service.dart';
import '../screens/mushboom_monarto_screen.dart'; // For FarmColors

class PurchasingTabScreen extends StatefulWidget {
  final bool isDark;
  final String activePlant;
  final String currentRole;

  const PurchasingTabScreen({
    super.key,
    required this.isDark,
    this.activePlant = 'M2',
    this.currentRole = 'Manager',
  });

  @override
  State<PurchasingTabScreen> createState() => _PurchasingTabScreenState();
}

class _PurchasingTabScreenState extends State<PurchasingTabScreen>
    with SingleTickerProviderStateMixin {
  final MushroomPurchasingService _service = MushroomPurchasingService();
  final EmployeeService _employeeService = EmployeeServiceImpl();

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<PurchaseRequestModel> _requests = [];
  List<SupplierModel> _suppliers = [];
  bool _isLoading = true;

  String _statusFilter = 'all';
  String _departmentFilter = 'all';
  String _searchQuery = '';
  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadCurrentUser();
    _loadData();
    _service.watchChanges.listen((_) {
      if (mounted) _loadData(showLoading: false);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final emp = await _employeeService.getCurrentEmployee();
    if (mounted && emp != null) {
      setState(() {
        _currentUserName = emp.name;
      });
    }
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    final reqs = await _service.getPurchaseRequests(
      status: _statusFilter,
      department: _departmentFilter,
      searchQuery: _searchQuery,
    );
    final sups = await _service.getSuppliers(searchQuery: _searchQuery);
    if (mounted) {
      setState(() {
        _requests = reqs;
        _suppliers = sups;
        _isLoading = false;
      });
    }
  }

  // --- KPI Counters ---
  int get _countTotal => _requests.length;
  int get _countPending => _requests.where((r) => r.status == 'pending').length;
  int get _countSourcing =>
      _requests.where((r) => r.status == 'sourcing').length;
  int get _countOrdered => _requests.where((r) => r.status == 'ordered').length;
  int get _countReceived =>
      _requests.where((r) => r.status == 'received').length;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildKpiMetrics(),
          const SizedBox(height: 16),
          _buildFiltersAndActions(),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRequestsList(),
                      _buildSuppliersList(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // --- Header ---
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shopping_cart_checkout_rounded,
                    color: Color(0xFF0D9488), size: 26),
                SizedBox(width: 10),
                Text(
                  'Purchasing & Supplier Management',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Manage purchase requests, spare parts, and Costa Farm Monarto supplier directory',
              style: TextStyle(
                fontSize: 13,
                color: widget.isDark ? Colors.white60 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
        Row(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
              label: const Text('Create Purchase Request (PR)'),
              onPressed: () => _showCreateRequestDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Add Supplier'),
              onPressed: () => _showSupplierDialog(),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D9488),
                side: const BorderSide(color: Color(0xFF0D9488)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- KPI Metrics ---
  Widget _buildKpiMetrics() {
    return Row(
      children: [
        _buildKpiCard('Total Requests', '$_countTotal', Icons.receipt_long_rounded,
            Colors.blueGrey),
        const SizedBox(width: 12),
        _buildKpiCard('Pending Review', '$_countPending',
            Icons.pending_actions_rounded, Colors.amber.shade700),
        const SizedBox(width: 12),
        _buildKpiCard('Sourcing Supplier', '$_countSourcing',
            Icons.travel_explore_rounded, Colors.indigo),
        const SizedBox(width: 12),
        _buildKpiCard('PO Ordered', '$_countOrdered',
            Icons.local_shipping_rounded, Colors.purple),
        const SizedBox(width: 12),
        _buildKpiCard('Received', '$_countReceived',
            Icons.check_circle_outline_rounded, Colors.teal),
      ],
    );
  }

  Widget _buildKpiCard(
      String title, String count, IconData icon, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: widget.isDark
              ? const Color(0xFF1E1E1E)
              : accentColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isDark
                ? Colors.white12
                : accentColor.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.white : accentColor,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        widget.isDark ? Colors.white60 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Filter Bar ---
  Widget _buildFiltersAndActions() {
    return Row(
      children: [
        // Tabs
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicator: BoxDecoration(
              color: const Color(0xFF0D9488),
              borderRadius: BorderRadius.circular(8),
            ),
            labelColor: Colors.white,
            unselectedLabelColor:
                widget.isDark ? Colors.white70 : Colors.black87,
            tabs: [
              Tab(
                child: Row(
                  children: [
                    const Icon(Icons.list_alt_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text('Purchase Requests (${_requests.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    const Icon(Icons.store_mall_directory_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text('Suppliers (${_suppliers.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Search Bar
        Expanded(
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _tabController.index == 0
                    ? 'Search by Part No, product, purpose, requester, room...'
                    : 'Search suppliers by name, category, phone number...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                          _loadData(showLoading: false);
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                ),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _loadData(showLoading: false);
              },
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Filter by Status (Only in Requests tab)
        if (_tabController.index == 0) ...[
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending Review')),
                  DropdownMenuItem(value: 'sourcing', child: Text('Sourcing Supplier')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'ordered', child: Text('PO Ordered')),
                  DropdownMenuItem(value: 'received', child: Text('Received')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _statusFilter = val);
                    _loadData();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Filter by Department
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _departmentFilter,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Departments')),
                  DropdownMenuItem(value: 'Growing', child: Text('Growing')),
                  DropdownMenuItem(value: 'Harvest', child: Text('Harvest')),
                  DropdownMenuItem(value: 'Cool Room', child: Text('Cool Room')),
                  DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                  DropdownMenuItem(value: 'Purchasing', child: Text('Purchasing')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _departmentFilter = val);
                    _loadData();
                  }
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  // --- Tab 1: Requests List ---
  Widget _buildRequestsList() {
    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No purchase requests found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Click "Create Purchase Request (PR)" to submit a request to Purchasing.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final req = _requests[index];
        return _buildRequestCard(req);
      },
    );
  }

  Widget _buildRequestCard(PurchaseRequestModel req) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final isUrgent = req.priority == 'urgent';
    final isHigh = req.priority == 'high';

    Color priorityColor = Colors.grey.shade600;
    String priorityLabel = 'Normal';
    if (isUrgent) {
      priorityColor = Colors.red;
      priorityLabel = 'URGENT';
    } else if (isHigh) {
      priorityColor = Colors.orange.shade800;
      priorityLabel = 'HIGH PRIORITY';
    } else if (req.priority == 'low') {
      priorityColor = Colors.blueGrey;
      priorityLabel = 'Low';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isUrgent
              ? Colors.red.shade300
              : (widget.isDark ? Colors.white12 : Colors.grey.shade300),
          width: isUrgent ? 1.5 : 1,
        ),
      ),
      color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Code, Department, Status, Priority
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    req.requestNo,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D9488),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    req.department,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
                if (req.roomName != null && req.roomName!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: FarmColors.forestGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.meeting_room_outlined,
                            size: 14, color: FarmColors.forestGreen),
                        const SizedBox(width: 4),
                        Text(
                          req.roomName!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: FarmColors.forestGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),

                // Priority Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: priorityColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUrgent
                            ? Icons.error_outline_rounded
                            : Icons.flag_rounded,
                        size: 14,
                        color: priorityColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        priorityLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: priorityColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Status Badge
                _buildStatusBadge(req.status),
              ],
            ),
            const SizedBox(height: 12),

            // Product & Part No & Quantity
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Part No: ${req.partNo.isNotEmpty ? req.partNo : 'N/A'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Qty: ${req.quantity.toStringAsFixed(req.quantity.truncateToDouble() == req.quantity ? 0 : 2)} ${req.unit}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        req.productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.assignment_outlined,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Purpose: ${req.purpose}',
                              style: TextStyle(
                                fontSize: 13,
                                color: widget.isDark
                                    ? Colors.white70
                                    : Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (req.notes != null && req.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.note_alt_outlined,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Notes: ${req.notes}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Supplier & Timing Info Box
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.isDark
                            ? Colors.white12
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              'Requested: ${dateFormat.format(req.requestDate)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.alarm_on_rounded,
                                size: 14, color: Colors.red),
                            const SizedBox(width: 6),
                            Text(
                              'Required by: ${dateFormat.format(req.requiredDate)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 14),
                        if (req.supplierName != null &&
                            req.supplierName!.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.store_outlined,
                                  size: 15, color: Color(0xFF0D9488)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  req.supplierName!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D9488),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (req.poNumber != null &&
                              req.poNumber!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'PO: ${req.poNumber}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (req.estimatedCost != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Est. Cost: \$${req.estimatedCost!.toStringAsFixed(2)} AUD',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ] else ...[
                          const Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 14, color: Colors.amber),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'No supplier assigned',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.amber),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bottom Row: Requester Info & Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_circle_outlined,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Requester: ${req.requesterName}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Assign Supplier Button
                    OutlinedButton.icon(
                      icon: const Icon(Icons.storefront_rounded, size: 16),
                      label: Text(req.supplierName == null
                          ? 'Assign Supplier'
                          : 'Change Supplier (${req.supplierName})'),
                      onPressed: () => _showAssignSupplierDialog(req),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0D9488),
                        side: const BorderSide(color: Color(0xFF0D9488)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Change Status Menu
                    PopupMenuButton<String>(
                      tooltip: 'Change Status',
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (newStatus) async {
                        await _service.updateRequestStatus(req.id, newStatus);
                        _loadData(showLoading: false);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: 'pending', child: Text('Pending Review')),
                        const PopupMenuItem(
                            value: 'sourcing', child: Text('Sourcing / Quotes')),
                        const PopupMenuItem(
                            value: 'approved', child: Text('Approve Request')),
                        const PopupMenuItem(
                            value: 'ordered', child: Text('PO Issued / Ordered')),
                        const PopupMenuItem(
                            value: 'received', child: Text('Received in Warehouse')),
                        const PopupMenuItem(
                            value: 'rejected', child: Text('Reject Request')),
                      ],
                    ),

                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Request',
                      onPressed: () => _showCreateRequestDialog(editing: req),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      tooltip: 'Delete Request',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Confirm Delete'),
                            content: Text(
                                'Are you sure you want to delete ${req.requestNo}?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _service.deletePurchaseRequest(req.id);
                          _loadData(showLoading: false);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'pending':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        label = 'Pending Review';
        break;
      case 'sourcing':
        bg = Colors.indigo.shade50;
        fg = Colors.indigo.shade700;
        label = 'Sourcing';
        break;
      case 'approved':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        label = 'Approved';
        break;
      case 'ordered':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade700;
        label = 'PO Ordered';
        break;
      case 'received':
        bg = Colors.teal.shade50;
        fg = Colors.teal.shade800;
        label = 'Received';
        break;
      case 'rejected':
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        label = 'Rejected';
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  // --- Tab 2: Suppliers List ---
  Widget _buildSuppliersList() {
    if (_suppliers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_mall_directory_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No suppliers found in directory',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Click "Add Supplier" to register farm suppliers and service providers.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 450,
        mainAxisExtent: 220,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _suppliers.length,
      itemBuilder: (context, index) {
        final sup = _suppliers[index];
        return _buildSupplierCard(sup);
      },
    );
  }

  Widget _buildSupplierCard(SupplierModel sup) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: widget.isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.15),
                  child: const Icon(Icons.store_rounded,
                      color: Color(0xFF0D9488), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sup.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (sup.contactPerson != null &&
                          sup.contactPerson!.isNotEmpty)
                        Text(
                          'Contact: ${sup.contactPerson}',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => _showSupplierDialog(editing: sup),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (sup.phone != null && sup.phone!.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(sup.phone!, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 12),
                  if (sup.email != null && sup.email!.isNotEmpty) ...[
                    const Icon(Icons.email_outlined,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        sup.email!,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
            ],
            if (sup.address != null && sup.address!.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      sup.address!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            // Categories Chips
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: sup.categories.take(3).map((c) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    c,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // --- Dialog: Create Purchase Request (For Managers) ---
  void _showCreateRequestDialog({PurchaseRequestModel? editing}) async {
    final isEdit = editing != null;
    final nextReqNo =
        isEdit ? editing.requestNo : await _service.generateNextRequestNo();

    final partNoController = TextEditingController(text: editing?.partNo ?? '');
    final productNameController =
        TextEditingController(text: editing?.productName ?? '');
    final quantityController = TextEditingController(
        text: editing != null ? '${editing.quantity}' : '1');
    final purposeController =
        TextEditingController(text: editing?.purpose ?? '');
    final notesController = TextEditingController(text: editing?.notes ?? '');

    String selectedUnit = editing?.unit ?? 'Cái';
    String selectedDept = editing?.department ?? 'Growing';
    String selectedPriority = editing?.priority ?? 'normal';
    final selectedPlant = editing?.plant ?? widget.activePlant;
    String? selectedRoom = editing?.roomName;

    DateTime reqDate = editing?.requestDate ?? DateTime.now();
    DateTime needDate = editing?.requiredDate ??
        DateTime.now().add(const Duration(days: 3));

    final roomsList = [
      'Room 33', 'Room 34', 'Room 35', 'Room 36', 'Room 37', 'Room 38',
      'Room 39', 'Room 40', 'Room 41', 'Room 42', 'Room 43', 'Room 44',
      'Room 6A', 'Room 6B', 'Room 22A', 'Cool Room 1', 'Packing Shed', 'General'
    ];

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDlgState) {
            return AlertDialog(
              backgroundColor:
                  widget.isDark ? const Color(0xFF1E293B) : Colors.white,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.note_add_rounded,
                      color: Color(0xFF0D9488),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? 'Edit Purchase Request' : 'Create Purchase Request (PR)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Request No banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.isDark
                                ? Colors.white10
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.tag,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  'Request No: $nextReqNo',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Plant: $selectedPlant',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Color(0xFF0D9488),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Part No and Product Name
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: TextField(
                              controller: partNoController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Part No. (Item / Part Code)',
                                hintText: 'e.g. PUMP-24V-01',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 6,
                            child: TextField(
                              controller: productNameController,
                              decoration: const InputDecoration(
                                labelText: 'Product / Item Name *',
                                hintText: 'e.g. High Pressure 24V Water Pump',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Quantity, Unit and Priority
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: quantityController,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Quantity *',
                                hintText: '10',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedUnit,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Cái', child: Text('Unit / Piece')),
                                DropdownMenuItem(value: 'Can', child: Text('Canister (5L/20L)')),
                                DropdownMenuItem(value: 'Chai', child: Text('Bottle (1L)')),
                                DropdownMenuItem(value: 'Thùng', child: Text('Box / Carton')),
                                DropdownMenuItem(value: 'Bộ', child: Text('Set / Kit')),
                                DropdownMenuItem(value: 'Kg', child: Text('Kg')),
                                DropdownMenuItem(value: 'Mét', child: Text('Meters')),
                                DropdownMenuItem(value: 'Hộp', child: Text('Pack / Box')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDlgState(() => selectedUnit = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedPriority,
                              decoration: const InputDecoration(
                                labelText: 'Priority',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'low', child: Text('Low')),
                                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                                DropdownMenuItem(value: 'high', child: Text('High Priority')),
                                DropdownMenuItem(value: 'urgent', child: Text('🔥 URGENT')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDlgState(() => selectedPriority = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Dates: Request Date & Required Date
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                  'Request Date: ${DateFormat('dd/MM/yyyy').format(reqDate)}'),
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: reqDate,
                                  firstDate: DateTime(2025),
                                  lastDate: DateTime(2030),
                                );
                                if (d != null) {
                                  setDlgState(() => reqDate = d);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.alarm_on,
                                  size: 16, color: Colors.red),
                              label: Text(
                                'Required by: ${DateFormat('dd/MM/yyyy').format(needDate)}',
                                style: const TextStyle(
                                    color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: needDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2030),
                                );
                                if (d != null) {
                                  setDlgState(() => needDate = d);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Department and Grow Room
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedDept,
                              decoration: const InputDecoration(
                                labelText: 'Requesting Department *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'Growing', child: Text('Growing')),
                                DropdownMenuItem(
                                    value: 'Harvest', child: Text('Harvest')),
                                DropdownMenuItem(
                                    value: 'Cool Room', child: Text('Cool Room')),
                                DropdownMenuItem(
                                    value: 'Maintenance',
                                    child: Text('Maintenance')),
                                DropdownMenuItem(
                                    value: 'Purchasing', child: Text('Purchasing')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDlgState(() => selectedDept = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              initialValue: selectedRoom,
                              decoration: const InputDecoration(
                                labelText: 'Associated Grow Room',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem(
                                    value: null, child: Text('General / None')),
                                ...roomsList.map((r) =>
                                    DropdownMenuItem(value: r, child: Text(r))),
                              ],
                              onChanged: (val) {
                                setDlgState(() => selectedRoom = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Purpose (Dùng cho việc gì)
                      TextField(
                        controller: purposeController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Purpose / Intended Use *',
                          hintText:
                              'e.g. Routine fan filter replacement in Room 33, Prochloraz fungicide application...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Notes
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'Additional Notes / Technical Specs',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(isEdit ? 'Save Changes' : 'Submit Purchase Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final partNo = partNoController.text.trim();
                    final prodName = productNameController.text.trim();
                    final qty = double.tryParse(quantityController.text) ?? 1.0;
                    final purpose = purposeController.text.trim();

                    if (partNo.isEmpty || prodName.isEmpty || purpose.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Please fill in Part No, Product Name, and Purpose.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    final newReq = PurchaseRequestModel(
                      id: editing?.id ?? const Uuid().v4(),
                      requestNo: nextReqNo,
                      requestDate: reqDate,
                      requiredDate: needDate,
                      partNo: partNo,
                      productName: prodName,
                      quantity: qty,
                      unit: selectedUnit,
                      purpose: purpose,
                      department: selectedDept,
                      plant: selectedPlant,
                      roomName: selectedRoom,
                      priority: selectedPriority,
                      status: editing?.status ?? 'pending',
                      requesterId: editing?.requesterId ?? 'MGR-01',
                      requesterName: editing?.requesterName ??
                          (_currentUserName ?? 'Manager'),
                      notes: notesController.text.trim(),
                      supplierId: editing?.supplierId,
                      supplierName: editing?.supplierName,
                      estimatedCost: editing?.estimatedCost,
                      actualCost: editing?.actualCost,
                      poNumber: editing?.poNumber,
                      expectedDeliveryDate: editing?.expectedDeliveryDate,
                    );

                    if (isEdit) {
                      await _service.updatePurchaseRequest(newReq);
                    } else {
                      await _service.createPurchaseRequest(newReq);
                    }

                    if (mounted && ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Successfully submitted request $nextReqNo!'),
                          backgroundColor: const Color(0xFF0D9488),
                        ),
                      );
                      _loadData(showLoading: false);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Dialog: Assign Supplier (For Purchasing) ---
  void _showAssignSupplierDialog(PurchaseRequestModel req) {
    SupplierModel? selectedSupplier;
    if (req.supplierId != null) {
      selectedSupplier = _suppliers.firstWhere(
        (s) => s.id == req.supplierId,
        orElse: () => _suppliers.first,
      );
    } else if (_suppliers.isNotEmpty) {
      selectedSupplier = _suppliers.first;
    }

    final costController = TextEditingController(
        text: req.estimatedCost != null ? '${req.estimatedCost}' : '');
    final poController = TextEditingController(
        text: req.poNumber ?? 'PO-${req.plant ?? 'M2'}-${DateFormat('yyMM').format(DateTime.now())}-');
    DateTime deliveryDate =
        req.expectedDeliveryDate ?? req.requiredDate;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.store_mall_directory_rounded,
                      color: Color(0xFF0D9488)),
                  const SizedBox(width: 8),
                  Text('Assign Supplier to ${req.requestNo}'),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Item: ${req.productName} (Part No: ${req.partNo})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quantity: ${req.quantity} ${req.unit} • Required by: ${DateFormat('dd/MM/yyyy').format(req.requiredDate)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Divider(height: 20),

                    // Choose Supplier from List or Add New
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Supplier from Catalog:',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add New Supplier'),
                          onPressed: () {
                            _showSupplierDialog();
                          },
                        ),
                      ],
                    ),
                    DropdownButtonFormField<SupplierModel>(
                      initialValue: selectedSupplier,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _suppliers.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(
                            '${s.name} (${s.categories.join(", ")})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDlgState(() => selectedSupplier = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // PO Number and Cost
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: poController,
                            decoration: const InputDecoration(
                              labelText: 'Purchase Order No. (PO)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: costController,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Estimated Cost (\$ AUD)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Expected Delivery Date
                    OutlinedButton.icon(
                      icon: const Icon(Icons.local_shipping_outlined, size: 16),
                      label: Text(
                        'Expected Delivery Date: ${DateFormat('dd/MM/yyyy').format(deliveryDate)}',
                      ),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: deliveryDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) {
                          setDlgState(() => deliveryDate = d);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Confirm & Assign Supplier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (selectedSupplier == null) return;
                    final estCost = double.tryParse(costController.text);
                    final po = poController.text.trim();

                    await _service.assignSupplierToRequest(
                      req.id,
                      selectedSupplier!,
                      estimatedCost: estCost,
                      poNumber: po.isNotEmpty ? po : null,
                      expectedDeliveryDate: deliveryDate,
                    );

                    if (mounted && ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Assigned supplier "${selectedSupplier!.name}" to request ${req.requestNo}!'),
                          backgroundColor: const Color(0xFF0D9488),
                        ),
                      );
                      _loadData(showLoading: false);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Dialog: Create/Edit Supplier ---
  void _showSupplierDialog({SupplierModel? editing}) {
    final isEdit = editing != null;
    final nameController = TextEditingController(text: editing?.name ?? '');
    final contactController =
        TextEditingController(text: editing?.contactPerson ?? '');
    final phoneController = TextEditingController(text: editing?.phone ?? '');
    final emailController = TextEditingController(text: editing?.email ?? '');
    final addressController = TextEditingController(text: editing?.address ?? '');
    final categoriesController =
        TextEditingController(text: editing?.categories.join(', ') ?? '');
    final notesController = TextEditingController(text: editing?.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.store_mall_directory_rounded,
                  color: Color(0xFF0D9488)),
              const SizedBox(width: 8),
              Text(isEdit ? 'Edit Supplier' : 'Add New Supplier'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Supplier Name (Company / Vendor) *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: contactController,
                          decoration: const InputDecoration(
                            labelText: 'Contact Person',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address / Warehouse',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: categoriesController,
                    decoration: const InputDecoration(
                      labelText: 'Product Categories (comma-separated)',
                      hintText: 'e.g. Chemicals, Air Filters, Trays, Water Pumps',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Additional Notes',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final cats = categoriesController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();

                final sup = SupplierModel(
                  id: editing?.id ?? 'SUP-${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  contactPerson: contactController.text.trim(),
                  phone: phoneController.text.trim(),
                  email: emailController.text.trim(),
                  address: addressController.text.trim(),
                  categories: cats,
                  notes: notesController.text.trim(),
                );

                await _service.saveSupplier(sup);
                if (mounted && ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Supplier "$name" saved successfully!'),
                      backgroundColor: const Color(0xFF0D9488),
                    ),
                  );
                  _loadData(showLoading: false);
                }
              },
              child: Text(isEdit ? 'Save Changes' : 'Add Supplier'),
            ),
          ],
        );
      },
    );
  }
}
