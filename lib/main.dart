import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          theme: ThemeData(
            colorScheme: lightDynamic ?? ThemeData.light().colorScheme,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkDynamic ?? ThemeData.dark().colorScheme,
            useMaterial3: true,
          ),
          home: TemperatureScreen(),
        );
      },
    );
  }
}

class TemperatureScreen extends StatefulWidget {
  const TemperatureScreen({super.key});

  @override
  _TemperatureScreenState createState() => _TemperatureScreenState();
}

class _TemperatureScreenState extends State<TemperatureScreen> {
  String _temperature = 'Cargando...';
  bool _isLoading = true;
  bool _isOn = false;
  double _thresholdTemperature = 25.0; // Valor por defecto
  Timer? _timer;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initPrefs();
    fetchTemperature();
    startTimer();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _thresholdTemperature = _prefs.getDouble('thresholdTemp') ?? 25.0;
    });
  }

  Future<void> _saveThreshold(double value) async {
    await _prefs.setDouble('thresholdTemp', value);
  }

  Future<void> fetchTemperature() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.128.236/temperature'),
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        double currentTemp =
            double.tryParse(data['temperatura'].toString()) ?? 0.0;

        setState(() {
          _temperature = '${currentTemp.toStringAsFixed(1)}°C';
          _isLoading = false;
        });

        // Control automático basado en la temperatura
        if (currentTemp > _thresholdTemperature && !_isOn) {
          await toggleHS100(context, shouldNotify: false);
        } else if (currentTemp <= _thresholdTemperature && _isOn) {
          await toggleHS100(context, shouldNotify: false);
        }
      } else {
        setState(() {
          _temperature = 'Error al cargar';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _temperature = 'Error de conexión';
        _isLoading = false;
      });
    }
  }

  Future<void> toggleHS100(
    BuildContext context, {
    bool shouldNotify = true,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.128.236/${_isOn ? 'off' : 'on'}'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _isOn = !_isOn;
        });
        if (shouldNotify) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("HS100 ${_isOn ? 'encendido' : 'apagado'}")),
          );
        }
      } else if (shouldNotify) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al ${_isOn ? 'apagar' : 'encender'} el HS100"),
          ),
        );
      }
    } catch (e) {
      if (shouldNotify) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error de conexión: $e")));
      }
    }
  }

  void startTimer() {
    _timer = Timer.periodic(Duration(seconds: 30), (timer) {
      fetchTemperature();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SettingsScreen(
              thresholdTemperature: _thresholdTemperature,
              onThresholdChanged: (value) {
                setState(() {
                  _thresholdTemperature = value;
                });
                _saveThreshold(value);
              },
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Aclimatate'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isLoading
                ? CircularProgressIndicator()
                : Column(
                  children: [
                    Text(_temperature, style: TextStyle(fontSize: 24)),
                    SizedBox(height: 10),
                    Text(
                      'Umbral: ${_thresholdTemperature.toStringAsFixed(1)}°C',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
            SizedBox(height: 20),
            FloatingActionButton(
              onPressed: () => toggleHS100(context),
              backgroundColor: _isOn ? Colors.green : Colors.red,
              child: Icon(_isOn ? Icons.power_off : Icons.power),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final double thresholdTemperature;
  final ValueChanged<double> onThresholdChanged;

  const SettingsScreen({
    super.key,
    required this.thresholdTemperature,
    required this.onThresholdChanged,
  });

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _currentThreshold;

  @override
  void initState() {
    super.initState();
    _currentThreshold = widget.thresholdTemperature;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Configuración')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Temperatura umbral: ${_currentThreshold.toStringAsFixed(1)}°C',
              style: TextStyle(fontSize: 18),
            ),
            Slider(
              value: _currentThreshold,
              min: 0,
              max: 100,
              divisions: 100,
              label: _currentThreshold.toStringAsFixed(1),
              onChanged: (value) {
                setState(() {
                  _currentThreshold = value;
                });
                widget.onThresholdChanged(value);
              },
            ),
            SizedBox(height: 20),
            Text(
              'Cuando la temperatura supere este valor, el dispositivo se encenderá automáticamente.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
