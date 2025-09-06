import 'dart:typed_data';
import 'dart:io' as io;
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:latlong2/latlong.dart' as flmap;
import 'package:flutter_map/flutter_map.dart' as flmapWidgets;
import 'package:url_launcher/url_launcher.dart';
import 'package:my_app/pages/welcome_page.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadFile(XFile file, String type) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final fileName =
          "${DateTime.now().millisecondsSinceEpoch}_$type.${file.name.split('.').last}";
      final ref = _storage.ref().child('reports/$uid/$fileName');

      UploadTask uploadTask;

      if (kIsWeb) {
        Uint8List bytes = await file.readAsBytes();
        if (type == 'image') {
          bytes = await compressImageWeb(bytes);
        }
        uploadTask = ref.putData(bytes);
      } else {
        io.File rawFile = io.File(file.path);
        if (type == 'image') {
          final compressedXFile = await _compressImage(rawFile);
          if (compressedXFile != null) {
            rawFile = io.File(compressedXFile.path);
          }
        }
        uploadTask = ref.putFile(rawFile);
      }

      await uploadTask;
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Upload error: $e");
      return null;
    }
  }

  Future<XFile?> _compressImage(io.File file) async {
    final targetPath = "${file.path}_compressed.jpg";
    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: 80,
      minWidth: 1200,
      minHeight: 1200,
      format: CompressFormat.jpeg,
    );
    return compressedFile;
  }

  Future<Uint8List> compressImageWeb(Uint8List bytes) async {
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      quality: 80,
      minWidth: 1200,
      minHeight: 1200,
      format: CompressFormat.jpeg,
    );
    return result;
  }

  Future<void> addReport({
    required String title,
    required String description,
    String? imageUrl,
    String? videoUrl,
    Map<String, double>? location,
  }) async {
    try {
      await _db.collection('reportapp').add({
        'title': title,
        'description': description,
        'imageUrl': imageUrl ?? '',
        'videoUrl': videoUrl ?? '',
        'location': location,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'Submitted',
        'userId': FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
        'upvotes': 0,
        'downvotes': 0,
      });
      debugPrint("Report added successfully ✅");
    } catch (e) {
      debugPrint("Firestore error: $e ❌");
    }
  }

  Future<void> upvoteReport(String docId) async {
    final ref = _db.collection('reportapp').doc(docId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final current = snapshot.get('upvotes') ?? 0;
      transaction.update(ref, {'upvotes': current + 1});
    });
  }

  Future<void> downvoteReport(String docId) async {
    final ref = _db.collection('reportapp').doc(docId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final current = snapshot.get('downvotes') ?? 0;
      transaction.update(ref, {'downvotes': current + 1});
    });
  }
}

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
  flmap.LatLng _currentPoint = const flmap.LatLng(23.6102, 85.2799);
  double _currentZoom = 6.0;
  final flmapWidgets.MapController _mapController =
      flmapWidgets.MapController();
  bool _isUploading = false;

  final FirestoreService _service = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _getLocation();
    FirebaseStorage.instance.setMaxUploadRetryTime(const Duration(minutes: 5));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
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
          permission == LocationPermission.denied)
        return;

      final pos = await Geolocator.getCurrentPosition();
      setState(() => _currentPoint = flmap.LatLng(pos.latitude, pos.longitude));
      _mapController.move(_currentPoint, _currentZoom);
    }
  }

  Future<void> _pickImage() async {
    final result = await _picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      setState(() {
        _pickedImage = result;
        _pickedVideo = null;
      });
    }
  }

  Future<void> _captureImage() async {
    final result = await _picker.pickImage(source: ImageSource.camera);
    if (result != null) {
      setState(() {
        _pickedImage = result;
        _pickedVideo = null;
      });
    }
  }

  Future<void> _pickVideo() async {
    final result = await _picker.pickVideo(source: ImageSource.gallery);
    if (result != null) {
      setState(() {
        _pickedVideo = result;
        _pickedImage = null;
      });
    }
  }

  Future<void> _recordVideo() async {
    final result = await _picker.pickVideo(
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickedImage == null && _pickedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select an image or video."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    String? imageUrl;
    String? videoUrl;

    if (_pickedImage != null) {
      imageUrl = await _service.uploadFile(_pickedImage!, 'image');
    }
    if (_pickedVideo != null) {
      videoUrl = await _service.uploadFile(_pickedVideo!, 'video');
    }

    if ((_pickedImage != null && imageUrl == null) ||
        (_pickedVideo != null && videoUrl == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("File upload failed.")));
      setState(() => _isUploading = false);
      return;
    }

    await _service.addReport(
      title: _titleCtrl.text.trim().isEmpty
          ? "Untitled Report"
          : _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      location: {'lat': _currentPoint.latitude, 'lng': _currentPoint.longitude},
    );

    _titleCtrl.clear();
    _descCtrl.clear();
    setState(() {
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
              _buildTopNav(context, user),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: ListView(
                    children: [
                      _buildReportFormCard(),
                      const SizedBox(height: 12),
                      _buildMap(),
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

  Widget _buildTopNav(BuildContext context, User? user) {
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
              if (mounted) {
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
                decoration: const InputDecoration(
                  labelText: "Title",
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? "Enter a title" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (val) => val == null || val.trim().isEmpty
                    ? "Enter a description"
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _pickImage,
                      icon: const Icon(Icons.photo),
                      label: const Text("Pick Image"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _captureImage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Capture Image"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _pickVideo,
                      icon: const Icon(Icons.video_library),
                      label: const Text("Pick Video"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _recordVideo,
                      icon: const Icon(Icons.videocam),
                      label: const Text("Record Video"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_pickedImage != null)
                ListTile(
                  leading: const Icon(Icons.image, color: Colors.indigo),
                  title: Text(p.basename(_pickedImage!.path)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => setState(() => _pickedImage = null),
                  ),
                ),
              if (_pickedVideo != null)
                ListTile(
                  leading: const Icon(Icons.videocam, color: Colors.indigo),
                  title: Text(p.basename(_pickedVideo!.path)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => setState(() => _pickedVideo = null),
                  ),
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isUploading ? null : _submit,
                child: _isUploading
                    ? const CircularProgressIndicator()
                    : const Text("Submit Report"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    return SizedBox(
      height: 300,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reportapp')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data!.docs;

          return flmapWidgets.FlutterMap(
            mapController: _mapController,
            options: flmapWidgets.MapOptions(
              initialCenter: _currentPoint,
              initialZoom: _currentZoom,
              onTap: (tapPosition, latLng) {
                setState(() => _currentPoint = latLng);
                _mapController.move(_currentPoint, _currentZoom);
              },
              onPositionChanged: (pos, _) {
                _currentZoom = pos.zoom;
              },
            ),
            children: [
              flmapWidgets.TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              flmapWidgets.MarkerLayer(
                markers: reports
                    .map<flmapWidgets.Marker>((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final loc = data['location'] as Map<String, dynamic>?;

                      if (loc == null) {
                        return flmapWidgets.Marker(
                          point: flmap.LatLng(0, 0),
                          width: 0,
                          height: 0,
                          child: const SizedBox(),
                        );
                      }

                      final point = flmap.LatLng(
                        loc['lat']?.toDouble() ?? 0.0,
                        loc['lng']?.toDouble() ?? 0.0,
                      );

                      return flmapWidgets.Marker(
                        point: point,
                        width: 50,
                        height: 50,
                        child: GestureDetector(
                          onTap: () => _showReportDialog(doc.id, data),
                          child: const Icon(
                            Icons.location_on,
                            size: 40,
                            color: Colors.red,
                          ),
                        ),
                      );
                    })
                    .where((marker) => marker.width != 0)
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showReportDialog(String docId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(data['title'] ?? "No Title"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(data['description'] ?? ""),
            const SizedBox(height: 8),
            if ((data['imageUrl'] ?? "").isNotEmpty)
              InkWell(
                onTap: () async {
                  await launchUrl(Uri.parse(data['imageUrl']));
                },
                child: const Text(
                  "View Image",
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.thumb_up, color: Colors.green),
                      onPressed: () async {
                        await _service.upvoteReport(docId);
                        Navigator.pop(context);
                      },
                    ),
                    Text("${data['upvotes'] ?? 0}"),
                  ],
                ),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.thumb_down, color: Colors.red),
                      onPressed: () async {
                        await _service.downvoteReport(docId);
                        Navigator.pop(context);
                      },
                    ),
                    Text("${data['downvotes'] ?? 0}"),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}
