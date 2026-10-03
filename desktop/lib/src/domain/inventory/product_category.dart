/// A group a product belongs to.
///
/// ## Why a category exists at all
///
/// The specification names `product_categories` in the schema (section 22). For a
/// business with a hundred products and two categories the operator retypes the
/// same name a hundred times and gets a flat stock report. Categories are reference
/// data for **inventory and sales reports only** — see ADR 013, which also decides
/// what a category is *not*: it has no account and posts nothing.
///
/// ## Identity follows ADR 010 and ADR 012, for the same reasons
///
/// - **`id` is random and permanent.** Products reference a category by id, so an
///   id that moved would silently reclassify historical stock.
/// - **`code` is the business reference** — `ELEC-01` — printed on a stock report.
/// - **Name is not a key.** Names repeat and are mutable. A unique index on a name
///   would reject two legitimate categories and turn a spelling correction into a
///   lost record, so duplicate detection comes from the code instead.
///
/// ## A category is optional on a product
///
/// A product with no category is an ordinary product, not an incomplete one. Making
/// it mandatory would force category records before anything could be sold, and
/// would require backfilling a placeholder onto every historical product — which
/// would put a category on products that never had one, and that is a fabrication.
class ProductCategory {
  const ProductCategory._({
    required this.id,
    required this.code,
    required this.name,
    this.parentId,
  });

  factory ProductCategory({
    required String id,
    required String code,
    required String name,
    String? parentId,
  }) {
    final trimmedId = _requireText(id, 'A category needs an id.');
    final trimmedParent = _blankToNull(parentId);

    // **A self-parent is refused at construction**, not caught by a report. A
    // cycle walked while resolving depth would loop forever, and a hang is a worse
    // failure than a wrong number because nothing fails visibly.
    if (trimmedParent == trimmedId) {
      throw ArgumentError.value(
        parentId,
        'parentId',
        'A category cannot be its own parent. That would be a cycle, and '
            'resolving the depth of a cycle never ends.',
      );
    }

    return ProductCategory._(
      id: trimmedId,
      code: _requireText(code, 'A category needs a code.'),
      name: _requireText(name, 'A category needs a name.'),
      parentId: trimmedParent,
    );
  }

  /// Random, permanent, never reused. See the class docblock.
  final String id;

  /// The business reference, `ELEC-01`. **Not the identity.**
  final String code;

  /// The name as a person says it. **Not a key.**
  final String name;

  /// The parent category's id, or `null` when this category is top level.
  final String? parentId;

  /// Whether this category sits at the top of its tree.
  bool get isTopLevel => parentId == null;

  /// What a person quotes: the code.
  ///
  /// **Never the id** — an id is meaningless outside the system, and printing one
  /// on a report invites the reader to treat it as a business reference.
  String get displayReference => code;

  /// How deep this category sits, counting itself as 0.
  ///
  /// [lookup] resolves an id to a category, returning `null` when it does not
  /// exist. Returns `null` when the parent **cannot be resolved**, because a
  /// depth that cannot be computed is not zero — see [assertWithinV1Depth].
  ///
  /// **Walks the whole chain, not just to [maxDepth].** A first version stopped
  /// at `maxDepth`, which made [assertWithinV1Depth] unable to detect a too-deep
  /// tree at all: the very check that exists to refuse one could never see one.
  /// The bound belongs in the caller that decides what is acceptable, not in the
  /// function that measures.
  ///
  /// **Termination is guaranteed by [visited], not by a depth limit.** A cycle
  /// written straight to the database would otherwise walk forever, and a hang is
  /// a worse failure than a wrong number because nothing fails visibly.
  int? depthOf(ProductCategory? Function(String id) lookup) {
    if (parentId == null) return 0;

    // Seeded at 0, not 1: `depth` counts **hops to the root**, and this category
    // has not yet made one. Seeding at 1 and incrementing counted the parent as a
    // level as well, so a category one level down reported depth 2 — which is
    // exactly what `assertWithinV1Depth` compares against `maxDepth`, so the
    // boundary would have been off by one in the permissive direction.
    var depth = 0;
    var current = this;
    final visited = <String>{id};

    while (current.parentId != null) {
      final parent = lookup(current.parentId!);
      if (parent == null) return null;
      if (!visited.add(parent.id)) return null;
      current = parent;
      depth++;
    }
    return depth;
  }

  /// Throws unless this category is a tree V1 can report.
  ///
  /// Two refusals, both because the alternative is silently wrong:
  ///
  /// - **A parent that does not exist.** Treating it as top level would place the
  ///   category at the root in a grouped report — a different answer, and one
  ///   nobody chose.
  /// - **A tree deeper than [maxDepth].** It is representable and unreportable, so
  ///   storing it would produce a report that silently groups wrongly. Refusing at
  ///   write time is cheap, and relaxing the limit later is a one-line change.
  void assertWithinV1Depth(Map<String, ProductCategory> all) {
    if (parentId == null) return;

    if (!all.containsKey(parentId)) {
      throw CategoryDepthException(
        category: this,
        reason: CategoryDepthReason.unknownParent,
        detail: 'No category with id "$parentId" exists, so "$name" has no '
            'parent it can be reported under.',
      );
    }

    final depth = depthOf((id) => all[id]);

    // A depth of `null` here means the chain broke partway, which the branch above
    // has already refused — but it is checked rather than assumed, because a `!`
    // on a value that can legitimately be null is how a refusal turns into a
    // crash instead of an explanation.
    if (depth != null && depth > maxDepth) {
      throw CategoryDepthException(
        category: this,
        reason: CategoryDepthReason.tooDeep,
        detail: '"$name" sits more than $maxDepth level(s) down. This version '
            'reports at most one level of nesting, and a deeper category would '
            'be grouped wrongly in a stock report.',
      );
    }
  }

  /// How many levels of nesting V1 reports. See ADR 013.
  static const int maxDepth = 1;

  /// A copy with different details. [id] cannot change.
  ///
  /// [clearParent] exists because `null` otherwise cannot be distinguished from
  /// "not supplied". Without it an optional parent could be **set** but never
  /// **removed**, so a category could never be promoted to top level.
  ProductCategory copyWith({
    String? code,
    String? name,
    String? parentId,
    bool clearParent = false,
  }) {
    return ProductCategory(
      id: id,
      code: code ?? this.code,
      name: name ?? this.name,
      parentId: clearParent ? null : (parentId ?? this.parentId),
    );
  }

  @override
  bool operator ==(Object other) => other is ProductCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ProductCategory($code, $name)';

  static String _requireText(String value, String message) {
    if (value.trim().isEmpty) throw ArgumentError(message);
    return value.trim();
  }

  /// Blank means absent, so `''` and `null` cannot become two spellings of one
  /// fact. A blank parent stored as `''` would match no category yet not be null,
  /// so a "top level" query would quietly miss it.
  static String? _blankToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// Why a category cannot be reported by this version.
enum CategoryDepthReason {
  /// The stated parent id matches no category.
  unknownParent,

  /// The category sits below the depth this version reports.
  tooDeep,
}

/// Raised when a category's tree cannot be represented by the V1 reports.
///
/// The alternative is a report that silently groups wrongly, so this is a refusal
/// rather than a clamp. See ADR 013.
class CategoryDepthException implements Exception {
  CategoryDepthException({
    required this.category,
    required this.reason,
    required this.detail,
  });

  final ProductCategory category;
  final CategoryDepthReason reason;

  /// A sentence a user can act on, rather than a class name.
  final String detail;

  @override
  String toString() => 'CategoryDepthException: $detail';
}