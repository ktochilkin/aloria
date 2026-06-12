/// Обращение в поддержку: тема, статус и ответ, когда он появится.
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.status,
    this.createdAt,
    this.answer,
    this.answeredAt,
  });

  final String id;
  final String subject;

  /// `open` — ждёт разбора, `answered` — есть ответ.
  final String status;
  final DateTime? createdAt;
  final String? answer;
  final DateTime? answeredAt;

  bool get isAnswered => status == 'answered';

  static SupportTicket? fromMap(Map<String, dynamic> map) {
    final id = map['id']?.toString();
    final subject = map['subject']?.toString();
    if (id == null || subject == null) return null;
    return SupportTicket(
      id: id,
      subject: subject,
      status: map['status']?.toString() ?? 'open',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      answer: map['answer']?.toString(),
      answeredAt: DateTime.tryParse(map['answeredAt']?.toString() ?? ''),
    );
  }
}
