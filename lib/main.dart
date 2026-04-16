import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'dart:async';

// Bootstrap Design Constants
class BootstrapTheme {
  static const Color primary = Color(0xFF0D6EFD);
  static const Color secondary = Color(0xFF6C757D);
  static const Color success = Color(0xFF198754);
  static const Color danger = Color(0xFFDC3545);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF0DCAF0);
  static const Color light = Color(0xFFF8F9FA);
  static const Color dark = Color(0xFF212529);
  static const Color darkBg = Color(0xFF1A1A1A);
  static const Color accent = Color(0xFF00E5FF);

  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacing = 12;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;
  static const double spacingXxl = 48;

  static const double borderRadius = 8;
  static const double borderRadiusLg = 12;
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Toggle between splash screen and main simulator screen.
  bool _showSplash = true;

  @override
  // Official Screen
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AeroCalc - Drone Flight Simulator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: BootstrapTheme.darkBg,
        fontFamily: GoogleFonts.k2d().fontFamily,
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: BootstrapTheme.primary,
          secondary: BootstrapTheme.accent,
          error: BootstrapTheme.danger,
          surface: const Color(0xFF2E2E2E),
        ),
      ),
      home: _showSplash
          ? SplashScreen(onFinished: () => setState(() => _showSplash = false))
          : const MyHomePage(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const SplashScreen({super.key, required this.onFinished});

  @override
  // hon aamlna call lal state tabaa splash ta ye2dar yharek video.
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  bool _isWeb = false;
  bool _showVideo = false;
  Timer? _fallbackTimer;

  @override
  // first step ll spalsh screen
  void initState() {
    super.initState();
    _isWeb = kIsWeb;
    _startSplash();
  }

  // video or fallback , ---> home screen
  void _startSplash() {
    // Web fallback: skip video and move on quickly.
    if (_isWeb) {
      _startFallbackTimer();
      return;
    }

    _controller = VideoPlayerController.asset('assets/Color_Matte.mp4');
    _controller!
        .initialize()
        .then((_) {
          if (!mounted || _controller == null) return;

          setState(() {
            // Show splash video once ready.
            _showVideo = true;
          });

          _controller!.play();
          _controller!.addListener(_handleVideoState);
        })
        .catchError((Object error) {
          debugPrint('Splash video failed: $error');
          _startFallbackTimer();
        });
  }

  // home screen after the splash screen
  void _handleVideoState() {
    final controller = _controller;
    if (controller == null || !mounted) return;

    if (controller.value.hasError) {
      debugPrint('Splash video error: ${controller.value.errorDescription}');
      _startFallbackTimer();
      return;
    }

    final position = controller.value.position;
    final duration = controller.value.duration;
    // Continue to the home page when the splash video ends.
    if (duration > Duration.zero && position >= duration) {
      widget.onFinished();
    }
  }

  // timer ehteyate eza video msh zabet ma ywa22ef el app.
  void _startFallbackTimer() {
    if (_fallbackTimer?.isActive ?? false) return;
    _fallbackTimer = Timer(const Duration(seconds: 2), widget.onFinished);
  }

  @override
  // hon eza video ready btftah splash video, eza la btftah logo w loading indicator.
  Widget build(BuildContext context) {
    final controller = _controller;
    final isVideoReady =
        _showVideo && controller != null && controller.value.isInitialized;

    return Scaffold(
      body: isVideoReady
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/logoappp.png', width: 140, height: 140),
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
    );
  }

  @override
  // hon mnna2e el video w el timer eza ma aamlna splash video.
  void dispose() {
    _fallbackTimer?.cancel();
    _controller?.removeListener(_handleVideoState);
    _controller?.dispose();
    super.dispose();
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  // hawn mnkhalle2 el state taba3 el simulator el ra2isi.
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  // If estimated failure is >= 1%, we classify the setup as danger.
  static const double _dangerFailureThreshold = 0.01;

  late int weight;
  String selectedMotor = '4 Motors';
  String thrustMotor = '';
  String batteryCapacity = '';
  String selectedVoltage = '11.1v';
  late TextEditingController weightController;
  late TextEditingController thrustController;
  late TextEditingController batteryController;
  late double twr;
  late double failureProbability;
  late Color statusColor;
  late String statusMessage;
  late double flightTimeEstimate;
  Timer? _dangerVibrationTimer;
  VideoPlayerController? _safeResultVideoController;
  bool _isSafeResultVideoReady = false;

  // Animation controllers for safety indicator
  late AnimationController _safetyAnimationController;
  late Animation<double> _safetyProgressAnimation;
  late Animation<Color?> _safetyColorAnimation;

  @override
  // hawn mnjhaz kel el variables w animations abl ma ybalesh el esteemel.
  void initState() {
    super.initState();
    weight = 0;
    weightController = TextEditingController();
    thrustController = TextEditingController();
    batteryController = TextEditingController();
    twr = 0.0;
    failureProbability = 1.0;
    statusColor = BootstrapTheme.secondary;
    statusMessage = '';
    flightTimeEstimate = 0.0;

    // Initialize animation controllers
    _safetyAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _safetyProgressAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _safetyAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _safetyColorAnimation =
        ColorTween(
          begin: BootstrapTheme.secondary,
          end: BootstrapTheme.secondary,
        ).animate(
          CurvedAnimation(
            parent: _safetyAnimationController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  // hon mnsaker controllers w timers ta ydal el state ndef.
  void dispose() {
    _dangerVibrationTimer?.cancel();
    _safeResultVideoController?.dispose();
    _safetyAnimationController.dispose();
    weightController.dispose();
    thrustController.dispose();
    batteryController.dispose();
    super.dispose();
  }

  // hon mnhawel el voltage mn string la ra2em byfhamo.
  double _getVoltageFromString(String voltageStr) {
    return double.parse(voltageStr.replaceAll('v', ''));
  }

  // hon mnshaghel vibration lama el result ykoun dangerous.
  void _startDangerVibration() {
    _dangerVibrationTimer?.cancel();
    _dangerVibrationTimer = Timer.periodic(const Duration(milliseconds: 500), (
      _,
    ) async {
      if (failureProbability >= _dangerFailureThreshold && mounted) {
        await Vibration.vibrate(duration: 100);
      } else {
        _dangerVibrationTimer?.cancel();
      }
    });
  }

  // hon mnwaef el vibration lama ma yeb2a fi danger.
  void _stopDangerVibration() {
    _dangerVibrationTimer?.cancel();
    _dangerVibrationTimer = null;
  }

  // hon mnshaghel video el result el mnih iza kel shi tamem.
  Future<void> _showSafeResultVideo() async {
    final existingController = _safeResultVideoController;
    if (existingController != null && existingController.value.isInitialized) {
      await existingController.seekTo(Duration.zero);
      await existingController.play();
      if (mounted && !_isSafeResultVideoReady) {
        setState(() {
          _isSafeResultVideoReady = true;
        });
      }
      return;
    }

    _safeResultVideoController?.dispose();
    final controller = VideoPlayerController.asset('assets/Color Matte_2.mp4');
    _safeResultVideoController = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();

      if (!mounted || _safeResultVideoController != controller) {
        await controller.dispose();
        return;
      }

      setState(() {
        _isSafeResultVideoReady = true;
      });
    } catch (error) {
      debugPrint('Safe result video failed: $error');
      if (_safeResultVideoController == controller) {
        _safeResultVideoController = null;
      }
      await controller.dispose();
      if (mounted) {
        setState(() {
          _isSafeResultVideoReady = false;
        });
      }
    }
  }

  // hon mnkhabe w mnsaker video el result lama ma yeb2a lazem.
  void _hideSafeResultVideo() {
    final controller = _safeResultVideoController;
    _safeResultVideoController = null;
    _isSafeResultVideoReady = false;
    controller?.pause();
    controller?.dispose();
  }

  // hon mnraje3 el simulation men el awal w mnaaml clean la kel el inputs.
  void _resetSimulation() {
    _stopDangerVibration();
    _hideSafeResultVideo();
    weightController.clear();
    thrustController.clear();
    batteryController.clear();

    setState(() {
      weight = 0;
      thrustMotor = '';
      batteryCapacity = '';
      selectedMotor = '4 Motors';
      selectedVoltage = '11.1v';
      twr = 0.0;
      failureProbability = 1.0;
      statusColor = BootstrapTheme.secondary;
      statusMessage = '';
      flightTimeEstimate = 0.0;
    });

    _safetyAnimationController.reset();
    _safetyProgressAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _safetyAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _safetyColorAnimation =
        ColorTween(
          begin: BootstrapTheme.secondary,
          end: BootstrapTheme.secondary,
        ).animate(
          CurvedAnimation(
            parent: _safetyAnimationController,
            curve: Curves.easeInOut,
          ),
        );
  }

  // hon mn2adder wa2t el teyran 3a ases el motors w battery w weight.
  double _estimateFlightTime(
    int numMotors,
    double thrust,
    double batteryMah,
    double voltage,
    int weightGrams,
  ) {
    if (thrust <= 0 ||
        batteryMah <= 0 ||
        voltage <= 0 ||
        weightGrams <= 0 ||
        numMotors <= 0) {
      return 0.0;
    }

    // Convert drone mass from grams to Newtons.
    final totalWeightN = (weightGrams / 1000.0) * 9.81;
    final hoverThrustPerMotor = totalWeightN / numMotors;
    final hoverFraction = (hoverThrustPerMotor / thrust).clamp(0.08, 1.25);

    // Approximate electrical model for hover-to-cruise current draw.
    final currentPerMotorA = 1.8 + (19.0 * pow(hoverFraction, 1.7));
    final voltageEfficiency = (voltage / 11.1).clamp(0.85, 1.2);
    final systemCurrentA =
        ((currentPerMotorA * numMotors) + 1.5) / voltageEfficiency;

    // Assume 80% usable capacity to protect the battery from deep discharge.
    final usableBatteryAh = (batteryMah / 1000.0) * 0.8;
    final flightTimeMinutes = (usableBatteryAh / systemCurrentA) * 60.0;

    if (!flightTimeMinutes.isFinite || flightTimeMinutes.isNaN) return 0.0;
    return flightTimeMinutes.clamp(0.0, 60.0);
  }

  // hon mnhseb addeh fi ehtemel fashal bel teyran 3a ases el TWR.
  double _estimateFailureProbability(double twr, int numMotors) {
    // TWR <= 1 means no thrust margin to safely sustain flight.
    if (twr <= 1.0) return 1.0;

    // Exponential decay: at TWR=2.0, base failure probability is about 1%.
    final baseProbability = exp(-4.605 * (twr - 1.0));
    // More motors give redundancy, so failure risk is reduced.
    final motorRedundancyFactor = switch (numMotors) {
      8 => 0.70,
      6 => 0.82,
      _ => 1.0,
    };

    final failure = baseProbability * motorRedundancyFactor;
    return failure.clamp(0.0005, 1.0);
  }

  // hon mnaaml input field mratab maa label w style wahad
  Widget _buildFormField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required Function(String) onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BootstrapTheme.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFB0B0B0),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: BootstrapTheme.spacingSm),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF404040), width: 1),
              borderRadius: BorderRadius.circular(BootstrapTheme.borderRadius),
              color: const Color(0xFF2A2A2A),
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              keyboardType: keyboardType,
              style: const TextStyle(
                color: BootstrapTheme.accent,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: BootstrapTheme.spacingMd,
                  vertical: BootstrapTheme.spacing,
                ),
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFF707070),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // hon mnaaml dropdown la yekhtar el user men options jdide.
  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BootstrapTheme.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFB0B0B0),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: BootstrapTheme.spacingSm),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF404040), width: 1),
              borderRadius: BorderRadius.circular(BootstrapTheme.borderRadius),
              color: const Color(0xFF2A2A2A),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BootstrapTheme.spacingMd,
              ),
              child: DropdownButton<String>(
                value: value,
                onChanged: onChanged,
                isExpanded: true,
                underline: const SizedBox(),
                items: items.map<DropdownMenuItem<String>>((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      style: const TextStyle(color: BootstrapTheme.accent),
                    ),
                  );
                }).toList(),
                dropdownColor: const Color(0xFF2A2A2A),
                style: const TextStyle(color: BootstrapTheme.accent),
                icon: const Icon(
                  Icons.expand_more,
                  color: BootstrapTheme.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // hon mnaaml card container la nratteb el sections b style wahad
  Widget _buildCard({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        border: Border.all(color: const Color(0xFF3A3A3A), width: 1),
        borderRadius: BorderRadius.circular(BootstrapTheme.borderRadiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BootstrapTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: BootstrapTheme.accent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF808080),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: BootstrapTheme.spacingMd),
            const Divider(color: Color(0xFF404040), height: 1, thickness: 1),
            const SizedBox(height: BootstrapTheme.spacingMd),
            ...children,
          ],
        ),
      ),
    );
  }

  // hon el indicator elli byfarje el safety aw el dangerous 
  Widget _buildSafetyIndicator() {
    return AnimatedBuilder(
      animation: _safetyAnimationController,
      builder: (context, child) {
        return Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                _safetyColorAnimation.value!.withValues(alpha: 0.2),
                BootstrapTheme.darkBg,
              ],
              stops: const [0.0, 1.0],
            ),
            border: Border.all(
              color: _safetyColorAnimation.value!.withValues(alpha: 0.5),
              width: 3,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF252525),
                  border: Border.all(color: const Color(0xFF404040), width: 2),
                ),
              ),
              // Progress arc
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: _safetyProgressAnimation.value,
                  strokeWidth: 8,
                  backgroundColor: const Color(0xFF404040),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _safetyColorAnimation.value!,
                  ),
                ),
              ),
              // Center content
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getSafetyIcon(),
                    color: _safetyColorAnimation.value,
                    size: 40,
                  ),
                  const SizedBox(height: BootstrapTheme.spacingSm),
                  Text(
                    _getSafetyLevel(),
                    style: TextStyle(
                      color: _safetyColorAnimation.value,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TWR: ${twr.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFB0B0B0),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // hon mnkhtar el icon lmneseb aala hasab level el risk.
  IconData _getSafetyIcon() {
    if (failureProbability >= _dangerFailureThreshold) return Icons.cancel;
    if (failureProbability >= 0.005) return Icons.warning;
    if (failureProbability >= 0.002) return Icons.remove_circle_outline;
    if (failureProbability >= 0.001) return Icons.check_circle;
    return Icons.rocket_launch;
  }

  // hon mnkhtar el kelme elli btosef level el safe aw el danger.
  String _getSafetyLevel() {
    if (failureProbability >= _dangerFailureThreshold) return 'DANGER';
    if (failureProbability >= 0.005) return 'WARNING';
    if (failureProbability >= 0.002) return 'CAUTION';
    if (failureProbability >= 0.001) return 'LOW RISK';
    return 'VERY SAFE';
  }

  // hon mnaaml update ll animation tabaa el safety ta ybayen el result smoothly.
  void _updateSafetyAnimation() {
    // Normalize risk to a 0..1 progress where lower risk shows higher progress.
    double progress = (1.0 - (failureProbability / 0.05)).clamp(0.0, 1.0);

    // Determine indicator color from the modeled failure probability.
    Color targetColor;
    if (failureProbability >= _dangerFailureThreshold) {
      targetColor = BootstrapTheme.danger;
    } else if (failureProbability >= 0.005) {
      targetColor = BootstrapTheme.warning;
    } else if (failureProbability >= 0.002) {
      targetColor = const Color(0XFFFFC61F);
    } else if (failureProbability >= 0.001) {
      targetColor = BootstrapTheme.success;
    } else {
      targetColor = BootstrapTheme.info;
    }

    // Update animations
    _safetyProgressAnimation =
        Tween<double>(
          begin: _safetyProgressAnimation.value,
          end: progress,
        ).animate(
          CurvedAnimation(
            parent: _safetyAnimationController,
            curve: Curves.easeInOut,
          ),
        );

    _safetyColorAnimation =
        ColorTween(
          begin: _safetyColorAnimation.value,
          end: targetColor,
        ).animate(
          CurvedAnimation(
            parent: _safetyAnimationController,
            curve: Curves.easeInOut,
          ),
        );

    // Start animation
    _safetyAnimationController.reset();
    _safetyAnimationController.forward();
  }

  @override
  // home screen 
  Widget build(BuildContext context) {
    // Keep UI compact on phones and wider on tablets/desktop.
    final isMobile = MediaQuery.of(context).size.width < 768;
    final padding = isMobile
        ? BootstrapTheme.spacingMd
        : BootstrapTheme.spacingXl;
    final maxWidth = isMobile ? double.infinity : 500.0;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo Section
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: BootstrapTheme.spacingXl,
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(
                              BootstrapTheme.spacingMd,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              border: Border.all(
                                color: BootstrapTheme.accent.withValues(
                                  alpha: 0.3,
                                ),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(
                                BootstrapTheme.borderRadiusLg,
                              ),
                            ),
                            child: Image.asset(
                              'assets/logoappp.png',
                              height: 80,
                              width: 80,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: BootstrapTheme.spacingMd),
                          Text(
                            'AeroCalc',
                            style: GoogleFonts.k2d(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: BootstrapTheme.accent,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Drone Flight Simulator',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF808080),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Drone Build Card
                    _buildCard(
                      title: 'Drone Build',
                      subtitle: 'Configure your drone specifications',
                      children: [
                        _buildFormField(
                          label: 'Total Weight',
                          hint: 'grams',
                          controller: weightController,
                          onChanged: (value) {
                            setState(() {
                              weight = int.tryParse(value) ?? 0;
                            });
                          },
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: BootstrapTheme.spacing),
                        _buildDropdown(
                          label: 'Motor Layout',
                          value: selectedMotor,
                          items: const ['4 Motors', '6 Motors', '8 Motors'],
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedMotor = newValue!;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: BootstrapTheme.spacingLg),

                    // Power & Propulsion Card
                    _buildCard(
                      title: 'Power & Propulsion',
                      subtitle: 'Set motor and battery specifications',
                      children: [
                        _buildFormField(
                          label: 'Thrust per Motor',
                          hint: 'Newtons (N)',
                          controller: thrustController,
                          onChanged: (value) {
                            setState(() {
                              thrustMotor = value;
                            });
                          },
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: BootstrapTheme.spacing),
                        _buildFormField(
                          label: 'Battery Capacity',
                          hint: 'milliAmp hours (mAh)',
                          controller: batteryController,
                          onChanged: (value) {
                            setState(() {
                              batteryCapacity = value;
                            });
                          },
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: BootstrapTheme.spacing),
                        _buildDropdown(
                          label: 'Battery Voltage',
                          value: selectedVoltage,
                          items: const ['7.4v', '11.1v', '14.8v', '22.2v'],
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedVoltage = newValue!;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: BootstrapTheme.spacingXl),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () async {
                                await Vibration.vibrate(duration: 35);
                                _resetSimulation();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: BootstrapTheme.secondary,
                                side: const BorderSide(
                                  color: BootstrapTheme.secondary,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    BootstrapTheme.borderRadius,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'RESET',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: BootstrapTheme.spacing),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () async {
                                // Haptic feedback on button press
                                await Vibration.vibrate(duration: 50);

                                setState(() {
                                  // Read and parse all user inputs.
                                  int numMotors = int.parse(
                                    selectedMotor.split(' ')[0],
                                  );
                                  double thrust =
                                      double.tryParse(thrustMotor) ?? 0.0;
                                  double batteryMah =
                                      double.tryParse(batteryCapacity) ?? 0.0;
                                  double voltage = _getVoltageFromString(
                                    selectedVoltage,
                                  );

                                  if (weight <= 0 ||
                                      thrust <= 0.0 ||
                                      batteryMah <= 0.0) {
                                    // Validation message for missing/invalid input.
                                    twr = 0.0;
                                    failureProbability = 1.0;
                                    statusColor = BootstrapTheme.danger;
                                    statusMessage =
                                        'Error: Enter weight, thrust, and battery capacity values';
                                    flightTimeEstimate = 0.0;
                                    return;
                                  }

                                  double totalThrust = thrust * numMotors;
                                  double weightKg = weight / 1000.0;
                                  // Core physics ratio: available thrust vs weight force.
                                  twr = totalThrust / (weightKg * 9.81);
                                  failureProbability =
                                      _estimateFailureProbability(
                                        twr,
                                        numMotors,
                                      );
                                  flightTimeEstimate = _estimateFlightTime(
                                    numMotors,
                                    thrust,
                                    batteryMah,
                                    voltage,
                                    weight,
                                  );

                                  final riskPercent =
                                      failureProbability * 100.0;
                                    // Convert model output into user-friendly status labels.
                                  if (failureProbability >=
                                      _dangerFailureThreshold) {
                                    statusColor = BootstrapTheme.danger;
                                    statusMessage =
                                        'Danger: Failure risk ${riskPercent.toStringAsFixed(2)}% (>= 1.00%)';
                                    _startDangerVibration();
                                  } else if (failureProbability >= 0.005) {
                                    statusColor = BootstrapTheme.warning;
                                    statusMessage =
                                        'Warning: Failure risk ${riskPercent.toStringAsFixed(2)}%';
                                    _stopDangerVibration();
                                  } else if (failureProbability >= 0.002) {
                                    statusColor = const Color(0XFFFFC61F);
                                    statusMessage =
                                        'Caution: Failure risk ${riskPercent.toStringAsFixed(2)}%';
                                    _stopDangerVibration();
                                  } else {
                                    statusColor = BootstrapTheme.success;
                                    statusMessage =
                                        'Low Risk: Failure risk ${riskPercent.toStringAsFixed(2)}%';
                                    _stopDangerVibration();
                                  }
                                });
                                _updateSafetyAnimation();

                                // Play success visual only for non-danger cases.
                                if (failureProbability <
                                    _dangerFailureThreshold) {
                                  _showSafeResultVideo();
                                } else {
                                  _hideSafeResultVideo();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: BootstrapTheme.accent,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    BootstrapTheme.borderRadius,
                                  ),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                'SIMULATE FLIGHT',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Simulation Results
                    if (twr > 0) ...[
                      const SizedBox(height: BootstrapTheme.spacingXl),
                      // Animated Safety Indicator
                      Center(child: _buildSafetyIndicator()),
                      const SizedBox(height: BootstrapTheme.spacingLg),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(BootstrapTheme.spacingMd),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(
                            BootstrapTheme.borderRadiusLg,
                          ),
                          color: statusColor.withValues(alpha: 0.05),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Simulation Results',
                              style: const TextStyle(
                                color: Color(0xFFB0B0B0),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: BootstrapTheme.spacingMd),
                            Text(
                              'TWR: ${twr.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: BootstrapTheme.spacing),
                            Text(
                              statusMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: BootstrapTheme.spacingSm),
                            Text(
                              'Failure risk: ${(failureProbability * 100).toStringAsFixed(2)}%',
                              style: const TextStyle(
                                color: Color(0xFFB0B0B0),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_isSafeResultVideoReady &&
                                _safeResultVideoController != null) ...[
                              const SizedBox(height: BootstrapTheme.spacingMd),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  BootstrapTheme.borderRadius,
                                ),
                                child: AspectRatio(
                                  aspectRatio: _safeResultVideoController!
                                      .value
                                      .aspectRatio,
                                  child: VideoPlayer(
                                    _safeResultVideoController!,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: BootstrapTheme.spacingMd),

                      // Status and Flight Time Cards
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(
                                BootstrapTheme.spacingMd,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    failureProbability < _dangerFailureThreshold
                                    ? BootstrapTheme.success.withValues(
                                        alpha: 0.1,
                                      )
                                    : BootstrapTheme.danger.withValues(
                                        alpha: 0.1,
                                      ),
                                border: Border.all(
                                  color:
                                      failureProbability <
                                          _dangerFailureThreshold
                                      ? BootstrapTheme.success
                                      : BootstrapTheme.danger,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(
                                  BootstrapTheme.borderRadius,
                                ),
                              ),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      failureProbability <
                                              _dangerFailureThreshold
                                          ? Icons.check_circle_outline
                                          : Icons.cancel_outlined,
                                      color:
                                          failureProbability <
                                              _dangerFailureThreshold
                                          ? BootstrapTheme.success
                                          : BootstrapTheme.danger,
                                      size: 32,
                                    ),
                                    const SizedBox(
                                      height: BootstrapTheme.spacingSm,
                                    ),
                                    Text(
                                      failureProbability <
                                              _dangerFailureThreshold
                                          ? 'READY FOR\nTAKEOFF'
                                          : 'HIGH RISK',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color:
                                            failureProbability <
                                                _dangerFailureThreshold
                                            ? BootstrapTheme.success
                                            : BootstrapTheme.danger,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: BootstrapTheme.spacing),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(
                                BootstrapTheme.spacingMd,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A2A),
                                border: Border.all(
                                  color: BootstrapTheme.info,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(
                                  BootstrapTheme.borderRadius,
                                ),
                              ),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.flight_takeoff,
                                      color: BootstrapTheme.info,
                                      size: 32,
                                    ),
                                    const SizedBox(
                                      height: BootstrapTheme.spacingSm,
                                    ),
                                    Text(
                                      flightTimeEstimate.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: BootstrapTheme.info,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'minutes',
                                      style: const TextStyle(
                                        color: Color(0xFF808080),
                                        fontSize: 11,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: BootstrapTheme.spacingLg),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
