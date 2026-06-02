import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_aspect.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope_aspect.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_aspect.dart';
import 'package:collection/collection.dart';

class PerAppProxyScreen extends StatefulWidget {
  const PerAppProxyScreen({super.key});

  @override
  State<PerAppProxyScreen> createState() => _PerAppProxyScreenState();
}

class _PerAppProxyScreenState extends State<PerAppProxyScreen> {
  bool _isLoading = true;
  bool _perAppProxy = false;
  bool _bypassApps = false;
  bool _needsRestart = false;
  
  List<AppInfo> _allApps = [];
  List<AppInfo> _displayedApps = [];
  Set<String> _selectedApps = {};
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterApps);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Update UI with saved settings immediately so the toggles don't flicker
      setState(() {
        _perAppProxy = prefs.getBool('per_app_proxy') ?? false;
        _bypassApps = prefs.getBool('bypass_apps') ?? false;
        _selectedApps = (prefs.getStringList('proxy_apps') ?? []).toSet();
      });
      
      // Fetch installed apps (excluding system apps, with icons)
      final apps = await InstalledApps.getInstalledApps(excludeSystemApps: true, withIcon: true);
      
      apps.sort((a, b) {
        final aSelected = _selectedApps.contains(a.packageName);
        final bSelected = _selectedApps.contains(b.packageName);
        if (aSelected && !bSelected) return -1;
        if (!aSelected && bSelected) return 1;
        return (a.name ?? '').compareTo(b.name ?? '');
      });
      
      setState(() {
        _allApps = apps;
        _displayedApps = List.from(_allApps);
      });
    } catch (e) {
      // Ignore errors for now
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _markNeedsRestart() {
    final vpn = VpnScope.vpnControllerMaybeOf(context, listen: false);
    if (vpn?.state == VpnState.connected && !_needsRestart) {
      setState(() {
        _needsRestart = true;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('per_app_proxy', _perAppProxy);
    await prefs.setBool('bypass_apps', _bypassApps);
    await prefs.setStringList('proxy_apps', _selectedApps.toList());
    _markNeedsRestart();
  }

  Future<void> _restartVpn() async {
    final vpn = VpnScope.vpnControllerMaybeOf(context, listen: false);
    if (vpn == null) return;

    final serverScope = ServersScope.controllerOf(context, aspect: ServersScopeAspect.selectedServer);
    final routingScope = RoutingScope.controllerOf(context, aspect: RoutingScopeAspect.profiles);
    final excludedRoutesScope = ExcludedRoutesScope.controllerOf(context, aspect: ExcludedRoutesAspect.routes);

    final server = serverScope.selectedServer;
    final routingProfile = routingScope.routingList.firstWhereOrNull((e) => e.id == server?.serverData.routingProfileId);
    final excludedRoutes = excludedRoutesScope.excludedRoutes;

    if (server != null && routingProfile != null) {
      // Temporarily clear the banner while restarting
      setState(() => _needsRestart = false);
      
      // Stop and restart
      await vpn.stop();
      // small delay to let platform settle
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        await vpn.start(
          server: server,
          routingProfile: routingProfile,
          excludedRoutes: excludedRoutes ?? [],
        );
      }
    }
  }

  void _filterApps() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _displayedApps = List.from(_allApps);
      } else {
        _displayedApps = _allApps.where((app) {
          return (app.name ?? '').toLowerCase().contains(query) ||
                 (app.packageName ?? '').toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _selectAll() {
    setState(() {
      for (var app in _displayedApps) {
        if (app.packageName != null) {
          _selectedApps.add(app.packageName!);
        }
      }
    });
    _saveSettings();
  }

  void _invertSelection() {
    setState(() {
      for (var app in _displayedApps) {
        if (app.packageName != null) {
          if (_selectedApps.contains(app.packageName)) {
            _selectedApps.remove(app.packageName);
          } else {
            _selectedApps.add(app.packageName!);
          }
        }
      }
    });
    _saveSettings();
  }

  Future<void> _exportToClipboard() async {
    final buffer = StringBuffer();
    buffer.writeln(_bypassApps.toString());
    for (var app in _selectedApps) {
      buffer.writeln(app);
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exported to clipboard')),
      );
    }
  }

  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text == null) return;
    
    final lines = data!.text!.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (lines.isEmpty) return;
    
    final bypassStr = lines.first.toLowerCase();
    if (bypassStr != 'true' && bypassStr != 'false') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid format: First line must be true or false')),
        );
      }
      return;
    }
    
    setState(() {
      _bypassApps = bypassStr == 'true';
      _selectedApps.clear();
      if (lines.length > 1) {
        _selectedApps.addAll(lines.sublist(1));
      }
    });
    await _saveSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imported successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Per-app Proxy'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'select_all':
                    _selectAll();
                    break;
                  case 'invert':
                    _invertSelection();
                    break;
                  case 'export':
                    _exportToClipboard();
                    break;
                  case 'import':
                    _importFromClipboard();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'select_all', child: Text('Select All Visible')),
                const PopupMenuItem(value: 'invert', child: Text('Invert Selection')),
                const PopupMenuItem(value: 'export', child: Text('Export to Clipboard')),
                const PopupMenuItem(value: 'import', child: Text('Import from Clipboard')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            if (_needsRestart)
              Container(
                color: Colors.orange.withOpacity(0.2),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Restart required to apply changes.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: _restartVpn,
                      child: const Text('Restart'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListTileTheme(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
                dense: true,
                child: Column(
                  children: [
                    SwitchListTile(
                      visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                      title: const Text('Enable Per-app Proxy'),
                      value: _perAppProxy,
                      onChanged: (val) {
                        setState(() => _perAppProxy = val);
                        _saveSettings();
                      },
                    ),
                    if (_perAppProxy) ...[
                      ListTile(
                        visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                        title: const Text('Route'),
                        trailing: DropdownButton<bool>(
                          value: _bypassApps,
                          items: const [
                            DropdownMenuItem(value: false, child: Text('Proxy Selected')),
                            DropdownMenuItem(value: true, child: Text('Bypass Selected')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _bypassApps = val);
                              _saveSettings();
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            labelText: 'Search Apps',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.all(12),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _isLoading 
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              itemCount: _displayedApps.length,
                              itemBuilder: (context, index) {
                                final app = _displayedApps[index];
                                final isSelected = _selectedApps.contains(app.packageName);
                                return CheckboxListTile(
                                  visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                                  secondary: app.icon != null 
                                    ? Image.memory(app.icon!, width: 32, height: 32)
                                    : const Icon(Icons.android, size: 32),
                                  title: Text(app.name ?? 'Unknown', style: const TextStyle(fontSize: 14)),
                                  subtitle: Text(app.packageName ?? '', style: const TextStyle(fontSize: 12)),
                                  value: isSelected,
                                  onChanged: (val) {
                                    if (val == null || app.packageName == null) return;
                                    setState(() {
                                      if (val) {
                                        _selectedApps.add(app.packageName!);
                                      } else {
                                        _selectedApps.remove(app.packageName!);
                                      }
                                    });
                                    _saveSettings();
                                  },
                                );
                              },
                            ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
