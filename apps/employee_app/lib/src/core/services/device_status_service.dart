import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final deviceStatusServiceProvider = Provider<DeviceStatusService>((ref) {
  return DeviceStatusService(battery: Battery(), connectivity: Connectivity());
});

class DeviceStatusService {
  const DeviceStatusService({
    required Battery battery,
    required Connectivity connectivity,
  }) : _battery = battery,
       _connectivity = connectivity;

  final Battery _battery;
  final Connectivity _connectivity;

  Future<DeviceStatusSnapshot> snapshot() async {
    final batteryLevel = await _battery.batteryLevel;
    final connectivity = await _connectivity.checkConnectivity();
    return DeviceStatusSnapshot(
      batteryPercent: batteryLevel,
      internetStatus: _label(connectivity),
    );
  }

  String _label(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) return 'Wi-Fi';
    if (results.contains(ConnectivityResult.mobile)) return 'Mobile Data';
    if (results.contains(ConnectivityResult.ethernet)) return 'Ethernet';
    if (results.contains(ConnectivityResult.vpn)) return 'VPN';
    return 'Offline';
  }
}

class DeviceStatusSnapshot {
  const DeviceStatusSnapshot({
    required this.batteryPercent,
    required this.internetStatus,
  });

  final int batteryPercent;
  final String internetStatus;
}
