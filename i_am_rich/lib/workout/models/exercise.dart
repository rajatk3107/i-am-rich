class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final bool isCustom;

  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    this.isCustom = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'muscle_group': muscleGroup,
        'equipment': equipment,
        'is_custom': isCustom ? 1 : 0,
      };

  factory Exercise.fromMap(Map<String, dynamic> map) => Exercise(
        id: map['id'] as String,
        name: map['name'] as String,
        muscleGroup: map['muscle_group'] as String,
        equipment: map['equipment'] as String,
        isCustom: (map['is_custom'] as int) == 1,
      );

  Exercise copyWith({
    String? id,
    String? name,
    String? muscleGroup,
    String? equipment,
    bool? isCustom,
  }) =>
      Exercise(
        id: id ?? this.id,
        name: name ?? this.name,
        muscleGroup: muscleGroup ?? this.muscleGroup,
        equipment: equipment ?? this.equipment,
        isCustom: isCustom ?? this.isCustom,
      );
}

const List<String> kMuscleGroups = [
  'Chest',
  'Back',
  'Shoulders',
  'Arms',
  'Legs',
  'Core',
  'Cardio',
  'Full Body',
];

const List<String> kEquipmentTypes = [
  'Barbell',
  'Dumbbell',
  'Cable',
  'Machine',
  'Bodyweight',
  'Kettlebell',
  'Resistance Band',
  'Other',
];
