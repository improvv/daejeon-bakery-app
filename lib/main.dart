import 'package:flutter/material.dart';
import 'screens/root_screen.dart'; // 수정됨: 진입점을 RootScreen으로 변경

void main() {
  runApp(const DaejeonBakeryApp());
}

class DaejeonBakeryApp extends StatelessWidget {
  const DaejeonBakeryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '대전 빵집 지도',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFD97941),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD97941),
          primary: const Color(0xFFD97941),
        ),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToMain();
  }

  Future<void> _navigateToMain() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        // 수정됨: MainScreen -> RootScreen으로 진입!
        MaterialPageRoute(builder: (context) => const RootScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5E6D3), Color(0xFFFFE8CC)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bakery_dining, size: 100, color: Color(0xFFD97941)),
              SizedBox(height: 24),
              Text(
                '빵집지도',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C2C2C),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '대전의 모든 베이커리',
                style: TextStyle(fontSize: 15, color: Color(0xFF6B6B6B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
