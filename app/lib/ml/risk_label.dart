/// The three categories SMISHield assigns to a message.
enum RiskLabel {
  safe('Safe'),
  suspicious('Suspicious'),
  highRisk('High Risk');

  const RiskLabel(this.modelName);

  /// The label as written in the dataset and the exported model file.
  final String modelName;

  static RiskLabel fromModelName(String name) => values.firstWhere(
    (label) => label.modelName == name,
    orElse: () => throw FormatException('Unknown label "$name"'),
  );
}
