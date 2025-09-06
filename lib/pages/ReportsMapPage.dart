import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class ReportsMapPage extends StatefulWidget {
  @override
  _ReportsMapPageState createState() => _ReportsMapPageState();
}

class _ReportsMapPageState extends State<ReportsMapPage> {
  final MapController _mapController = MapController();
  Map<String, dynamic>? _selectedReport;
  String? _selectedReportId;

  // Stream to get reports from Firestore
  Stream<QuerySnapshot> _getReports() {
    return FirebaseFirestore.instance
        .collection("reportapp") // Make sure your collection name is correct
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  // Launch URL for image or link
  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }

  // Handle upvote/downvote
  void _vote(String reportId, bool isUpvote) {
    final field = isUpvote ? 'upvotes' : 'downvotes';
    FirebaseFirestore.instance.collection('reportapp').doc(reportId).update({
      field: FieldValue.increment(1),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reports Map"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          // Left panel - list of reports
          Expanded(
            flex: 1,
            child: StreamBuilder<QuerySnapshot>(
              stream: _getReports(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Error loading reports"));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final reports = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final data = reports[index].data() as Map<String, dynamic>;
                    final location = data["location"] as Map<String, dynamic>?;
                    final reportId = reports[index].id;

                    return ListTile(
                      leading: const Icon(Icons.report, color: Colors.red),
                      title: Text(data["title"] ?? "Untitled"),
                      subtitle: Text(data["description"] ?? ""),
                      onTap: () {
                        setState(() {
                          _selectedReport = data;
                          _selectedReportId = reportId;
                          if (location != null) {
                            final point = LatLng(
                              location["lat"] ?? 0.0,
                              location["lng"] ?? 0.0,
                            );
                            _mapController.move(point, 15);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          // Right panel - map
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: _getReports(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final reports = snapshot.data!.docs;

                    return FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(
                          23.6102,
                          85.2799,
                        ), // default center
                        initialZoom: 6,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                        ),
                        MarkerLayer(
                          markers: reports.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final location =
                                data["location"] as Map<String, dynamic>?;
                            final reportId = doc.id;

                            if (location == null) {
                              return const Marker(
                                point: LatLng(0, 0),
                                child: SizedBox(),
                              );
                            }

                            final point = LatLng(
                              location["lat"] ?? 0.0,
                              location["lng"] ?? 0.0,
                            );

                            return Marker(
                              point: point,
                              width: 50,
                              height: 50,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedReport = data;
                                    _selectedReportId = reportId;
                                  });
                                },
                                child: const Icon(
                                  Icons.location_on,
                                  size: 40,
                                  color: Colors.red,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                ),
                // Selected report details
                if (_selectedReport != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Card(
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedReport!["title"] ?? "No Title",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(_selectedReport!["description"] ?? ""),
                            const SizedBox(height: 12),
                            if ((_selectedReport!["imageUrl"] ?? "")
                                .toString()
                                .isNotEmpty)
                              InkWell(
                                onTap: () =>
                                    _launchURL(_selectedReport!["imageUrl"]),
                                child: Text(
                                  "View Image",
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.thumb_up),
                                  onPressed: () =>
                                      _vote(_selectedReportId ?? '', true),
                                ),
                                Text(
                                  "${_selectedReport!["upvotes"] ?? 0}",
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.thumb_down),
                                  onPressed: () =>
                                      _vote(_selectedReportId ?? '', false),
                                ),
                                Text(
                                  "${_selectedReport!["downvotes"] ?? 0}",
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
