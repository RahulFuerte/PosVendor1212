class WhatsappTemplateModel {
  final String id;
  final String name;
  final String message;
  final bool isDefault;

  WhatsappTemplateModel({
    required this.id,
    required this.name,
    required this.message,
    this.isDefault = false,
  });

  factory WhatsappTemplateModel.fromJson(Map<String, dynamic> json) {
    return WhatsappTemplateModel(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'message': message,
    'isDefault': isDefault,
  };
}
