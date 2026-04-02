abstract class IAudioDeviceRepository {
  Stream<(double, double)> get audioLevelStream;
  Future<Map<String, dynamic>> loadDevices();
  void liveVolumeUpdate({required double desktopVolume, required double micVolume});
  void liveDeviceUpdate({int? inputDeviceIndex, int? outputDeviceIndex});
  void liveMicToggle(bool useMic);
}
