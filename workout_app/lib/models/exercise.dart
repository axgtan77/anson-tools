class Exercise {
  final int? id;
  final String name;
  final int displayOrder;
  final int restSeconds;

  Exercise({
    this.id,
    required this.name,
    this.displayOrder = 0,
    this.restSeconds = 90,
  });

  Exercise copyWith({String? name, int? displayOrder, int? restSeconds}) =>
      Exercise(
        id: id,
        name: name ?? this.name,
        displayOrder: displayOrder ?? this.displayOrder,
        restSeconds: restSeconds ?? this.restSeconds,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'display_order': displayOrder,
        'rest_seconds': restSeconds,
      };

  factory Exercise.fromMap(Map<String, dynamic> m) => Exercise(
        id: m['id'] as int?,
        name: m['name'] as String,
        displayOrder: (m['display_order'] as int?) ?? 0,
        restSeconds: (m['rest_seconds'] as int?) ?? 90,
      );
}
