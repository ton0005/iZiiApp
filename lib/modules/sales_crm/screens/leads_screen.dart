import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/crm_bloc.dart';
import 'add_lead_screen.dart';
import 'edit_lead_screen.dart';

class LeadsScreen extends StatelessWidget {
  const LeadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CrmBloc()..add(LoadLeadsEvent()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leads Management'),
          actions: [
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final result = await Navigator.of(ctx).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const AddLeadScreen(),
                    ),
                  );
                  if (result == true && ctx.mounted) {
                    ctx.read<CrmBloc>().add(LoadLeadsEvent());
                  }
                },
              ),
            ),
          ],
        ),
        body: BlocBuilder<CrmBloc, CrmState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.leads.isEmpty) {
              return const Center(child: Text('No leads found.'));
            }
            return ListView.builder(
              itemCount: state.leads.length,
              itemBuilder: (context, index) {
                final lead = state.leads[index] as Map<String, dynamic>;
                final customFields =
                    lead['custom_fields'] as Map<String, dynamic>? ?? {};

                return ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person, color: Color(0xFF6366F1)),
                  ),
                  title: Text(
                    lead['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Customer: ${lead['name']}'),
                      Text(
                        'Expected value: ${lead['expected_revenue']}',
                        style: const TextStyle(color: Colors.green),
                      ),
                      if (customFields.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: customFields.entries.map((entry) {
                            return Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                '${entry.key}: ${entry.value}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                  isThreeLine: customFields.isEmpty,
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      lead['status'],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  onTap: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => EditLeadScreen(lead: lead),
                      ),
                    );
                    if (result == true && context.mounted) {
                      context.read<CrmBloc>().add(LoadLeadsEvent());
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
