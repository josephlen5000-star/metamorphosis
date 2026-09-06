import 'package:device_preview/device_preview.dart';
import 'package:flutter/cupertino.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/firebase_service.dart';
import 'theme/app_colors.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late Future<bool> _isFirstTimeFuture;

  @override
  void initState() {
    super.initState();
    _isFirstTimeFuture = FirebaseService().isFirstTimeUser();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.accent,
        primaryContrastingColor: CupertinoColors.white,
        scaffoldBackgroundColor: AppColors.background,
        barBackgroundColor: AppColors.chrome,
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
          ),
          navTitleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          navActionTextStyle: TextStyle(
            fontSize: 17,
            color: AppColors.accent,
          ),
        ),
      ),
      home: FutureBuilder<bool>(
        future: _isFirstTimeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CupertinoPageScaffold(
              backgroundColor: AppColors.background,
              child: Center(
                child: CupertinoActivityIndicator(),
              ),
            );
          }

          if (snapshot.hasError) {
            return const CupertinoPageScaffold(
              backgroundColor: AppColors.background,
              child: Center(
                child: Text('Error loading app'),
              ),
            );
          }

          final isFirstTime = snapshot.data ?? true;
          return isFirstTime
              ? OnboardingScreen(
                  onOnboardingComplete: () {
                    setState(() {
                      _isFirstTimeFuture = Future.value(false);
                    });
                  },
                )
              : const HomeScreen();
        },
      ),
    );
  }
}
