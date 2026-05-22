import '../entities/attendance_record.dart';

abstract class AttendanceRepository {
  Future<List<AttendanceRecord>> fetchHistory();
  Future<AttendanceRecord> checkIn(Map<String, dynamic> payload);
  Future<AttendanceRecord> checkOut(Map<String, dynamic> payload);
}
