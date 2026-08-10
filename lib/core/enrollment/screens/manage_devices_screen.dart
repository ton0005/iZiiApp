import 'package:flutter/material.dart';

import '../widgets/device_list_view.dart';
import 'issue_enrollment_screen.dart';

/// Màn hình riêng toàn màn hình cho quản lý thiết bị.
///
/// Chỉ còn là lớp vỏ Scaffold mỏng bọc quanh [DeviceListView] — toàn bộ logic
/// nằm trong widget đó để dùng chung được với bản nhúng trong tab Settings.
/// Giữ màn hình này vì danh sách dài thì xem toàn màn hình vẫn dễ hơn.
class ManageDevicesScreen extends StatefulWidget {
  const ManageDevicesScreen({super.key});

  @override
  State<ManageDevicesScreen> createState() => _ManageDevicesScreenState();
}

class _ManageDevicesScreenState extends State<ManageDevicesScreen> {
  final _listKey = GlobalKey<DeviceListViewState>();

  Future<void> _issueNewCode() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const IssueEnrollmentScreen()),
    );
    _listKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thiết bị đã đăng ký')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _issueNewCode,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Cấp mã mới'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: DeviceListView(key: _listKey, shrinkWrap: false),
      ),
    );
  }
}
