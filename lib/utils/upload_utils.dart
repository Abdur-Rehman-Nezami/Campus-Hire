import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class UploadUtils {
  static final _picker = ImagePicker();

  // Pick and compress an image from gallery
  static Future<File?> pickAndCompressImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return null;

      final originalPath = pickedFile.path;
      final extensionIndex = originalPath.lastIndexOf('.');
      final targetPath = '${originalPath.substring(0, extensionIndex == -1 ? originalPath.length : extensionIndex)}_compressed.jpg';

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        originalPath,
        targetPath,
        quality: 70, // Excellent balance of quality and weight
        format: CompressFormat.jpeg,
      );

      if (compressedFile == null) return File(originalPath);
      return File(compressedFile.path);
    } catch (_) {
      return null;
    }
  }

  // Pick a PDF document
  static Future<File?> pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: false,
        withReadStream: false,
      );
      if (result == null || result.files.single.path == null) return null;
      return File(result.files.single.path!);
    } catch (_) {
      return null;
    }
  }

  // Upload any File to Firebase Storage and get its download URL
  static Future<String> uploadFile(File file, String storagePath) async {
    final ref = FirebaseStorage.instance.ref().child(storagePath);
    final bytes = await file.readAsBytes();
    
    // Using putData is much more robust on Android emulators where file paths might be content URIs
    final uploadTask = ref.putData(bytes);
    final snapshot = await uploadTask;
    
    return await snapshot.ref.getDownloadURL();
  }
}
