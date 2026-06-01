import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/api/hdrezka_types.dart';
import '../../../core/theme/app_theme.dart';

class TranslatorSelector extends StatefulWidget {
  final Map<int, TranslatorInfo> translators;
  final int? selectedId;
  final void Function(int translatorId) onChanged;

  const TranslatorSelector({
    super.key,
    required this.translators,
    required this.onChanged,
    this.selectedId,
  });

  @override
  State<TranslatorSelector> createState() => _TranslatorSelectorState();
}

class _TranslatorSelectorState extends State<TranslatorSelector> {
  late int? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedId ?? widget.translators.keys.firstOrNull;
    if (_selected != null && widget.selectedId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onChanged(_selected!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.translators.entries.toList();

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Перевод', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.onSurfaceMuted)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: entries.map((e) => _TranslatorChip(
                id: e.key,
                info: e.value,
                isSelected: _selected == e.key,
                onSelect: () {
                  setState(() => _selected = e.key);
                  widget.onChanged(e.key);
                },
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TranslatorChip extends StatefulWidget {
  final int id;
  final TranslatorInfo info;
  final bool isSelected;
  final VoidCallback onSelect;

  const _TranslatorChip({
    required this.id,
    required this.info,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  State<_TranslatorChip> createState() => _TranslatorChipState();
}

class _TranslatorChipState extends State<_TranslatorChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.select ||
               event.logicalKey == LogicalKeyboardKey.enter)) {
            widget.onSelect();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onSelect,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              gradient: widget.isSelected
                  ? const LinearGradient(
                      colors: [AppColors.accent, AppColors.accentSecondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withAlpha(_focused ? 45 : 22),
                        Colors.white.withAlpha(_focused ? 18 : 8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: _focused
                    ? AppColors.glassBorderFocus
                    : widget.isSelected
                        ? Colors.transparent
                        : AppColors.glassBorder,
                width: _focused ? 2 : 1,
              ),
              boxShadow: _focused
                  ? const [
                      BoxShadow(color: Color(0x50FFFFFF), blurRadius: 14),
                      BoxShadow(color: AppColors.accentGlow, blurRadius: 18, spreadRadius: -4),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.info.premium)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                  ),
                Text(
                  widget.info.name,
                  style: TextStyle(
                    color: widget.isSelected ? Colors.white : AppColors.onSurface,
                    fontSize: 15,
                    fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
