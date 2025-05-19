import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:dynamic_color/dynamic_color.dart';

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
  Timer? _timer;

  Future<void> fetchTemperature() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.128.236/temperature'),
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _temperature = '${data['temperatura']}°C';
          _isLoading = false;
        });
      } else {
        setState(() {
          _temperature = 'Error al cargar la temperatura';
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

  Future<void> toggleHS100(BuildContext context) async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.128.236/${_isOn ? 'off' : 'on'}'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _isOn = !_isOn;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("HS100 ${_isOn ? 'encendido' : 'apagado'}")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al ${_isOn ? 'apagar' : 'encender'} el HS100"),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error de conexión: $e")));
    }
  }

  void startTimer() {
    _timer = Timer.periodic(Duration(seconds: 30), (timer) {
      fetchTemperature();
    });
  }

  @override
  void initState() {
    super.initState();
    fetchTemperature();
    startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Aclimatate')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isLoading
                ? CircularProgressIndicator()
                : Text(_temperature, style: TextStyle(fontSize: 24)),
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
