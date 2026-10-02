import 'package:flutter/material.dart';

import '../../application/post_inventory_movement.dart';
import '../../domain/inventory/inventory_movement.dart';
import '../../domain/shared/money.dart';
import '../theme/app_theme.dart';

/// The Stock Movement screen: receiving stock, or writing it off.
///
/// ## Why this screen chooses so little
///
/// Two decisions belong to the domain and are not offered here:
///
/// - **The value is what the stock is worth, not a price the user invents.** ADR
///   004 makes the running inventory *value* authoritative and derives the cost
///   from it. The user says how many units and what they are worth, together.
/// - **Negative stock is refused** by the repository, inside the transaction. The
///   screen does not pre-judge it, because it cannot know the current level.
///
/// The one choice offered is *why* the stock moved — purchase, opening stock, a
/// return, a write-off — because that is a fact only the user knows, and it
/// changes how the movement reads later.
class StockMovementScreen extends StatefulWidget {
  const StockMovementScreen({super.key, required this.postMovement});

  final PostInventoryMovement postMovement;

  @override
  State<StockMovementScreen> createState() => _StockMovementScreenState();
}

class _StockMovementScreenState extends State<StockMovementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _product = TextEditingController();
  final _quantity = TextEditingController();
  final _value = TextEditingController();

  MovementReason? _reason = MovementReason.purchase;
  bool _busy = false;
  String? _problem;
  String? _done;

  @override
  void dispose() {
    _product.dispose();
    _quantity.dispose();
    _value.dispose();
    super.dispose();
  }

  int? _parseQuantity(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  Money? _parseValue(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final value = num.tryParse(text);
    if (value == null) return null;
    return Money.fromMajorUnits(value, 'NPR');
  }

  Future<void> _post() async {
    final quantity = _parseQuantity(_quantity.text);
    final value = _parseValue(_value.text);
    final reason = _reason;

    if (_product.text.trim().isEmpty) {
      setState(() => _problem = 'Enter the product.');
      return;
    }
    if (quantity == null || quantity <= 0) {
      setState(() => _problem = 'Enter a quantity of at least 1.');
      return;
    }
    if (value == null) {
      setState(() => _problem = 'Enter what the stock is worth.');
      return;
    }
    if (reason == null) {
      setState(() => _problem = 'Choose why the stock moved.');
      return;
    }

    setState(() {
      _busy = true;
      _problem = null;
      _done = null;
    });

    try {
      final movement = InventoryMovement.receipt(
        id: 'mv-${DateTime.now().microsecondsSinceEpoch}',
        productId: _product.text.trim(),
        date: DateTime.now(),
        reason: reason,
        quantity: quantity,
        value: value,
      );

      final outcome = await widget.postMovement(movement);
      if (!mounted) return;

      switch (outcome) {
        case InventoryMovementPosted(:final stock):
          setState(() {
            _busy = false;
            _done = 'Recorded. ${stock.quantity} in stock now.';
            // Cleared in place: the fields still reference these controllers.
            _quantity.clear();
            _value.clear();
          });
        case InventoryMovementRejected(:final message):
          setState(() {
            _busy = false;
            // The use case's own wording, not a second version of it.
            _problem = message;
          });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = 'The movement could not be recorded. $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Text('Record stock', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Stock arriving, or written off. The value is what the stock is worth, '
          'not a price you type per unit.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_done != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: palette.canvas,
                border: Border.all(color: palette.positive),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.check_circle_outline,
                      size: 18, color: palette.positive),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(_done!, style: textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                key: const ValueKey<String>('movement-product-field'),
                controller: _product,
                enabled: !_busy,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Product'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey<String>('movement-quantity-field'),
                controller: _quantity,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  helperText: 'Whole units',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey<String>('movement-value-field'),
                controller: _value,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Total value',
                  helperText: 'What this quantity is worth, in total.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Text('Why', style: textTheme.labelSmall),
              const SizedBox(height: AppSpacing.xs),
              // A dropdown, not a switch: there are several reasons and only the
              // user knows which applies.
              DropdownButtonFormField<MovementReason>(
                key: const ValueKey<String>('movement-reason-field'),
                initialValue: _reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: <DropdownMenuItem<MovementReason>>[
                  for (final reason in MovementReason.values)
                    DropdownMenuItem<MovementReason>(
                      value: reason,
                      child: Text(reason.label),
                    ),
                ],
                onChanged:
                    _busy ? null : (value) => setState(() => _reason = value),
              ),
              const SizedBox(height: AppSpacing.lg),

              FilledButton.icon(
                key: const ValueKey<String>('movement-post-button'),
                onPressed: _busy ? null : _post,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.inventory_outlined, size: 18),
                label: const Text('Record stock'),
              ),
            ],
          ),
        ),
        if (_problem != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            _problem!,
            style: textTheme.bodyMedium?.copyWith(color: palette.error),
          ),
        ],
      ],
    );
  }
}
