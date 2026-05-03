class MeralcoSchedule {
  final String date;
  final String location;
  final String timeRange;
  final String affectedAreas;
  final String reason;
  final String? detailUrl;

  MeralcoSchedule({
    required this.date,
    required this.location,
    required this.timeRange,
    required this.affectedAreas,
    required this.reason,
    this.detailUrl,
  });

  String get displayTitle => '$date - $location';

  Map<String, dynamic> toJson() => {
    'date': date,
    'location': location,
    'timeRange': timeRange,
    'affectedAreas': affectedAreas,
    'reason': reason,
    'detailUrl': detailUrl,
  };

  factory MeralcoSchedule.fromJson(Map<String, dynamic> json) => MeralcoSchedule(
    date: json['date'],
    location: json['location'],
    timeRange: json['timeRange'],
    affectedAreas: json['affectedAreas'],
    reason: json['reason'],
    detailUrl: json['detailUrl'],
  );
}

enum AlertLevel { red, yellow, green }

class AlertArea {
  final String province;
  final String city;
  final List<String> barangays;
  final AlertLevel alertLevel;

  AlertArea({
    required this.province,
    required this.city,
    required this.barangays,
    required this.alertLevel,
  });

  String get alertEmoji {
    switch (alertLevel) {
      case AlertLevel.red: return '🔴';
      case AlertLevel.yellow: return '🟡';
      case AlertLevel.green: return '🟢';
    }
  }

  String get alertText {
    switch (alertLevel) {
      case AlertLevel.red: return 'RED ALERT';
      case AlertLevel.yellow: return 'YELLOW ALERT';
      case AlertLevel.green: return 'NORMAL';
    }
  }
}
