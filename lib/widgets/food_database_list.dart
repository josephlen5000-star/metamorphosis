import 'package:flutter/cupertino.dart';

import '../models/food_item.dart';
import '../services/food_database.dart';

class FoodDatabaseList extends StatelessWidget {
  const FoodDatabaseList({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FoodItem>>(
      future: FoodDatabase.instance.getAllFoods(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CupertinoActivityIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text('Failed to load food database.'),
          );
        }

        final foods = snapshot.data ?? [];
        if (foods.isEmpty) {
          return const Center(child: Text('No foods found in the database.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: foods.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final food = foods[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Calories: ${food.calories} kcal'),
                  const SizedBox(height: 4),
                  Text('Protein: ${food.protein} g, Carbs: ${food.carbohydrates} g'),
                  const SizedBox(height: 4),
                  Text('Fats: ${food.fats} g'),
                  const SizedBox(height: 4),
                  Text('Omega-6: ${food.omega6} g, Omega-3: ${food.omega3} g'),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
