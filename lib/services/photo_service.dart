import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class PhotoService {
  static final PhotoService _instance = PhotoService._internal();
  factory PhotoService() => _instance;
  PhotoService._internal();

  final ImagePicker _picker = ImagePicker();

  Future<File?> takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 70,
    );
    
    if (photo != null) {
      return File(photo.path);
    }
    return null;
  }

  Future<File> compressImage(File image) async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    final img.Image? original = img.decodeImage(await image.readAsBytes());
    if (original == null) return image;
    
    img.Image resized = original;
    if (original.width > 1024 || original.height > 1024) {
      resized = img.copyResize(original, width: 1024);
    }
    
    final compressed = File(tempPath)
      ..writeAsBytesSync(img.encodeJpg(resized, quality: 70));
    
    return compressed;
  }

  Future<String> addTimestampToPhoto(File image) async {
    return image.path;
  }
}
