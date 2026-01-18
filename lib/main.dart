import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Quita el banner feo de "Debug"
      title: 'Descifrando la Guerra',
      theme: ThemeData.dark(), // Establece un tema oscuro de base
      home: const HomeScreen(), // <--- Llama a tu pantalla principal
    );
  }
}
