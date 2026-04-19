import 'package:flutter/material.dart';
import '../../domain/repositories/printer_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

enum PrinterStatus {
  initial,
  scanning,
  scanSuccess,
  scanFailure,
  connecting,
  connected,
  connectionFailure,
  disconnected,
  testPrinting
}

class PrinterState extends Equatable {
  final PrinterStatus status;
  final String? connectedMac;
  final String? connectedName;
  final List<BluetoothInfo> devices;
  final String? errorMessage;

  const PrinterState({
    this.status = PrinterStatus.initial,
    this.connectedMac,
    this.connectedName,
    this.devices = const [],
    this.errorMessage,
  });

  PrinterState copyWith({
    PrinterStatus? status,
    String? connectedMac,
    String? connectedName,
    List<BluetoothInfo>? devices,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PrinterState(
      status: status ?? this.status,
      connectedMac: connectedMac ?? this.connectedMac,
      connectedName: connectedName ?? this.connectedName,
      devices: devices ?? this.devices,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props =>
      [status, connectedMac, connectedName, devices, errorMessage];
}

class PrinterProvider extends ChangeNotifier {
  final PrinterRepository repository;

  PrinterState _state = const PrinterState();
  PrinterState get state => _state;

  PrinterProvider({required this.repository});
  
  void _emit(PrinterState newState) {
    _state = newState;
    notifyListeners();
  }

  void init() {
    final mac = repository.getSavedPrinterMac();
    final name = repository.getSavedPrinterName();
    _emit(state.copyWith(
      status: PrinterStatus.initial,
      connectedMac: mac,
      connectedName: name,
    ));
  }

  Future<void> refresh() async {
    _emit(state.copyWith(status: PrinterStatus.scanning, clearError: true));
    try {
      final devices = await repository.scanDevices();
      if (devices.isEmpty) {
        _emit(state.copyWith(
          status: PrinterStatus.scanFailure,
          errorMessage: 'No paired devices found.',
          devices: [],
        ));
        return;
      }

      bool connected = false;
      for (var device in devices) {
        final success = await repository.connect(device.macAdress);
        if (success) {
          await repository.savePrinterData(device.macAdress, device.name);
          _emit(state.copyWith(
            status: PrinterStatus.connected,
            connectedMac: device.macAdress,
            connectedName: device.name,
            devices: devices,
            clearError: true,
          ));
          connected = true;
          break;
        }
      }

      if (!connected) {
        _emit(state.copyWith(
          status: PrinterStatus.scanFailure,
          errorMessage: 'Could not connect to any paired device.',
          devices: devices,
        ));
      }
    } catch (e) {
      _emit(state.copyWith(
        status: PrinterStatus.scanFailure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> scanPrinters() async {
    _emit(state.copyWith(status: PrinterStatus.scanning, clearError: true));
    try {
      final devices = await repository.scanDevices();
      _emit(state.copyWith(
        status: PrinterStatus.scanSuccess,
        devices: devices,
      ));
    } catch (e) {
      _emit(state.copyWith(
        status: PrinterStatus.scanFailure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> connectPrinter(String mac, String name) async {
    _emit(state.copyWith(status: PrinterStatus.connecting, clearError: true));
    final success = await repository.connect(mac);
    if (success) {
      await repository.savePrinterData(mac, name);
      _emit(state.copyWith(
        status: PrinterStatus.connected,
        connectedMac: mac,
        connectedName: name,
      ));
    } else {
      _emit(state.copyWith(
        status: PrinterStatus.connectionFailure,
        errorMessage: 'Failed to connect to printer',
      ));
    }
  }

  Future<void> disconnectPrinter() async {
    await repository.disconnect();
    await repository.clearPrinterData();
    _emit(PrinterState(
      status: PrinterStatus.disconnected,
      devices: state.devices,
    ));
  }

  Future<void> testPrint(String shopName) async {
    _emit(state.copyWith(status: PrinterStatus.testPrinting));
    await repository.testPrint(shopName);
    _emit(state.copyWith(status: PrinterStatus.scanSuccess));
  }
}
