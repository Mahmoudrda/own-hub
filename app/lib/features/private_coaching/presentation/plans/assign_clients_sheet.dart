library;

import 'package:flutter/material.dart';

import '../../../../domain/format/number_label.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_list_item.dart';
import '../desk/desk_text.dart';

class AssignClient {
  const AssignClient({required this.subId, required this.name});
  final String subId;
  final String name;
}

class AssignChoice {
  const AssignChoice(this.subIds, this.startsOn);
  final Set<String> subIds;
  final DateTime startsOn;
}

/// Shown by the "Send to more clients" button. [mine] is locked on.
class AssignClientsSheet extends StatefulWidget {
  const AssignClientsSheet({
    super.key,
    required this.mine,
    required this.others,
    required this.initial,
    required this.startsOn,
  });

  final AssignClient mine;
  final List<AssignClient> others;
  final Set<String> initial;
  final DateTime startsOn;

  @override
  State<AssignClientsSheet> createState() => _AssignClientsSheetState();
}

class _AssignClientsSheetState extends State<AssignClientsSheet> {
  late final Set<String> _picked = {...widget.initial};
  late DateTime _date = widget.startsOn;

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: first,
      lastDate: first.add(const Duration(days: 60)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final count = _picked.length + 1;
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.whoGetsThisPlan, style: AppText.titleL),
          CheckboxListTile(
            key: ValueKey('assign-client-${widget.mine.subId}'),
            value: true,
            onChanged: null,
            title: Text(widget.mine.name),
          ),
          for (final c in widget.others)
            CheckboxListTile(
              key: ValueKey('assign-client-${c.subId}'),
              value: _picked.contains(c.subId),
              onChanged: (on) => setState(
                () =>
                    on == true ? _picked.add(c.subId) : _picked.remove(c.subId),
              ),
              title: Text(c.name),
            ),
          AppListItem(
            key: const ValueKey('assign-date'),
            title: l10n.startDate,
            subtitle: dateText(l10n, _date),
            onTap: _pickDate,
          ),
          AppButton(
            l10n.chooseNClients(countLabel(count)),
            key: const ValueKey('assign-done'),
            onPressed: () =>
                Navigator.of(context).pop(AssignChoice({..._picked}, _date)),
          ),
        ],
      ),
    );
  }
}
