import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shimmer/shimmer.dart';

class LocationBottomSheet extends StatefulWidget {
  final Function(DateTime) onPunchIn;
  final Function(DateTime)? onPunchOut;
  final bool isCheckIn;

  const LocationBottomSheet({
    super.key,
    required this.onPunchIn,
    this.onPunchOut,
    required this.isCheckIn,
  });

  @override
  _LocationBottomSheetState createState() => _LocationBottomSheetState();
}

class _LocationBottomSheetState extends State<LocationBottomSheet> {
  double _dragPosition = 0.0;
  bool _isActionCompleted = false;
  String _currentAddress = "Fetching location...";
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _currentAddress = "Location services are disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _currentAddress = "Location permissions denied.");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _currentAddress = "Location permissions permanently denied.");
        return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => _currentPosition = position);
      await _getAddressFromLatLng(position);
    } catch (e) {
      setState(() => _currentAddress = "Failed to get location: $e");
    }
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _currentAddress = "${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}";
        });
      }
    } catch (e) {
      setState(() => _currentAddress = "Failed to get address: $e");
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double maxWidth) {
    if (_isActionCompleted || _currentPosition == null) return;
    setState(() {
      _dragPosition += details.delta.dx;
      _dragPosition = _dragPosition.clamp(0.0, maxWidth);
    });
  }

  void _onHorizontalDragEnd(double maxWidth) {
    if (_isActionCompleted || _currentPosition == null) return;

    if (_dragPosition >= maxWidth / 2) {
      DateTime actionTime = DateTime.now();
      if (widget.isCheckIn) {
        widget.onPunchIn(actionTime);
      } else if (widget.onPunchOut != null) {
        widget.onPunchOut!(actionTime);
      }
      Navigator.pop(context);
      setState(() => _isActionCompleted = true);
    } else {
      setState(() => _dragPosition = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    double maxWidth = MediaQuery.of(context).size.width - 32 - 65;

    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey,
                child: Icon(Icons.business, size: 20, color: Colors.white),
              ),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Space Infotech Pvt. Ltd.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            _currentAddress,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 20),
          _buildSlider(maxWidth),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSlider(double maxWidth) {
    final baseColor = widget.isCheckIn ? Colors.green : Colors.red;
    final shimmerBaseColor = widget.isCheckIn ? Colors.green[300]! : Colors.red[300]!;
    final shimmerHighlightColor = widget.isCheckIn ? Colors.green[100]! : Colors.red[100]!;

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        _currentPosition == null
            ? Shimmer.fromColors(
          baseColor: shimmerBaseColor,
          highlightColor: shimmerHighlightColor,
          child: Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(30)),
          ),
        )
            : Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(30)),
        ),
        Positioned(
          left: _dragPosition,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) => _onHorizontalDragUpdate(details, maxWidth),
            onHorizontalDragEnd: (details) => _onHorizontalDragEnd(maxWidth),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(Icons.arrow_forward_ios, color: Colors.black, size: 20),
            ),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Text(
              _isActionCompleted
                  ? (widget.isCheckIn ? 'Checked In!' : 'Checked Out!')
                  : (widget.isCheckIn ? 'Swipe to Check In' : 'Swipe to Check Out'),
              style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}