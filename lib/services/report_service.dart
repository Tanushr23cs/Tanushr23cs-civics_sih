import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ReportService {
  static Future<void> submitReport({
    required String userId,
    required String title,
    required String description,
    required double lat,
    required double lng,
  }) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    File file = File(pickedFile.path);
    String fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";

    try {
      // Upload image
      UploadTask uploadTask = FirebaseStorage.instance
          .ref()
          .child("reports/$userId/$fileName")
          .putFile(file);

      TaskSnapshot snapshot = await uploadTask;

      // Get download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Save to Firestore
      await FirebaseFirestore.instance.collection("reports").add({
        "userId": userId,
        "title": title,
        "description": description,
        "lat": lat,
        "lng": lng,
        "status": "Submitted",
        "createdAt": FieldValue.serverTimestamp(),
        "imageUrl": downloadUrl,
        "videoUrl": null,
      });

      print("✅ Report submitted with image URL: $downloadUrl");
    } catch (e) {
      print("❌ Upload failed: $e");
    }
  }
}
