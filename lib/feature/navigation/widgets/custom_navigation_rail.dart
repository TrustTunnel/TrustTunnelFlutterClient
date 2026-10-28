import 'package:flutter/material.dart';
import 'package:trusttunnel/feature/navigation/widgets/navigation_rail_update_button.dart';

class CustomNavigationRail extends StatelessWidget {
  final VoidCallback onUpdatePressed;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationRailDestination> destinations;

  const CustomNavigationRail({
    super.key,
    required this.selectedIndex,
    required this.onUpdatePressed,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 80,
    child: Column(
      children: [
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: IntrinsicHeight(
                  child: NavigationRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onDestinationSelected,
                    labelType: NavigationRailLabelType.all,
                    destinations: destinations,
                  ),
                ),
              ),
            ),
          ),
        ),
        NavigationRailUpdateButton(onPressed: onUpdatePressed),
      ],
    ),
  );
}
