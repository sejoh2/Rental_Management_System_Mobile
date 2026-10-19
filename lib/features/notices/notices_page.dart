import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../models/repair.dart';
import '../../utils/format.dart';
import '../../widgets/cards.dart';
import '../../widgets/message_box.dart';
import '../../widgets/status_chip.dart';
import '../repairs/repair_page.dart';

/// What is new: repairs the owner reported in the caretaker's properties,
/// or gave to them. Opening one marks it as read.
class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key});

  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  bool _marking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The list on screen is the latest.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AppScope.read(context).notices.check(),
    );
  }

  Future<void> _markAll() async {
    setState(() {
      _marking = true;
      _error = null;
    });

    try {
      await AppScope.read(context).notices.markAllSeen();
    } on ApiException catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<void> _open(Repair repair) async {
    final services = AppScope.read(context);
    final property = services.properties.properties
        ?.where((item) => item.id == repair.propertyId)
        .firstOrNull;

    if (property == null) return;

    services.notices.seen(repair.id);

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RepairPage(property: property, repair: repair),
      ),
    );

    services.notices.check();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final services = AppScope.of(context);
    final items = services.notices.items;
    final several = (services.properties.properties?.length ?? 0) > 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: _marking ? null : _markAll,
              child: Text(_marking ? 'Marking...' : 'Mark all as read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: services.notices.check,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.md,
            AppSpace.page,
            AppSpace.xxl,
          ),
          children: [
            if (_error != null) ...[
              ErrorBox(_error!),
              const SizedBox(height: AppSpace.md),
            ],
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: EmptyView(
                  icon: Icons.notifications_none,
                  title: 'Nothing new',
                  message:
                      'When the owner reports a repair, or gives one to you, it shows here.',
                ),
              ),
            for (final repair in items) ...[
              AppCard(
                onTap: () => _open(repair),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconBadge(
                      icon: repair.caretakerNotice == 'assigned'
                          ? Icons.assignment_ind_outlined
                          : Icons.build_outlined,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            repair.caretakerNotice == 'assigned'
                                ? 'The owner gave you a repair'
                                : 'The owner reported a repair',
                            style: AppText.small.copyWith(
                              color: colors.inkFaint,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            repair.title,
                            style: AppText.label.copyWith(color: colors.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              repair.unitNumber == null
                                  ? 'Whole property'
                                  : 'House ${repair.unitNumber}',
                              if (several && repair.propertyName != null)
                                repair.propertyName!,
                              if (repair.caretakerNoticeAt != null)
                                formatDay(repair.caretakerNoticeAt!),
                            ].join(' · '),
                            style: AppText.small.copyWith(
                              color: colors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (repair.priority == 'urgent')
                      const StatusChip('Urgent', tone: Tone.danger)
                    else if (repair.priority == 'high')
                      const StatusChip('High', tone: Tone.accent),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.sm),
            ],
          ],
        ),
      ),
    );
  }
}
