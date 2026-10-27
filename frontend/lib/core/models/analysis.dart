import 'dart:typed_data';

const cropLabels = <String>['Tomato', 'Maize', 'Potato', 'Bell Pepper'];
const tomatoClasses = <String>[
  'Tomato Healthy',
  'Tomato Early Blight',
  'Tomato Late Blight',
  'Tomato Bacterial Spot',
  'Tomato Leaf Mold',
];
const multiCropClasses = <String>[
  ...tomatoClasses,
  'Maize Healthy',
  'Maize Common Rust',
  'Maize Gray Leaf Spot',
  'Maize Northern Leaf Blight',
  'Potato Healthy',
  'Potato Early Blight',
  'Potato Late Blight',
  'Bell Pepper Healthy',
  'Bell Pepper Bacterial Spot',
];

String cropForClass(String name) => cropLabels.firstWhere(
  (crop) => name.startsWith('$crop '),
  orElse: () => throw const FormatException('Unsupported crop label.'),
);

class SelectedLeaf {
  const SelectedLeaf({
    required this.name,
    required this.bytes,
    required this.mimeType,
    required this.width,
    required this.height,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;
  final int width;
  final int height;

  String get sizeLabel =>
      '${(bytes.length / (1024 * 1024)).toStringAsFixed(2)} MB';
}

class BackendHealth {
  const BackendHealth({
    required this.modelLoaded,
    this.message,
    this.classLabels = tomatoClasses,
    this.testAccuracy,
    this.macroF1,
  });

  final bool modelLoaded;
  final String? message;
  final List<String> classLabels;
  final double? testAccuracy;
  final double? macroF1;

  factory BackendHealth.fromJson(Map<String, dynamic> json) {
    if (json['status'] != 'ok' || json['model_loaded'] is! bool) {
      throw const FormatException('Invalid health response.');
    }
    return BackendHealth(
      modelLoaded: json['model_loaded'] as bool,
      message: json['model_message'] as String?,
      classLabels: List<String>.from(
        json['class_labels'] as List? ?? tomatoClasses,
      ),
      testAccuracy: (json['test_accuracy'] as num?)?.toDouble(),
      macroF1: (json['macro_f1'] as num?)?.toDouble(),
    );
  }
}

class ClassScore {
  const ClassScore(this.name, this.confidence);

  final String name;
  final double confidence;

  String get percentage => '${(confidence * 100).toStringAsFixed(1)}%';

  factory ClassScore.fromJson(Map<String, dynamic> json) {
    final name = json['class'];
    final value = json['confidence'];
    if (name is! String || name.isEmpty || value is! num) {
      throw const FormatException('Invalid prediction score.');
    }
    final confidence = value.toDouble();
    if (!confidence.isFinite || confidence < 0 || confidence > 1) {
      throw const FormatException('Prediction score is outside [0, 1].');
    }
    return ClassScore(name, confidence);
  }
}

class DiseaseInformation {
  const DiseaseInformation({
    required this.description,
    required this.management,
    required this.prevention,
    required this.sources,
  });

  final String description;
  final List<String> management;
  final List<String> prevention;
  final List<String> sources;

  factory DiseaseInformation.fromJson(Map<String, dynamic> json) {
    return DiseaseInformation(
      description: json['description'] as String,
      management: List<String>.from(json['management'] as List),
      prevention: List<String>.from(json['prevention'] as List),
      sources: List<String>.from(json['sources'] as List? ?? []),
    );
  }
}

class LeafPrediction {
  const LeafPrediction({
    required this.className,
    required this.confidence,
    required this.topThree,
    required this.information,
    required this.confidenceNote,
  });

  final String className;
  final double confidence;
  final List<ClassScore> topThree;
  final DiseaseInformation information;
  final String confidenceNote;

  String get percentage => '${(confidence * 100).toStringAsFixed(1)}%';
  String get crop => cropForClass(className);
  String get shortName => className.substring(crop.length + 1);

  factory LeafPrediction.fromJson(Map<String, dynamic> json) {
    final winner = ClassScore.fromJson({
      'class': json['predicted_class'],
      'confidence': json['confidence'],
    });
    final topThree = (json['top_predictions'] as List)
        .map((value) => ClassScore.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
    if (topThree.length != 3 ||
        topThree.map((score) => score.name).toSet().length != 3 ||
        topThree.first.name != winner.name ||
        (topThree.first.confidence - winner.confidence).abs() > 0.000001 ||
        topThree[0].confidence < topThree[1].confidence ||
        topThree[1].confidence < topThree[2].confidence) {
      throw const FormatException('Inconsistent top-three predictions.');
    }
    return LeafPrediction(
      className: winner.name,
      confidence: winner.confidence,
      topThree: topThree,
      information: DiseaseInformation.fromJson(
        json['disease_information'] as Map<String, dynamic>,
      ),
      confidenceNote:
          json['confidence_note'] as String? ??
          'Confidence is a model score among five classes, not diagnostic certainty. '
              'Confirm significant symptoms with a local agricultural professional.',
    );
  }
}
