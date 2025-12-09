import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/feature/settings/excluded_routes/bloc/excluded_routes_bloc.dart';
import 'package:vpn/feature/settings/excluded_routes/view/widget/excluded_routes_screen_view.dart';

class ExcludedRoutesScreen extends StatefulWidget {
  const ExcludedRoutesScreen({super.key});

  @override
  State<ExcludedRoutesScreen> createState() => _ExcludedRoutesScreenState();
}

class _ExcludedRoutesScreenState extends State<ExcludedRoutesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ExcludedRoutesBloc>().add(const ExcludedRoutesEvent.init());
  }

  @override
  Widget build(BuildContext context) => const ExcludedRoutesScreenView();
}
