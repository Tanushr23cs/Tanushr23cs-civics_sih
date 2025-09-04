// lib/pages/dashboard_page.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:my_app/pages/welcome_page.dart';
import 'package:path/path.dart' as path;

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  XFile? _pickedImage;
  XFile? _pickedVideo;

  LatLng _currentPoint = const LatLng(23.6102, 85.2799);
  final MapController _mapController = MapController();

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _getLocation();
    FirebaseStorage.instance.setMaxUploadRetryTime(const Duration(minutes: 5));
  }

  Future<void> _getLocation() async {
    if (!kIsWeb) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPoint = LatLng(pos.latitude, pos.longitude);
      });
      _mapController.move(_currentPoint, 15);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      setState(() {
        _pickedImage = result;
        _pickedVideo = null;
      });
    }
  }

  Future<void> _captureImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.camera);
    if (result != null) {
      setState(() {
        _pickedImage = result;
        _pickedVideo = null;
      });
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final result = await picker.pickVideo(source: ImageSource.gallery);
    if (result != null) {
      setState(() {
        _pickedVideo = result;
        _pickedImage = null;
      });
    }
  }

  Future<void> _recordVideo() async {
    final picker = ImagePicker();
    final result = await picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 15),
    );
    if (result != null) {
      setState(() {
        _pickedVideo = result;
        _pickedImage = null;
      });
    }
  }

  // ✅ Compress image
  Future<File> _compressImage(File file) async {
    final targetPath = "${file.path}_compressed.jpg";

    // Light compression for fast upload from laptop
    final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80, // good quality, still smaller file
      minWidth: 1200, // moderate resizing
      minHeight: 1200,
      format: CompressFormat.jpeg,
    );

    return File(compressed?.path ?? file.path);
  }

  // ✅ Upload file to Firebase Storage
  Future<String?> _uploadFile(XFile file, String type) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final fileName =
          "${DateTime.now().millisecondsSinceEpoch}_$type.${file.name.split('.').last}";
      final ref = FirebaseStorage.instance.ref().child(
        'reports/$uid/$fileName',
      );

      UploadTask uploadTask;

      if (kIsWeb) {
        uploadTask = ref.putData(await file.readAsBytes());
      } else {
        File rawFile = File(file.path);
        if (type == "image") {
          rawFile = await _compressImage(rawFile);
        }
        uploadTask = ref.putFile(rawFile);
      }

      final taskSnapshot = await uploadTask.whenComplete(() {});
      if (taskSnapshot.state == TaskState.success) {
        return await ref.getDownloadURL();
      }
      return null;
    } catch (e) {
      debugPrint("Upload error: $e");
      return null;
    }
  }

  // ✅ Submit report with parallel uploads
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    final futures = <Future<String?>>[];

    if (_pickedImage != null) futures.add(_uploadFile(_pickedImage!, 'image'));
    if (_pickedVideo != null) futures.add(_uploadFile(_pickedVideo!, 'video'));

    final results = await Future.wait(futures);

    String? imageUrl;
    String? videoUrl;

    if (_pickedImage != null) imageUrl = results.isNotEmpty ? results[0] : null;
    if (_pickedVideo != null)
      videoUrl = results.length > 1 ? results[1] : results[0];

    await FirebaseFirestore.instance.collection('reports').add({
      'title': _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'lat': _currentPoint.latitude,
      'lng': _currentPoint.longitude,
      'createdAt': FieldValue.serverTimestamp(),
      'status': "Submitted",
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'userId': FirebaseAuth.instance.currentUser?.uid,
    });

    setState(() {
      _titleCtrl.clear();
      _descCtrl.clear();
      _pickedImage = null;
      _pickedVideo = null;
      _isUploading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Report submitted successfully!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade700, Colors.indigo.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopNav(user),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: ListView(
                    children: [
                      _buildReportFormCard(),
                      const SizedBox(height: 16),
                      _buildReportsListCard(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Government of Jharkhand • Department of Higher & Technical Education',
                  style: GoogleFonts.poppins(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopNav(User? user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.location_city, color: Colors.white, size: 30),
          const SizedBox(width: 8),
          Text(
            'Civics Reporter',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const WelcomePage()),
              );
            },
            child: const Text('Home', style: TextStyle(color: Colors.white)),
          ),
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildReportFormCard() {
    return Card(
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                "Create Report",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade900,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: "Title",
                  prefixIcon: const Icon(Icons.title, color: Colors.indigo),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) &&
                        _pickedImage == null &&
                        _pickedVideo == null
                    ? "Provide description or attach media"
                    : null,
                decoration: InputDecoration(
                  labelText: "Short description",
                  prefixIcon: const Icon(Icons.edit_note, color: Colors.indigo),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo),
                      label: const Text("Pick Photo"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _captureImage,
                      icon: const Icon(Icons.photo_camera),
                      label: const Text("Camera"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickVideo,
                      icon: const Icon(Icons.video_library),
                      label: const Text("Pick Video"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _recordVideo,
                      icon: const Icon(Icons.videocam),
                      label: const Text("Record"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_pickedImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: kIsWeb
                      ? FutureBuilder<dynamic>(
                          future: _pickedImage!.readAsBytes(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Image.memory(
                                snapshot.data,
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              );
                            }
                            return const SizedBox(
                              height: 140,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          },
                        )
                      : Image.file(
                          File(_pickedImage!.path),
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                ),
              if (_pickedVideo != null)
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.smart_display),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_pickedVideo!.name)),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _getLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text("Use My Location"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Lat: ${_currentPoint.latitude.toStringAsFixed(5)}, Lng: ${_currentPoint.longitude.toStringAsFixed(5)}",
                      style: GoogleFonts.poppins(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentPoint,
                      initialZoom: 15,
                      onTap: (tap, point) =>
                          setState(() => _currentPoint = point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentPoint,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_pin,
                              size: 40,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _submit,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isUploading ? "Uploading..." : "Submit Report"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportsListCard() {
    return Card(
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  "My Reports",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.indigo.shade900,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .where(
                    'userId',
                    isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                  )
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      "No reports yet. Create your first report above.",
                      style: GoogleFonts.poppins(fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: data['imageUrl'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                data['imageUrl'],
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            )
                          : data['videoUrl'] != null
                          ? const Icon(
                              Icons.smart_display,
                              size: 36,
                              color: Colors.indigo,
                            )
                          : const Icon(
                              Icons.description,
                              size: 36,
                              color: Colors.indigo,
                            ),
                      title: Text(data['title'] ?? "Untitled report"),
                      subtitle: Text(
                        "${data['status']} • ${(data['createdAt'] as Timestamp?)?.toDate().toLocal().toString().substring(0, 16) ?? ''}",
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
