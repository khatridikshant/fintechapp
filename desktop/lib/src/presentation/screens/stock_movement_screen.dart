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
/// Which way a stock movement moves the goods.
///
/// Only ever asked for reasons whose direction is **not** implied by the reason
/// itself — currently just an adjustment, which is either a found surplus or a
/// shortage. Every other reason carries its direction in its name, so offering a
/// control for them would invite the user to contradict the meaning of the word
/// they picked.
enum StockDirection {
  /// More stock than the books recorded: goods coming in.
  arriving,

  /// Fewer goods than the books recorded: goods going out.
  leaving,
}

/// The form for recording goods arriving or leaving.
///
/// ## Why the content is width-constrained
///
/// Without a maximum, the three fields stretched the full width of a desktop
/// window — a 1,400-pixel input line is hard to scan, and the eye loses its place
/// crossing it. Constraining the form and centring it keeps the labels, the inputs
/// and the button in one readable column whatever the window size.
///
/// The widest the form is allowed to get.
///
/// Wide enough for a currency amount to sit comfortably, narrow enough that the
/// eye does not have to travel across the window to check a label against its
/// value. Roughly the width of the Business-details form.
const double stockMovementFormMaxWidth = 720;

/// The form for recording goods arriving or leaving.
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

  /// Which way an **adjustment** moves stock.
  ///
  /// Only consulted for [MovementReason.adjustment]. Every other reason's direction
  /// is implied by the reason itself, so showing a control for them would offer a
  /// choice that does not exist.
  StockDirection _direction = StockDirection.arriving;
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

  /// Builds the movement, with its direction taken from **the reason**.
  ///
  /// ## Why this exists
  ///
  /// It used to call `InventoryMovement.receipt(...)` unconditionally. Every reason
  /// therefore produced stock coming **in**, so choosing "Sale" credited cost of
  /// goods sold instead of debiting it, raised stock, raised profit by the value of
  /// the goods, and recognised no revenue. Nothing detected it: the entry balanced,
  /// the trial balance balanced and the balance sheet balanced, because the entry was
  /// well formed and simply meant the opposite of what was asked for.
  ///
  /// There was also **no way to record an issue at all**, so `sale` — the only reason
  /// that posts cost of goods sold — was unreachable from the application.
  ///
  /// The SQLite `CHECK` constraints eventually refused it, and the user saw a raw
  /// `SqliteException` where a stock sale should simply have worked.
  ///
  /// ## Why the domain decides, not this method
  ///
  /// [MovementReason.isReceipt] already encodes which way each reason moves stock,
  /// and it is the same rule the posting use case keys off. Deriving the direction
  /// here from that one predicate means the screen and the journal cannot disagree
  /// about what "Sale" means.
  InventoryMovement _movementFor({
    required MovementReason reason,
    required int quantity,
    required Money value,
  }) {
    final id = 'mv-${DateTime.now().microsecondsSinceEpoch}';
    final productId = _product.text.trim();
    final date = DateTime.now();

    // A write-down is the one reason whose shape is different: the goods are still
    // held, so the quantity does not move and only the carrying value falls. It is
    // the only value-only movement the domain permits.
    if (reason == MovementReason.writeDown) {
      return InventoryMovement(
        id: id,
        productId: productId,
        date: date,
        reason: reason,
        quantity: 0,
        value: value.negated(),
      );
    }

    // A stock-count correction can go either way, so the operator says which. It is
    // the only reason whose direction is not implied by its own name.
    if (reason == MovementReason.adjustment) {
      return _direction == StockDirection.leaving
          ? InventoryMovement.issue(
              id: id,
              productId: productId,
              date: date,
              reason: reason,
              quantity: quantity,
              value: value,
            )
          : InventoryMovement.receipt(
              id: id,
              productId: productId,
              date: date,
              reason: reason,
              quantity: quantity,
              value: value,
            );
    }

    return reason.isReceipt
        ? InventoryMovement.receipt(
            id: id,
            productId: productId,
            date: date,
            reason: reason,
            quantity: quantity,
            value: value,
          )
        : InventoryMovement.issue(
            id: id,
            productId: productId,
            date: date,
            reason: reason,
            quantity: quantity,
            value: value,
          );
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
      final movement = _movementFor(
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

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: stockMovementFormMaxWidth),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            Text('Record stock', style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              // **Both directions.** This used to say "Stock arriving, or written
              // off", which described half the form. Since the direction is taken
              // from the chosen reason, the screen records goods leaving just as
              // often as goods arriving, and telling a user who is recording a
              // sale that they are receiving stock is simply wrong.
              'Stock arriving or leaving, or written off. The value is what the '
              'stock is worth, not a price you type per unit.',
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

                  // **One label, not two.** There used to be a `Why` heading here with
                  // the dropdown's own `Reason` label directly beneath it, so the user
                  // read "Why" and "Reason" as two separate things. The field's own
                  // label is the one that stays: it sits with the control it names and
                  // it is what every other field on this screen does.
                  //
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
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _reason = value),
                  ),

                  // **Only for a reason whose direction is genuinely open.**
                  //
                  // Shown for an adjustment alone: a stock count can find a surplus or
                  // a shortage, whereas "Sale" already means the goods left. Offering
                  // this control for every reason would let the user contradict the
                  // meaning of the word they just picked, and the resulting movement
                  // would be well formed and wrong.
                  if (_reason == MovementReason.adjustment) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    SegmentedButton<StockDirection>(
                      key: const ValueKey<String>('movement-direction-field'),
                      segments: const <ButtonSegment<StockDirection>>[
                        ButtonSegment<StockDirection>(
                          value: StockDirection.arriving,
                          label: Text('Found more'),
                        ),
                        ButtonSegment<StockDirection>(
                          value: StockDirection.leaving,
                          label: Text('Found fewer'),
                        ),
                      ],
                      selected: <StockDirection>{_direction},
                      onSelectionChanged: _busy
                          ? null
                          : (Set<StockDirection> selected) =>
                              setState(() => _direction = selected.first),
                    ),
                  ],
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
        ),
      ),
    );
  }
}
