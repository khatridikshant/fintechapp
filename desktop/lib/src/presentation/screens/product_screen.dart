import 'package:flutter/material.dart';

import '../../application/create_product.dart';
import '../theme/app_theme.dart';

/// The New Product screen.
///
/// A **catalogue entry**, not a supplier or customer: it carries no PAN and
/// appears on no tax document as a counterparty, so there is nothing to validate
/// beyond a name and a price.
///
/// ## What it decides
///
/// Only what a person has to tell it. **The cost is not asked for and must not
/// be**: ADR 004 makes the running inventory *value* authoritative and derives
/// the cost from it, so a stored cost would be a second source of truth that
/// drifts. The cost arrives when stock is received, through a stock movement.
class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, required this.createProduct});

  final CreateProduct createProduct;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();

  bool _trackStock = true;
  bool _busy = false;
  String? _savedName;
  String? _problem;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  /// The typed price, or null when it is not a number.
  ///
  /// **A blank price is a price of zero**, which is allowed: a product may be
  /// given away. That is deliberately different from an invoice line, where a
  /// zero is treated as a data-entry mistake.
  num? _parsePrice(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return 0;
    return num.tryParse(text);
  }

  Future<void> _save() async {
    final price = _parsePrice(_price.text);
    if (price == null) {
      setState(
          () => _problem = 'Enter a sale price, or leave it blank for zero.');
      return;
    }
    if (_name.text.trim().isEmpty) {
      setState(() => _problem = 'Enter a name.');
      return;
    }

    setState(() {
      _busy = true;
      _problem = null;
      _savedName = null;
    });

    try {
      final outcome = await widget.createProduct(
        name: _name.text.trim(),
        salePriceRupees: price,
        stockTrackingEnabled: _trackStock,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _savedName = outcome.product.name;
        // Cleared in place: the live fields still reference these controllers.
        _name.clear();
        _price.clear();
        _trackStock = true;
      });
    } on ProductRejected catch (rejection) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = rejection.reason;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = 'The product could not be saved. $error';
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
        Text('New product', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Something you sell. Its cost comes from the stock you record, not from '
          'here.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_savedName != null)
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
                    child: Text(
                      'Saved $_savedName.',
                      style: textTheme.bodyMedium,
                    ),
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
                key: const ValueKey<String>('product-name-field'),
                controller: _name,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey<String>('product-price-field'),
                controller: _price,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Sale price',
                  helperText:
                      'Leave blank if you do not sell it, or give it away.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // A service has no stock to run out, so it is exempt from the
              // negative-stock rule. The domain enforces that; this only records
              // what the product is.
              CheckboxListTile(
                key: const ValueKey<String>('product-track-stock-field'),
                value: _trackStock,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _trackStock = value ?? true),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Track stock for this product'),
                subtitle: Text(
                  'Turn this off for a service, or something you do not hold.',
                  style: textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                key: const ValueKey<String>('product-save-button'),
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_box_outlined, size: 18),
                label: const Text('Save product'),
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
