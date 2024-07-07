import 'package:flutter/material.dart';
import 'package:vpn_plugin/api.dart';

class TestWidget extends StatefulWidget {
  const TestWidget({super.key});

  @override
  State<TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<TestWidget> {
  final _api = PlatformApi();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Test widget'),
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: _getPlatformType,
            child: const Text('Get platform version'),
          ),
        ),
      );

  Future<void> _getPlatformType() async {
    final request = GetPlatformTypeRequest()..testParam = 42;
    final response = await _api.getPlatformType(request);
    print(response.platformType);
  }
}
