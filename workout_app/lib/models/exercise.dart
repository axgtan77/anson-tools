class Exercise {
  final int? id;
  final String name;
  final int displayOrder;

  Exercise({this.id, required this.name, this.displayOrder = 0});

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'display_order': displayOrder,
      };

  factory Exercise.fromMap(Map<String, dynamic> m) => Exercise(
        id: m['id'] as int?,
        name: m['name'] as String,
        displayOrder: (m['display_order'] as int?) ?? 0,
      );
}
