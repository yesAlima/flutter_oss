import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/dummy_data_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const PopulateDatabaseApp());
}

class PopulateDatabaseApp extends StatelessWidget {
  const PopulateDatabaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Populate Database',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const PopulateDatabaseScreen(),
    );
  }
}

class PopulateDatabaseScreen extends StatefulWidget {
  const PopulateDatabaseScreen({super.key});

  @override
  State<PopulateDatabaseScreen> createState() => _PopulateDatabaseScreenState();
}

class _PopulateDatabaseScreenState extends State<PopulateDatabaseScreen> {
  bool _isLoading = false;
  String _status = '';
  bool _isError = false;

  Future<void> _populateDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Database Population'),
        content: const Text(
          'This will clear all existing data and populate the database with test data. '
          'Are you sure you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _status = 'Starting database population...';
      _isError = false;
    });

    try {
      final dummyDataService = DummyDataService();
      await dummyDataService.populateDatabase();
      
      setState(() {
        _status = 'Database populated successfully!';
        _isError = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isError = true;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Database Clear'),
        content: const Text(
          'This will clear all existing data from the database. '
          'Are you sure you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear Database'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _status = 'Clearing database...';
      _isError = false;
    });

    try {
      final dummyDataService = DummyDataService();
      await dummyDataService.clearAllData();
      
      setState(() {
        _status = 'Database cleared successfully!';
        _isError = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isError = true;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Management'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                  ],
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _populateDatabase,
                    icon: const Icon(Icons.add_circle),
                    label: const Text('Populate Database'),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _clearDatabase,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Clear Database'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _status,
                style: TextStyle(
                  color: _isError ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 