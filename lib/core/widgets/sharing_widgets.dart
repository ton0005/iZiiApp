import 'package:flutter/material.dart';
import '../database/app_database.dart';

class VisibilityToggleWidget extends StatelessWidget {
  final String visibility; // 'private', 'team', 'community'
  final VoidCallback onTap;

  const VisibilityToggleWidget({
    super.key,
    required this.visibility,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String label;

    switch (visibility) {
      case 'team':
        icon = Icons.people_alt_rounded;
        color = const Color(0xFF6366F1); // Primary indigo
        label = 'Nhóm';
        break;
      case 'community':
        icon = Icons.public_rounded;
        color = const Color(0xFF10B981); // Emerald
        label = 'Cộng đồng';
        break;
      default:
        icon = Icons.lock_outline_rounded;
        color = Colors.grey;
        label = 'Riêng tư';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AudienceSelectorBottomSheet extends StatefulWidget {
  final String initialVisibility;
  final List<String> initialAudience;
  final double initialMinTin;
  final DateTime? initialExpiresAt;
  final Function(String visibility, List<String> audience, double minTin,
      DateTime? expiresAt) onConfirm;

  const AudienceSelectorBottomSheet({
    super.key,
    required this.initialVisibility,
    required this.initialAudience,
    required this.initialMinTin,
    this.initialExpiresAt,
    required this.onConfirm,
  });

  @override
  State<AudienceSelectorBottomSheet> createState() =>
      _AudienceSelectorBottomSheetState();
}

class _AudienceSelectorBottomSheetState
    extends State<AudienceSelectorBottomSheet> {
  late String _visibility;
  late List<String> _selectedAudience;
  late double _minTin;
  DateTime? _expiresAt;

  List<User> _mockUsers = [];
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _visibility = widget.initialVisibility;
    _selectedAudience = List.from(widget.initialAudience);
    _minTin = widget.initialMinTin;
    _expiresAt = widget.initialExpiresAt;
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final db = AppDatabase();
      final users = await db.select(db.users).get();
      setState(() {
        _mockUsers = users;
        _isLoadingUsers = false;
      });
    } catch (_) {
      setState(() {
        _mockUsers = [
          User(
              id: 'usr-1',
              name: 'Nguyễn Văn An',
              type: 'both',
              kycStatus: 'verified',
              createdAt: DateTime(2026)),
          User(
              id: 'usr-2',
              name: 'Trần Thị Bình',
              type: 'both',
              kycStatus: 'verified',
              createdAt: DateTime(2026)),
          User(
              id: 'usr-3',
              name: 'Lê Hoàng Nam',
              type: 'both',
              kycStatus: 'none',
              createdAt: DateTime(2026)),
        ];
        _isLoadingUsers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom + 24;

    return Container(
      padding: EdgeInsets.fromLTRB(18, 18, 18, bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Thiết lập quyền chia sẻ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),

          // Visibility Level selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildVisibilityOption(
                type: 'private',
                label: 'Riêng tư',
                icon: Icons.lock_outline_rounded,
                color: Colors.grey,
              ),
              _buildVisibilityOption(
                type: 'team',
                label: 'Nhóm',
                icon: Icons.people_alt_rounded,
                color: const Color(0xFF6366F1),
              ),
              _buildVisibilityOption(
                type: 'community',
                label: 'Cộng đồng',
                icon: Icons.public_rounded,
                color: const Color(0xFF10B981),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Dynamic settings for Team/Network sharing
          if (_visibility == 'team') ...[
            const Text(
              'Chọn thành viên muốn chia sẻ:',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey),
            ),
            const SizedBox(height: 8),
            _isLoadingUsers
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    height: 120,
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      itemCount: _mockUsers.length,
                      itemBuilder: (context, index) {
                        final u = _mockUsers[index];
                        final isSelected = _selectedAudience.contains(u.id);
                        return CheckboxListTile(
                          title: Text(u.name,
                              style: const TextStyle(fontSize: 14)),
                          value: isSelected,
                          activeColor: const Color(0xFF6366F1),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedAudience.add(u.id);
                              } else {
                                _selectedAudience.remove(u.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 14),
            // HTI Slider threshold
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Chỉ số Tín tối thiểu:',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(_minTin.toStringAsFixed(1),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF06B6D4))),
              ],
            ),
            Slider(
              value: _minTin,
              min: 1.0,
              max: 5.0,
              divisions: 8,
              activeColor: const Color(0xFF06B6D4),
              onChanged: (val) {
                setState(() => _minTin = val);
              },
            ),
          ],

          if (_visibility == 'community') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF10B981)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bản ghi này sẽ xuất hiện trên Community Feed và tất cả người dùng trong hệ thống đều có quyền xem.',
                      style: TextStyle(fontSize: 12),
                    ),
                  )
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Expiry option
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Hạn chia sẻ:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              TextButton.icon(
                icon: const Icon(Icons.calendar_today_rounded,
                    size: 16, color: Color(0xFF6366F1)),
                label: Text(
                  _expiresAt == null
                      ? 'Vô thời hạn'
                      : '${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}',
                  style: const TextStyle(
                      color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _expiresAt = picked);
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 18),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              widget.onConfirm(
                  _visibility, _selectedAudience, _minTin, _expiresAt);
              Navigator.pop(context);
            },
            child: const Text('Xác nhận lưu',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityOption({
    required String type,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _visibility == type;
    return GestureDetector(
      onTap: () => setState(() => _visibility = type),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
