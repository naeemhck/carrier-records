/// A calendar date in the business's Asia/Karachi date basis, without a time.
final class BusinessDate implements Comparable<BusinessDate> {
  final int year;
  final int month;
  final int day;

  BusinessDate(this.year, this.month, this.day) {
    if (year < 1 || year > 9999) throw FormatException('Invalid business year');
    final candidate = DateTime.utc(year, month, day);
    if (candidate.year != year ||
        candidate.month != month ||
        candidate.day != day) {
      throw FormatException('Invalid calendar date');
    }
  }

  factory BusinessDate.parse(String value) {
    if (!RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(value)) {
      throw FormatException('Expected YYYY-MM-DD');
    }
    return BusinessDate(
      int.parse(value.substring(0, 4)),
      int.parse(value.substring(5, 7)),
      int.parse(value.substring(8, 10)),
    );
  }

  String toJson() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  @override
  String toString() => toJson();
  @override
  int compareTo(BusinessDate other) => toJson().compareTo(other.toJson());
  @override
  bool operator ==(Object other) =>
      other is BusinessDate && compareTo(other) == 0;
  @override
  int get hashCode => Object.hash(year, month, day);
}
