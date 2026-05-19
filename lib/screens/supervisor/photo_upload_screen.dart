import 'package:flutter/material.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import '../../services/location_service.dart';
import '../../utils/translation_helper.dart';
import 'package:intl/intl.dart';

class PhotoUploadScreen extends StatefulWidget {
  const PhotoUploadScreen({super.key});

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  Position? _currentPosition;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _getCurrentLocation();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _controller = CameraController(
          _cameras.first,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await LocationService().getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      print('Error getting location for photo: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(TranslationHelper.translate('capture_photo')),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isCameraInitialized
          ? Stack(
              children: [
                CameraPreview(_controller!),
                
                // Overlay info
                Positioned(
                  bottom: 120,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        if (_currentPosition != null) ...[
                          Text(
                            'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            'Long: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ] else
                          Text(
                            TranslationHelper.translate('acquiring_gps'),
                            style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ),
                ),

                if (_isProcessing)
                  Container(
                    color: Colors.black45,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 16),
                          Text(
                            TranslationHelper.translate('processing_geotag'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton.large(
                      onPressed: _isProcessing ? null : _takePhoto,
                      backgroundColor: _currentPosition == null ? Colors.grey : Colors.red,
                      child: const Icon(
                        Icons.camera,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return;
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(TranslationHelper.translate('waiting_gps'))),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final XFile photo = await _controller!.takePicture();
      
      // Process image to add geotag text
      final File processedFile = await _processImageWithGeotag(File(photo.path));
      
      if (mounted) {
        Navigator.pop(context, processedFile);
      }
    } catch (e) {
      print('Error taking photo: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${TranslationHelper.translate('error_taking_photo')}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<File> _processImageWithGeotag(File originalFile) async {
    final bytes = await originalFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    
    if (image == null) return originalFile;

    // Draw background for text
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final lat = 'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}';
    final lng = 'Long: ${_currentPosition!.longitude.toStringAsFixed(6)}';
    
    // Add text to image
    // Using a simple approach with the image library
    img.drawString(image, timestamp, font: img.arial24, x: 20, y: image.height - 100, color: img.ColorRgb8(255, 255, 255));
    img.drawString(image, '$lat, $lng', font: img.arial24, x: 20, y: image.height - 60, color: img.ColorRgb8(255, 255, 255));

    final tempDir = await getTemporaryDirectory();
    final savedPath = '${tempDir.path}/geotagged_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File savedFile = File(savedPath);
    
    await savedFile.writeAsBytes(img.encodeJpg(image, quality: 85));
    return savedFile;
  }
}
