import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';

/// A styled searchable dropdown built on top of `dropdown_search`.
///
/// Wraps [DropdownSearch] with the Omni dark-theme aesthetic — dark popup
/// background, white text, and a compact 36px trigger height. Supports
/// custom [dropdownBuilder] and [itemBuilder] for fully customized rendering.
///
/// Example:
/// ```dart
/// OmniDropdown<String>(
///   items: ['English', 'Spanish', 'French'],
///   itemAsString: (lang) => lang,
///   selectedItem: _selected,
///   onChanged: (val) => setState(() => _selected = val),
/// )
/// ```
class OmniDropdown<T> extends StatelessWidget {
  /// The full list of items to display in the popup.
  final List<T> items;

  /// Converts an item of type [T] to its display string.
  final String Function(T) itemAsString;

  /// The currently selected item. Pass `null` to show the hint.
  final T? selectedItem;

  /// Custom equality function. Defaults to `==` if not provided.
  final bool Function(T, T)? compareFn;

  /// Called whenever the user selects a new item.
  final void Function(T?)? onChanged;

  /// Optional async guard called before a selection change is committed.
  /// Return `false` to cancel the change.
  final Future<bool> Function(T?, T?)? onBeforeChange;

  /// Placeholder text shown in the trigger and the search box.
  final String hintText;

  /// Whether to show a search box at the top of the popup. Defaults to `true`.
  final bool showSearchBox;

  /// Custom builder for the collapsed dropdown trigger display.
  final Widget Function(BuildContext, T?)? dropdownBuilder;

  /// Custom builder for each individual item row in the popup.
  final Widget Function(BuildContext, T, bool)? itemBuilder;

  /// Maximum height of the popup menu. Defaults to 300.
  final double maxHeight;

  /// Padding applied to the dropdown button area.
  final EdgeInsetsGeometry padding;

  const OmniDropdown({
    super.key,
    required this.items,
    required this.itemAsString,
    this.selectedItem,
    this.compareFn,
    this.onChanged,
    this.onBeforeChange,
    this.hintText = 'Search...',
    this.showSearchBox = true,
    this.dropdownBuilder,
    this.itemBuilder,
    this.maxHeight = 300,
    this.padding = EdgeInsets.zero,
  });

  InputDecoration _searchDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
      filled: true,
      fillColor: Colors.black26,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: DropdownSearch<T>(
        items: items,
        itemAsString: itemAsString,
        selectedItem: selectedItem,
        compareFn: compareFn,
        onChanged: onChanged,
        onBeforeChange: onBeforeChange,
        dropdownButtonProps: DropdownButtonProps(
          padding: padding,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          mouseCursor: SystemMouseCursors.basic,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: Colors.white38,
          ),
        ),
        dropdownDecoratorProps: DropDownDecoratorProps(
          baseStyle: const TextStyle(color: Colors.white, fontSize: 13),
          dropdownSearchDecoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.white70),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
        ),
        dropdownBuilder: dropdownBuilder ??
            (context, selected) {
              if (selected == null) return const SizedBox.shrink();
              return Text(
                itemAsString(selected),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                softWrap: false,
              );
            },
        popupProps: PopupProps.menu(
          showSearchBox: showSearchBox,
          fit: FlexFit.loose,
          constraints: BoxConstraints(maxHeight: maxHeight),
          searchDelay: Duration.zero,
          interceptCallBacks:
              itemBuilder !=
              null, // Usually used to manually handle tap in custom itemBuilder
          searchFieldProps: showSearchBox
              ? TextFieldProps(
                  autofocus: true,
                  decoration: _searchDecoration(hintText),
                )
              : const TextFieldProps(),
          menuProps: MenuProps(
            backgroundColor: const Color(0xFF2C2C2C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          itemBuilder: itemBuilder,
        ),
      ),
    );
  }
}
