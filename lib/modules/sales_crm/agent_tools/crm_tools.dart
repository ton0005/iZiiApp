import 'package:uuid/uuid.dart';
import '../../../core/ai_agent/models/chat_models.dart';
import '../bloc/crm_bloc.dart';
import 'crm_field_utils.dart';

List<AgentTool> getCrmAgentTools() {
  return [
    AgentTool(
      name: 'add_lead',
      description:
          'Them mot khach hang tiem nang moi vao CRM. Co the luu them cac truong moi trong custom_fields.',
      parameters: {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'Ten cua khach hang'},
          'phone': {'type': 'string', 'description': 'So dien thoai'},
          'notes': {'type': 'string', 'description': 'Ghi chu ve nhu cau'},
          'custom_fields': {
            'type': 'string',
            'description':
                'Chuoi mo ta cac truong bo sung ma CRM chua co san, vi du "budget: 2000 AUD".'
          },
        },
        'required': ['name'],
      },
      requiresConfirmation: true,
      execute: (args) async {
        final name = args['name'] as String;
        final notes = args['notes']?.toString();
        final customFields = readCustomFields(args);

        final newLead = {
          'id': const Uuid().v4(),
          'title': notes?.isNotEmpty == true ? notes : 'Nhu cau cua $name',
          'status': 'Khach hang moi',
          'name': name,
          'expected_revenue': 0.0,
          'custom_fields': customFields,
        };
        await CrmRepository().addLead(newLead);

        return 'Da tao Lead thanh cong!\n[LEAD:$name|Khach hang moi|0.0 VND|${newLead['title']}]';
      },
    ),
    AgentTool(
      name: 'update_lead',
      description:
          'Cap nhat thong tin, nhu cau, tri gia du kien, hoac cac truong moi cua lead nhu budget.',
      parameters: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Ten khach hang can cap nhat'
          },
          'notes': {
            'type': 'string',
            'description': 'Nhu cau hoac ghi chu moi'
          },
          'expected_revenue': {
            'type': ['number', 'string'],
            'description':
                'Tri gia hop dong du kien. Chap nhan so hoac chuoi nhu "300000000 VND".'
          },
          'budget': {
            'type': ['number', 'string'],
            'description':
                'Ngan sach cua khach hang neu user noi budget. Luu vao custom_fields.'
          },
          'custom_fields': {
            'type': 'string',
            'description':
                'Chuoi mo ta cac truong bo sung ma CRM chua co san, vi du "budget: 2000 AUD".'
          },
          'field_name': {
            'type': 'string',
            'description':
                'Ten truong moi can them neu CRM chua co san, vi du budget, preferred_brand, delivery_date.'
          },
          'field_value': {
            'type': 'string',
            'description': 'Gia tri cua truong moi can them, vi du "2000 AUD".'
          },
        },
        'required': ['name'],
      },
      requiresConfirmation: false,
      execute: (args) async {
        final name = args['name'] as String;
        final notes = args['notes']?.toString() ?? '';
        final expectedRevenue = parseMoneyValue(args['expected_revenue']);
        final customFields = readCustomFields(args);

        final success = await CrmRepository().updateLead(
          name,
          notes,
          expectedRevenue,
          customFields: customFields,
        );

        if (success) {
          final fieldSummary = formatCustomFields(customFields);
          final extra =
              fieldSummary.isEmpty ? '' : ' Truong moi: $fieldSummary.';
          return 'Da cap nhat thanh cong khach hang $name.$extra';
        }
        return 'Khong tim thay khach hang nao co ten $name trong he thong de cap nhat.';
      },
    ),
    AgentTool(
      name: 'search_leads',
      description:
          'Tim kiem hoac kiem tra xem co khach hang/lead nao voi ten cu the trong he thong hay khong',
      parameters: {
        'type': 'object',
        'properties': {
          'name_query': {
            'type': 'string',
            'description': 'Ten khach hang can tim, co the la mot phan cua ten'
          },
        },
        'required': ['name_query'],
      },
      requiresConfirmation: false,
      execute: (args) async {
        final nameQuery = args['name_query'] as String;
        final leads = await CrmRepository().getLeads();

        final matches = leads
            .where((l) =>
                (l['name'] as String)
                    .toLowerCase()
                    .contains(nameQuery.toLowerCase()) ||
                (l['title'] as String)
                    .toLowerCase()
                    .contains(nameQuery.toLowerCase()))
            .toList();

        if (matches.isEmpty) {
          return 'Khong tim thay khach hang nao co ten chua "$nameQuery".';
        }

        final results = matches.map((l) {
          final name = l['name'] as String;
          final status = l['status'] as String;
          final revenue = '${l['expected_revenue']} VND';
          final title = l['title'] as String;
          final customFields =
              l['custom_fields'] as Map<String, dynamic>? ?? {};
          final customText = formatCustomFields(customFields);
          final suffix = customText.isEmpty ? '' : '|$customText';
          return '[LEAD:$name|$status|$revenue|$title$suffix]';
        }).join('\n');
        return 'Tim thay ${matches.length} khach hang khop voi "$nameQuery":\n$results';
      },
    ),
    AgentTool(
      name: 'list_all_leads',
      description: 'Hien thi danh sach tat ca cac khach hang tiem nang',
      parameters: const {
        'type': 'object',
        'properties': {},
      },
      requiresConfirmation: false,
      execute: (args) async {
        final leads = await CrmRepository().getLeads();
        if (leads.isEmpty) {
          return 'Hien tai khong co khach hang nao trong he thong.';
        }
        final results = leads.map((l) {
          final name = l['name'] as String;
          final status = l['status'] as String;
          final revenue = '${l['expected_revenue']} VND';
          final title = l['title'] as String;
          final customFields =
              l['custom_fields'] as Map<String, dynamic>? ?? {};
          final customText = formatCustomFields(customFields);
          final suffix = customText.isEmpty ? '' : '|$customText';
          return '[LEAD:$name|$status|$revenue|$title$suffix]';
        }).join('\n');
        return 'Danh sach khach hang hien co:\n$results';
      },
    ),
    AgentTool(
      name: 'get_pipeline_summary',
      description: 'Lay tom tat duong ong ban hang hien tai',
      parameters: {
        'type': 'object',
        'properties': {},
      },
      execute: (args) async {
        return 'Duong ong hien tai: 5 Lead moi, 2 Deal dang dam phan, 1 Deal da chot thanh cong. Tong gia tri ky vong: 150.000.000 VND.';
      },
    ),
  ];
}
