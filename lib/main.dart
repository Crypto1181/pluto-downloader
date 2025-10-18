import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(debug: true);
  runApp(const ColdDownloaderApp());
}

class ColdDownloaderApp extends StatelessWidget {
  const ColdDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pluto Downloader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      home: const ColdDownloaderHome(),
    );
  }
}

class ColdDownloaderHome extends StatefulWidget {
  const ColdDownloaderHome({super.key});

  @override
  State<ColdDownloaderHome> createState() => _ColdDownloaderHomeState();
}

class _ColdDownloaderHomeState extends State<ColdDownloaderHome>
    with TickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  late AnimationController _logoAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _logoAnimation;
  late Animation<double> _pulseAnimation;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  static const String _rapidApiKey = String.fromEnvironment('RAPIDAPI_KEY');

  @override
  void initState() {
    super.initState();
    _logoAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _logoAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoAnimationController, curve: Curves.easeOut),
    );

    _pulseAnimation = Tween<double>(begin: 1, end: 1.1).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _logoAnimationController.forward();
    _pulseAnimationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _pulseAnimationController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _simulateDownload() async {
    // Validate URL
    if (_urlController.text.trim().isEmpty) {
      _showErrorDialog('Please paste a valid URL');
      return;
    }

    // Ensure RapidAPI key is available
    final apiKey = _rapidApiKey.isNotEmpty
        ? _rapidApiKey
        : 'cfd42cb60fmsh596e3adef1f26a9p16f12bjsn720e2168c172'; // fallback for dev

    if (apiKey.isEmpty) {
      _showErrorDialog(
        'Missing API key. Run with --dart-define=RAPIDAPI_KEY=YOUR_KEY or set it in code.',
      );
      return;
    }

    setState(() {
      _isDownloading = true; // used to disable button
      _downloadProgress = 0.0;
    });

    // Show a quick blocking loader so users see progress immediately
    _showBlockingLoader('Fetching download links...');

    try {
      final url = _urlController.text.trim();
      final encodedUrl = Uri.encodeComponent(url);
      http.Response response;
      // Use GET for TikTok, Instagram, etc. (as in curl example)
      if (url.isNotEmpty) {
        final getApiUrl =
            'https://zm-api.p.rapidapi.com/v1/social/autolink?url=$encodedUrl';
        response = await http
            .get(
              Uri.parse(getApiUrl),
              headers: {
                'content-type': 'application/json',
                'x-rapidapi-host': 'zm-api.p.rapidapi.com',
                'x-rapidapi-key': apiKey,
              },
            )
            .timeout(const Duration(seconds: 30));
      } else {
        throw Exception('URL is empty');
      }

      if (mounted) {
        // Dismiss loader
        Navigator.of(context, rootNavigator: true).maybePop();
        setState(() {
          _downloadProgress = 1.0;
          _isDownloading = false;
        });

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          print('API Response: $decoded'); // Debug log

          final data = decoded is Map<String, dynamic>
              ? decoded
              : <String, dynamic>{};

          // zm-api returns 'medias' array for download links
          dynamic mediasList;
          if (data.containsKey('medias') && data['medias'] is List) {
            mediasList = data['medias'] as List;
          } else if (data.containsKey('videos') && data['videos'] is List) {
            mediasList = data['videos'] as List;
          } else if (data.containsKey('data') && data['data'] is Map) {
            final dataObj = data['data'] as Map<String, dynamic>;
            if (dataObj.containsKey('medias') && dataObj['medias'] is List) {
              mediasList = dataObj['medias'] as List;
            }
          }

          if (mediasList != null && mediasList.isNotEmpty) {
            final validMedias = mediasList.where((v) {
              return v is Map && v.containsKey('url');
            }).toList();
            if (validMedias.isNotEmpty) {
              final media = validMedias[0] as Map<String, dynamic>;
              final mediaUrl = media['url'];
              final quality =
                  media['quality'] ?? media['extension'] ?? 'default';
              if (mediaUrl != null && mediaUrl.toString().isNotEmpty) {
                _downloadVideo(mediaUrl.toString(), quality.toString());
              } else {
                _showErrorDialog('Media URL is empty or invalid.');
              }
            } else {
              _showErrorDialog('No valid media URLs found in the response.');
            }
          } else {
            _showErrorDialog(
              'No downloadable media found.\nResponse structure: ${data.keys.join(", ")}',
            );
          }
        } else {
          _showErrorDialog(
            'Failed to fetch media. Status: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
        setState(() {
          _isDownloading = false;
        });
        _showErrorDialog('Request failed: ${e.toString()}');
      }
    }
  }

  void _showBlockingLoader(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 300,
            minWidth: 200,
            maxHeight: 120,
            minHeight: 80,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                style: GoogleFonts.inter(color: Colors.white),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadVideo(String url, String quality) async {
    try {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      // Get download directory
      final directory = await getExternalStorageDirectory();

      // Create filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'pluto_video_${timestamp}_$quality.mp4';

      // Use flutter_downloader to download the file
      await FlutterDownloader.enqueue(
        url: url,
        savedDir: directory!.path,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: true,
        saveInPublicStorage: true,
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
        _showSuccessDialogWithMessage(
          'Download started!\n\nCheck your notification panel for progress.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
        _showErrorDialog('Download failed: ${e.toString()}');
      }
    }
  }

  void _showSuccessDialogWithMessage(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 50),
        content: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.inter(color: const Color(0xFF1E88E5)),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.error_outline, color: Colors.red, size: 50),
        content: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.inter(color: const Color(0xFF1E88E5)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF415A77)],
          ),
        ),
        child: SafeArea(
          child: AnimationLimiter(
            child: Column(
              children: [
                // Header Section
                AnimationConfiguration.staggeredList(
                  position: 0,
                  duration: const Duration(milliseconds: 1000),
                  child: SlideAnimation(
                    verticalOffset: -50,
                    child: FadeInAnimation(
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          children: [
                            // Logo Animation
                            AnimatedBuilder(
                              animation: _logoAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _logoAnimation.value,
                                  child: AnimatedBuilder(
                                    animation: _pulseAnimation,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: _pulseAnimation.value,
                                        child: Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF1E88E5),
                                                Color(0xFF42A5F5),
                                                Color(0xFF90CAF9),
                                              ],
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF1E88E5,
                                                ).withOpacity(0.3),
                                                blurRadius: 20,
                                                spreadRadius: 5,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.download_rounded,
                                            size: 60,
                                            color: Colors.white,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            // App Title with Animation
                            AnimatedTextKit(
                              animatedTexts: [
                                TyperAnimatedText(
                                  'Pluto Downloader',
                                  textStyle: GoogleFonts.inter(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  speed: const Duration(milliseconds: 100),
                                ),
                              ],
                              isRepeatingAnimation: false,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Download videos from any social media platform',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Main Content
                Expanded(
                  child: AnimationConfiguration.staggeredList(
                    position: 1,
                    duration: const Duration(milliseconds: 1000),
                    delay: const Duration(milliseconds: 300),
                    child: SlideAnimation(
                      verticalOffset: 50,
                      child: FadeInAnimation(
                        child: SingleChildScrollView(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                // Glassmorphic URL Input Card
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final width = constraints.maxWidth;
                                    return GlassmorphicContainer(
                                      width: width,
                                      height: 180,
                                      borderRadius: 25,
                                      blur: 20,
                                      alignment: Alignment.bottomCenter,
                                      border: 2,
                                      linearGradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withOpacity(0.1),
                                          Colors.white.withOpacity(0.05),
                                        ],
                                      ),
                                      borderGradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withOpacity(0.2),
                                          Colors.white.withOpacity(0.1),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Paste URL Here',
                                              style: GoogleFonts.inter(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            TextField(
                                              controller: _urlController,
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                              ),
                                              decoration: InputDecoration(
                                                hintText:
                                                    'https://instagram.com/p/...',
                                                hintStyle: GoogleFonts.inter(
                                                  color: Colors.white60,
                                                ),
                                                filled: true,
                                                fillColor: Colors.white
                                                    .withOpacity(0.1),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  borderSide: BorderSide.none,
                                                ),
                                                prefixIcon: const Icon(
                                                  Icons.link,
                                                  color: Color(0xFF1E88E5),
                                                ),
                                                suffixIcon: IconButton(
                                                  icon: const Icon(
                                                    Icons.paste,
                                                    color: Color(0xFF1E88E5),
                                                  ),
                                                  onPressed: () async {
                                                    final data =
                                                        await Clipboard.getData(
                                                          'text/plain',
                                                        );
                                                    if (data?.text != null) {
                                                      _urlController.text =
                                                          data!.text!;
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                const SizedBox(height: 30),

                                // Download Button
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: double.infinity,
                                  height: 60,
                                  child: ElevatedButton(
                                    onPressed: _isDownloading
                                        ? null
                                        : _simulateDownload,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E88E5),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      elevation: 8,
                                      shadowColor: const Color(
                                        0xFF1E88E5,
                                      ).withOpacity(0.4),
                                    ),
                                    child: _isDownloading
                                        ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Fetching links... ${(_downloadProgress * 100).toInt()}%',
                                                style: GoogleFonts.inter(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.download_rounded,
                                                size: 24,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Download Now',
                                                style: GoogleFonts.inter(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 40),

                                // Supported Platforms
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final width = constraints.maxWidth;
                                    return GlassmorphicContainer(
                                      width: width,
                                      height: 150,
                                      borderRadius: 20,
                                      blur: 20,
                                      alignment: Alignment.bottomCenter,
                                      border: 2,
                                      linearGradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withOpacity(0.05),
                                          Colors.white.withOpacity(0.02),
                                        ],
                                      ),
                                      borderGradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withOpacity(0.1),
                                          Colors.white.withOpacity(0.05),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Supported Platforms',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Wrap(
                                              alignment:
                                                  WrapAlignment.spaceAround,
                                              spacing: 10,
                                              runSpacing: 6,
                                              children: [
                                                _buildPlatformIcon(
                                                  Icons.camera_alt,
                                                  'Instagram',
                                                ),
                                                _buildPlatformIcon(
                                                  Icons.play_arrow,
                                                  'YouTube',
                                                ),
                                                _buildPlatformIcon(
                                                  Icons.music_note,
                                                  'TikTok',
                                                ),
                                                _buildPlatformIcon(
                                                  Icons.facebook,
                                                  'Facebook',
                                                ),
                                                _buildPlatformIcon(
                                                  Icons.more_horiz,
                                                  'More',
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),
                              ],
                            ), // Column
                          ), // Container
                        ), // SingleChildScrollView
                      ), // FadeInAnimation
                    ), // SlideAnimation
                  ), // AnimationConfiguration
                ), // Expanded
                // Bottom Section
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    '© 2024 Pluto Downloader - Fast & Secure',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformIcon(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E88E5).withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 8, color: Colors.white70),
        ),
      ],
    );
  }
}
