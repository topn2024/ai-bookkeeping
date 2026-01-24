/// SMS message model
class SmsMessage {
  final String id;
  final String address;  // Sender phone number or name
  final String body;     // SMS content
  final DateTime date;   // Received time

  SmsMessage({
    required this.id,
    required this.address,
    required this.body,
    required this.date,
  });

  factory SmsMessage.fromMap(Map<String, dynamic> map) {
    return SmsMessage(
      id: map['id']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(map['date']?.toString() ?? '0') ?? 0,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'address': address,
      'body': body,
      'date': date.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() {
    return 'SmsMessage(id: $id, address: $address, date: $date, body: ${body.substring(0, body.length > 50 ? 50 : body.length)}...)';
  }
}
