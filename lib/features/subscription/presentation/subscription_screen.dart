import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../apis/api.dart';
import '../../../core/network/api_provider.dart';
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/ui.dart';
import '../../auth/auth_controller.dart';

final subscriptionSummaryProvider =
    FutureProvider.autoDispose<SubscriptionSummary>((ref) async {
      final token = ref.watch(authControllerProvider).asData?.value;
      if (token == null || token.isEmpty) {
        throw const ApiException(
          'Your session has expired. Please sign in again.',
        );
      }
      return ref.watch(apiProvider).activeSubscription(token);
    });

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionSummaryProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          PageTitle(
            'Subscription & users',
            subtitle: 'Review your package and login-user allowance.',
            action: IconButton(
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(subscriptionSummaryProvider),
              icon: const Icon(Icons.refresh),
            ),
          ),
          const SizedBox(height: 18),
          subscription.when(
            loading: () => const Surface(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (error, _) => Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Unable to load subscription',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  const SizedBox(height: 6),
                  Text(error.toString()),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () =>
                        ref.invalidate(subscriptionSummaryProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
            data: (plan) => _SubscriptionContent(plan: plan),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionContent extends StatelessWidget {
  const _SubscriptionContent({required this.plan});
  final SubscriptionSummary plan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Surface(
          child: Wrap(
            spacing: 24,
            runSpacing: 20,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CURRENT PACKAGE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: Color(0xFF64736C),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    plan.name,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (plan.endDate != null) ...[
                    const SizedBox(height: 5),
                    Text('Valid until ${_date(plan.endDate!)}'),
                  ],
                ],
              ),
              _SeatRing(plan: plan),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth > 760
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Metric(
                  width: width,
                  label: 'Included users',
                  value: '${plan.includedUsers}',
                ),
                _Metric(
                  width: width,
                  label: 'Additional users',
                  value: '${plan.additionalUsers}',
                ),
                _Metric(
                  width: width,
                  label: 'Available seats',
                  value: plan.isUnlimited
                      ? 'Unlimited'
                      : '${plan.remainingUsers}',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.canAddUser
                    ? 'A login seat is available'
                    : 'User limit reached',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(_message(plan)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _showNextStep(context, plan),
                icon: Icon(
                  plan.tier == SubscriptionTier.lite
                      ? Icons.arrow_upward_rounded
                      : Icons.person_add_alt_1,
                ),
                label: Text(
                  plan.tier == SubscriptionTier.lite
                      ? 'Upgrade package'
                      : plan.canAddUser
                      ? 'Add user'
                      : 'Buy additional user',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Package user allowances',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        const _PlanTable(),
      ],
    );
  }

  static String _message(SubscriptionSummary plan) {
    if (plan.tier == SubscriptionTier.lite) {
      return 'Lite supports one login user and does not support paid additional users.';
    }
    if (plan.canAddUser) {
      return 'You can add another login user within your current allowance.';
    }
    return 'Basic, Standard and Advance packages can add paid users after an additional seat is activated.';
  }

  static void _showNextStep(BuildContext context, SubscriptionSummary plan) {
    final upgrading = plan.tier == SubscriptionTier.lite || !plan.canAddUser;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(upgrading ? 'Contact your account manager' : 'User setup'),
        content: Text(
          upgrading
              ? 'Package upgrades and additional-user payments must be activated on your business subscription before the new seat can be used.'
              : 'Your package has an available seat. User creation needs role and location options from the server, which are not currently exposed to this app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _SeatRing extends StatelessWidget {
  const _SeatRing({required this.plan});
  final SubscriptionSummary plan;

  @override
  Widget build(BuildContext context) {
    final label = plan.isUnlimited
        ? '${plan.activeUsers}'
        : '${plan.activeUsers}/${plan.userLimit}';
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const Text('active login users'),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.width,
    required this.label,
    required this.value,
  });
  final double width;
  final String label, value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64736C))),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}

class _PlanTable extends StatelessWidget {
  const _PlanTable();

  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      children: const [
        _PlanRow(name: 'Lite', users: '1 user', addOns: 'No additional users'),
        Divider(),
        _PlanRow(
          name: 'Basic',
          users: '1 user',
          addOns: 'Paid users available',
        ),
        Divider(),
        _PlanRow(
          name: 'Standard',
          users: '3 users',
          addOns: 'Paid users available',
        ),
        Divider(),
        _PlanRow(
          name: 'Advance',
          users: '5 users',
          addOns: 'Paid users available',
        ),
      ],
    ),
  );
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.name,
    required this.users,
    required this.addOns,
  });
  final String name, users, addOns;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(child: Text(users)),
        Expanded(flex: 2, child: Text(addOns, textAlign: TextAlign.end)),
      ],
    ),
  );
}
