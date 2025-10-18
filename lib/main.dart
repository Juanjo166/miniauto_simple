import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MiniAutoSimple());
}

class MiniAutoSimple extends StatelessWidget {
  const MiniAutoSimple({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiniAuto Simple',
      theme: ThemeData.dark(),
      home: const ControlScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  BluetoothConnection? connection;
  bool isConnected = false;
  int speed = 50;
  String lastCommand = 'Ninguno';

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  // Solicitar permisos de Bluetooth
  Future<void> _requestPermissions() async {
    // Mostrar diálogo explicativo
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permisos necesarios'),
          content: const Text('Esta app necesita permisos de Bluetooth y Ubicación para funcionar.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }

    // Esperar un momento
    await Future.delayed(const Duration(seconds: 1));

    // Solicitar permisos
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    // Verificar resultados
    if (statuses[Permission.bluetoothConnect]!.isDenied || 
        statuses[Permission.bluetoothScan]!.isDenied) {
      _showSnackBar('⚠️ Permisos denegados. Ve a Ajustes → Apps → MiniAuto → Permisos');
      
      // Abrir configuración de la app
      await openAppSettings();
    }
  }

  // Enviar comando por Bluetooth
  void sendCommand(String command) {
    setState(() {
      lastCommand = command;
    });
    
    if (isConnected && connection != null) {
      try {
        connection!.output.add(utf8.encode(command));
        print('Enviado: $command');
      } catch (e) {
        print('Error al enviar: $e');
        _showSnackBar('Error al enviar comando');
      }
    } else {
      print('No conectado - Comando: $command');
      _showSnackBar('No conectado al MiniAuto');
    }
  }

  // Mostrar lista de dispositivos Bluetooth
  Future<void> _showDeviceList() async {
    // Verificar permisos primero
    bool bluetoothConnectGranted = await Permission.bluetoothConnect.isGranted;
    bool bluetoothScanGranted = await Permission.bluetoothScan.isGranted;
    
    if (!bluetoothConnectGranted || !bluetoothScanGranted) {
      _showSnackBar('Por favor, concede los permisos de Bluetooth');
      await _requestPermissions();
      return;
    }

    try {
      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      
      if (!mounted) return;
      
      if (devices.isEmpty) {
        _showSnackBar('No hay dispositivos emparejados. Empareja el HC-05/HC-06 primero.');
        return;
      }
      
      BluetoothDevice? selectedDevice = await showDialog<BluetoothDevice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Seleccionar MiniAuto'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(devices[index].name ?? 'Desconocido'),
                  subtitle: Text(devices[index].address),
                  onTap: () => Navigator.pop(context, devices[index]),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );

      if (selectedDevice != null) {
        await _connectToDevice(selectedDevice);
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  // Conectar al dispositivo
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      _showSnackBar('Conectando...');
      
      BluetoothConnection conn = await BluetoothConnection.toAddress(device.address);
      
      setState(() {
        connection = conn;
        isConnected = true;
      });
      
      _showSnackBar('✓ Conectado a ${device.name}');
      
      // Escuchar desconexión
      connection!.input!.listen(
        (data) {
          // Aquí puedes recibir datos del Arduino si es necesario
          print('Recibido: ${String.fromCharCodes(data)}');
        },
        onDone: () {
          setState(() {
            isConnected = false;
            connection = null;
          });
          _showSnackBar('Desconectado');
        },
      );
      
    } catch (e) {
      _showSnackBar('Error al conectar: $e');
      setState(() {
        isConnected = false;
        connection = null;
      });
    }
  }

  // Desconectar
  void _disconnect() {
    if (connection != null) {
      connection!.dispose();
      setState(() {
        isConnected = false;
        connection = null;
      });
      _showSnackBar('Desconectado');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    connection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚗 MiniAuto Control'),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Estado de conexión
            Card(
              color: isConnected ? Colors.green[900] : Colors.grey[850],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                          color: isConnected ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isConnected ? 'Conectado' : 'Desconectado',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: isConnected ? _disconnect : _showDeviceList,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isConnected ? Colors.red : Colors.blue,
                      ),
                      child: Text(isConnected ? 'Desconectar' : 'Conectar'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Último comando
            Text(
              'Último comando: $lastCommand',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            
            const SizedBox(height: 16),
            
            // Control direccional
            const Text(
              'Control de Movimiento',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // Botones de dirección
            Column(
              children: [
                // Arriba
                _buildButton('↑', 'Arriba', () => sendCommand('A|0|\$')),
                const SizedBox(height: 8),
                
                // Izquierda - Centro - Derecha
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildButton('←', 'Izq', () => sendCommand('A|4|\$')),
                    const SizedBox(width: 8),
                    _buildButton('■', 'Stop', () => sendCommand('A|8|\$'), color: Colors.red),
                    const SizedBox(width: 8),
                    _buildButton('→', 'Der', () => sendCommand('A|2|\$')),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Abajo
                _buildButton('↓', 'Abajo', () => sendCommand('A|6|\$')),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Rotación
            const Text(
              'Rotación',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => sendCommand('A|10|\$'),
                    icon: const Icon(Icons.rotate_left, size: 20),
                    label: const Text('Girar Izq'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => sendCommand('A|9|\$'),
                    icon: const Icon(Icons.rotate_right, size: 20),
                    label: const Text('Girar Der'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Control de velocidad
            const Text(
              'Velocidad',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: speed.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 10,
                    label: '$speed%',
                    onChanged: (value) {
                      setState(() {
                        speed = value.toInt();
                      });
                    },
                    onChangeEnd: (value) {
                      sendCommand('C|${value.toInt()}|\$');
                    },
                  ),
                ),
                Text(
                  '$speed%',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Botón evitar obstáculos
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => sendCommand('F|1|\$'),
                icon: const Icon(Icons.shield),
                label: const Text('Evitar Obstáculos ON'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String icon, String label, VoidCallback onPressed, {Color? color}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Colors.blue,
        minimumSize: const Size(70, 70),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 28),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}