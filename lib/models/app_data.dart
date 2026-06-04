// Model untuk makanan
class FoodItem {
  final String name;
  final double calories;
  final double carbs;
  final double protein;
  final double fat;
  final double? fiber;
  final String emoji;
  final String category;

  const FoodItem({
    required this.name,
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    this.fiber,
    required this.emoji,
    this.category = 'Semua Makanan',
  });
}

// Model untuk log makanan harian
class MealLog {
  final String foodName;
  final String mealType;
  final String time;
  final double calories;
  final String emoji;

  const MealLog({
    required this.foodName,
    required this.mealType,
    required this.time,
    required this.calories,
    required this.emoji,
  });
}

// Model untuk profil pengguna
class UserProfile {
  final String name;
  final int age;
  final String gender;
  final double weight;
  final double height;
  final String activityLevel;
  final double dailyCalorieTarget;
  final double targetWeight;

  const UserProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.weight,
    required this.height,
    required this.activityLevel,
    required this.dailyCalorieTarget,
    required this.targetWeight,
  });
}

// Data dummy
class AppData {
  static const userProfile = UserProfile(
    name: 'Abyan Dante Ilyasa',
    age: 20,
    gender: 'Laki-laki',
    weight: 68.4,
    height: 165,
    activityLevel: 'Sedentary',
    dailyCalorieTarget: 1850,
    targetWeight: 64.0,
  );

  static const List<FoodItem> foodDatabase = [
    FoodItem(
      name: 'Nanas',
      calories: 50,
      carbs: 13.1,
      protein: 0.5,
      fat: 0.1,
      fiber: 1.4,
      emoji: '🍍',
      category: 'Buah',
    ),
    FoodItem(
      name: 'Almond',
      calories: 579,
      carbs: 21.6,
      protein: 21.2,
      fat: 49.9,
      fiber: 12.5,
      emoji: '🌰',
      category: 'Semua Makanan',
    ),
    FoodItem(
      name: 'Curly Kale',
      calories: 49,
      carbs: 8.8,
      protein: 4.3,
      fat: 0.9,
      fiber: 3.6,
      emoji: '🥬',
      category: 'Sayuran',
    ),
    FoodItem(
      name: 'Salmon Atlantik',
      calories: 208,
      carbs: 0.0,
      protein: 20.4,
      fat: 13.4,
      fiber: 0.0,
      emoji: '🐟',
      category: 'Semua Makanan',
    ),
    FoodItem(
      name: 'Alpukat Hass',
      calories: 160,
      carbs: 8.5,
      protein: 2.0,
      fat: 14.7,
      fiber: 6.7,
      emoji: '🥑',
      category: 'Buah',
    ),
    FoodItem(
      name: 'Kacang Merah',
      calories: 116,
      carbs: 20.1,
      protein: 9.0,
      fat: 0.4,
      fiber: 7.9,
      emoji: '🫘',
      category: 'Sayuran',
    ),
    FoodItem(
      name: 'Pisang',
      calories: 89,
      carbs: 23.0,
      protein: 1.1,
      fat: 0.3,
      fiber: 2.6,
      emoji: '🍌',
      category: 'Buah',
    ),
    FoodItem(
      name: 'Brokoli',
      calories: 34,
      carbs: 7.0,
      protein: 2.8,
      fat: 0.4,
      fiber: 2.6,
      emoji: '🥦',
      category: 'Sayuran',
    ),
  ];

  static const List<MealLog> todayMeals = [
    MealLog(
      foodName: 'Salad Chickpea Mediterania',
      mealType: 'Makan Siang',
      time: '13:30',
      calories: 420,
      emoji: '🥗',
    ),
    MealLog(
      foodName: 'Avocado Sourdough Toast',
      mealType: 'Sarapan',
      time: '08:45',
      calories: 315,
      emoji: '🥑',
    ),
    MealLog(
      foodName: 'Antioxidant Berry Blast',
      mealType: 'Snack',
      time: '11:15',
      calories: 185,
      emoji: '🍓',
    ),
  ];
}
