/// Тест, загруженный с сервера.
///
/// В отличие от [QuizQuestion] (markdown-источник), здесь у клиента нет
/// признака правильности ответа — он приходит только из ответа сервера на
/// попытку прохождения. Это намеренно: правильные ответы не должны утекать
/// на клиент.
class ServerQuiz {
  const ServerQuiz({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.rewardXp,
    required this.rewardBuyingPower,
    required this.questions,
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final int rewardXp;
  final double rewardBuyingPower;
  final List<ServerQuizQuestion> questions;

  factory ServerQuiz.fromJson(Map<String, dynamic> json) {
    final questions = (json['questions'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ServerQuizQuestion.fromJson)
        .toList(growable: false);
    return ServerQuiz(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      rewardXp: (json['rewardXp'] as num?)?.toInt() ?? 0,
      rewardBuyingPower:
          (json['rewardBuyingPower'] as num?)?.toDouble() ?? 0,
      questions: questions,
    );
  }
}

class ServerQuizQuestion {
  const ServerQuizQuestion({
    required this.id,
    required this.text,
    required this.allowsMultiple,
    required this.options,
  });

  final String id;
  final String text;
  final bool allowsMultiple;
  final List<ServerQuizOption> options;

  factory ServerQuizQuestion.fromJson(Map<String, dynamic> json) {
    final opts = (json['options'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ServerQuizOption.fromJson)
        .toList(growable: false);
    return ServerQuizQuestion(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      allowsMultiple: json['allowsMultiple'] as bool? ?? false,
      options: opts,
    );
  }
}

class ServerQuizOption {
  const ServerQuizOption({required this.id, required this.text});
  final String id;
  final String text;

  factory ServerQuizOption.fromJson(Map<String, dynamic> json) {
    return ServerQuizOption(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
    );
  }
}

class QuizAttemptResult {
  const QuizAttemptResult({
    required this.isPassed,
    required this.correctCount,
    required this.totalQuestions,
    required this.awardedXp,
    required this.awardedBuyingPower,
    required this.grantStatus,
    required this.questions,
  });

  final bool isPassed;
  final int correctCount;
  final int totalQuestions;
  final int awardedXp;
  final double awardedBuyingPower;
  final String? grantStatus;
  final List<QuestionResult> questions;

  factory QuizAttemptResult.fromJson(Map<String, dynamic> json) {
    final qs = (json['questions'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(QuestionResult.fromJson)
        .toList(growable: false);
    return QuizAttemptResult(
      isPassed: json['isPassed'] as bool? ?? false,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      awardedXp: (json['awardedXp'] as num?)?.toInt() ?? 0,
      awardedBuyingPower:
          (json['awardedBuyingPower'] as num?)?.toDouble() ?? 0,
      grantStatus: json['grantStatus'] as String?,
      questions: qs,
    );
  }
}

class QuestionResult {
  const QuestionResult({
    required this.questionId,
    required this.isCorrect,
    required this.correctOptionIds,
    required this.explanation,
  });

  final String questionId;
  final bool isCorrect;
  final List<String> correctOptionIds;
  final String? explanation;

  factory QuestionResult.fromJson(Map<String, dynamic> json) {
    final ids = (json['correctOptionIds'] as List? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    return QuestionResult(
      questionId: json['questionId'] as String,
      isCorrect: json['isCorrect'] as bool? ?? false,
      correctOptionIds: ids,
      explanation: json['explanation'] as String?,
    );
  }
}
