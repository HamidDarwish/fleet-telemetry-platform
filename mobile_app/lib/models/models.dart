double? _d(dynamic v) => v == null ? null : (v as num).toDouble();

class Session {
  final String token;
  final int userId;
  final String name;
  final String role;

  const Session({required this.token, required this.userId, required this.name, required this.role});

  bool get isAdmin => role == 'ADMIN';
  bool get isManager => role == 'MANAGER';
  bool get isTechnician => role == 'TECHNICIAN';
  bool get isDriver => role == 'DRIVER';

  Map<String, dynamic> toJson() => {'token': token, 'userId': userId, 'name': name, 'role': role};

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        token: j['token'] as String,
        userId: (j['userId'] as num).toInt(),
        name: (j['name'] ?? '') as String,
        role: (j['role'] ?? '') as String,
      );
}

class Vehicle {
  final int id;
  final String plate;
  final String model;
  final String? driverName;
  String status;
  double? lat;
  double? lng;
  double? speed;
  double? fuel;
  double? temp;
  double? odometer;
  DateTime? lastUpdate;

  Vehicle({
    required this.id,
    required this.plate,
    required this.model,
    this.driverName,
    this.status = 'NORMAL',
    this.lat,
    this.lng,
    this.speed,
    this.fuel,
    this.temp,
    this.odometer,
    this.lastUpdate,
  });

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: (j['id'] as num).toInt(),
        plate: (j['plate'] ?? '') as String,
        model: (j['model'] ?? '') as String,
        driverName: j['driver']?['name'] as String?,
        status: (j['status'] ?? 'NORMAL') as String,
        lat: _d(j['currentLat']),
        lng: _d(j['currentLng']),
        speed: _d(j['speed']),
        fuel: _d(j['fuelLevel']),
        temp: _d(j['engineTemp']),
        odometer: _d(j['odometer']),
        lastUpdate: DateTime.tryParse((j['lastUpdate'] ?? '') as String)?.toLocal(),
      );

  /// Applies a message received through WebSocket (/topic/telemetry).
  void applyLive(Map<String, dynamic> j) {
    lat = _d(j['latitude']);
    lng = _d(j['longitude']);
    speed = _d(j['speed']);
    fuel = _d(j['fuelLevel']);
    temp = _d(j['engineTemp']);
    odometer = _d(j['odometer']);
    status = (j['status'] ?? status) as String;
    lastUpdate = DateTime.now();
  }

  bool get hasPosition => lat != null && lng != null;
}

class AlertItem {
  final int id;
  final int vehicleId;
  final String plate;
  final String type;
  final String severity;
  final String message;
  final DateTime? createdAt;
  bool acknowledged;

  AlertItem({
    required this.id,
    required this.vehicleId,
    required this.plate,
    required this.type,
    required this.severity,
    required this.message,
    this.createdAt,
    this.acknowledged = false,
  });

  factory AlertItem.fromJson(Map<String, dynamic> j) => AlertItem(
        id: (j['id'] as num).toInt(),
        vehicleId: (j['vehicleId'] as num).toInt(),
        plate: (j['vehiclePlate'] ?? '') as String,
        type: (j['type'] ?? '') as String,
        severity: (j['severity'] ?? 'INFO') as String,
        message: (j['message'] ?? '') as String,
        createdAt: DateTime.tryParse((j['createdAt'] ?? '') as String)?.toLocal(),
        acknowledged: (j['acknowledged'] ?? false) as bool,
      );
}

class WorkOrder {
  final int id;
  final int vehicleId;
  final String plate;
  final String title;
  final String description;
  final String priority;
  final String status;
  final String source;
  final int? assignedToId;
  final String? assignedToName;
  final String notes;
  final String parts;
  final double? cost;
  final DateTime? createdAt;

  WorkOrder({
    required this.id,
    required this.vehicleId,
    required this.plate,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    required this.source,
    this.assignedToId,
    this.assignedToName,
    this.notes = '',
    this.parts = '',
    this.cost,
    this.createdAt,
  });

  factory WorkOrder.fromJson(Map<String, dynamic> j) => WorkOrder(
        id: (j['id'] as num).toInt(),
        vehicleId: (j['vehicleId'] as num).toInt(),
        plate: (j['vehiclePlate'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        priority: (j['priority'] ?? 'MEDIUM') as String,
        status: (j['status'] ?? 'OPEN') as String,
        source: (j['source'] ?? 'MANUAL') as String,
        assignedToId: (j['assignedTo']?['id'] as num?)?.toInt(),
        assignedToName: j['assignedTo']?['name'] as String?,
        notes: (j['notes'] ?? '') as String,
        parts: (j['parts'] ?? '') as String,
        cost: _d(j['cost']),
        createdAt: DateTime.tryParse((j['createdAt'] ?? '') as String)?.toLocal(),
      );
}

class RuleView {
  final int id;
  final int vehicleId;
  final String name;
  final String type; // DISTANCE or TIME
  final int intervalValue;
  final String status; // UPCOMING, DUE_SOON, DUE
  final double percentUsed;
  final double remaining;

  RuleView({
    required this.id,
    required this.vehicleId,
    required this.name,
    required this.type,
    required this.intervalValue,
    required this.status,
    required this.percentUsed,
    required this.remaining,
  });

  factory RuleView.fromJson(Map<String, dynamic> j) => RuleView(
        id: (j['id'] as num).toInt(),
        vehicleId: (j['vehicleId'] as num).toInt(),
        name: (j['name'] ?? '') as String,
        type: (j['type'] ?? '') as String,
        intervalValue: (j['intervalValue'] as num).toInt(),
        status: (j['status'] ?? 'UPCOMING') as String,
        percentUsed: _d(j['percentUsed']) ?? 0,
        remaining: _d(j['remaining']) ?? 0,
      );

  String get unit => type == 'DISTANCE' ? 'km' : 'days';
}

class Dashboard {
  final int totalVehicles;
  final int activeVehicles;
  final int criticalVehicles;
  final int openAlerts;
  final int openWorkOrders;
  final int maintenanceDue;

  Dashboard({
    required this.totalVehicles,
    required this.activeVehicles,
    required this.criticalVehicles,
    required this.openAlerts,
    required this.openWorkOrders,
    required this.maintenanceDue,
  });

  factory Dashboard.fromJson(Map<String, dynamic> j) => Dashboard(
        totalVehicles: (j['totalVehicles'] as num).toInt(),
        activeVehicles: (j['activeVehicles'] as num).toInt(),
        criticalVehicles: (j['criticalVehicles'] as num).toInt(),
        openAlerts: (j['openAlerts'] as num).toInt(),
        openWorkOrders: (j['openWorkOrders'] as num).toInt(),
        maintenanceDue: (j['maintenanceDue'] as num).toInt(),
      );
}

class TechnicianInfo {
  final int id;
  final String name;
  TechnicianInfo(this.id, this.name);

  factory TechnicianInfo.fromJson(Map<String, dynamic> j) =>
      TechnicianInfo((j['id'] as num).toInt(), (j['name'] ?? '') as String);
}
