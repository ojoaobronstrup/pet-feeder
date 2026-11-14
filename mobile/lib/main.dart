import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      body: Center(child: TextButton(
          onPressed: togglePower,
          child: Text('Ligar'),
      ))
    ),
  ));
}

Future<void> togglePower() async {
  final client = HttpClient();
  try {
    final request = await client.get('192.168.3.53', 5087, '/power/toggle');
    final response = await request.close();
    await response.drain<void>();
    debugPrint('Resposta da API: ${response.statusCode}');
  } catch (e) {
    debugPrint('Erro ao alternar energia: $e');
  } finally {
    client.close();
  }
}
