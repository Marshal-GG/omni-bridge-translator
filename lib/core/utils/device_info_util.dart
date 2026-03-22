import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

class DeviceInfoUtil {
  /// Collects device hardware and network info.
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    final info = <String, dynamic>{'platform': 'Windows Desktop'};

    try {
      final deviceInfo = DeviceInfoPlugin();
      final win = await deviceInfo.windowsInfo;
      info['computer_name'] = win.computerName;
      info['user_name'] = win.userName;
      info['os_version'] =
          '${win.majorVersion}.${win.minorVersion}.${win.buildNumber}';
      info['product_name'] = win.productName;
      info['system_memory_mb'] = win.systemMemoryInMegabytes;
    } catch (e) {
      debugPrint('[DeviceInfoUtil] device_info error: $e');
    }

    try {
      final net = NetworkInfo();
      info['wifi_ip'] = await net.getWifiIP() ?? 'N/A';
      info['wifi_name'] = await net.getWifiName() ?? 'N/A';
      info['wifi_bssid'] = await net.getWifiBSSID() ?? 'N/A';
      info['wifi_ipv6'] = await net.getWifiIPv6() ?? 'N/A';
      info['wifi_gateway'] = await net.getWifiGatewayIP() ?? 'N/A';
      info['wifi_submask'] = await net.getWifiSubmask() ?? 'N/A';
    } catch (e) {
      debugPrint('[DeviceInfoUtil] network_info error: $e');
    }

    return info;
  }
}
