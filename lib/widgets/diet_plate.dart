import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'plate/add_food_button.dart';
import 'plate/dairy_badge.dart';
import 'plate/plate_divider_painter.dart';
import 'plate/plate_section.dart';

class DietPlate extends StatelessWidget {
  final VoidCallback onAddPressed;

  const DietPlate({super.key, required this.onAddPressed});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heightBound = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 300.0;
        final shortest = math.min(constraints.maxWidth, heightBound);
        final stage = shortest.clamp(240.0, 340.0);
        final plate = stage * 0.96;
        final well = plate * 0.34;
        final addSize = (plate * 0.24).clamp(56.0, 70.0);
        final dairySize = plate * 0.25;
        final labelSize = (plate * 0.052).clamp(12.0, 15.0);
        final wedges = plate * 0.86;

        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: stage,
            height: plate,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: plate,
                  height: plate,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.plateRim,
                    border: Border.all(
                      color: AppColors.plateRim,
                      width: 5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                ClipOval(
                  child: SizedBox(
                    width: wedges,
                    height: wedges,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                flex: 2,
                                child: PlateSection(
                                  label: 'Fruits',
                                  color: AppColors.plateFruit,
                                  textColor: AppColors.plateFruitText,
                                  alignment: const Alignment(0, -0.15),
                                  fontSize: labelSize,
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    28,
                                    28,
                                    8,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: PlateSection(
                                  label: 'Vegetables',
                                  color: AppColors.plateVegetable,
                                  textColor: AppColors.plateVegetableText,
                                  alignment: const Alignment(0, 0.05),
                                  fontSize: labelSize,
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    8,
                                    28,
                                    36,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                flex: 3,
                                child: PlateSection(
                                  label: 'Grains',
                                  color: AppColors.plateGrain,
                                  textColor: AppColors.plateGrainText,
                                  alignment: const Alignment(0, -0.35),
                                  fontSize: labelSize,
                                  padding: const EdgeInsets.fromLTRB(
                                    28,
                                    28,
                                    14,
                                    8,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: PlateSection(
                                  label: 'Protein',
                                  color: AppColors.plateProtein,
                                  textColor: AppColors.plateProteinText,
                                  alignment: const Alignment(0, 0.1),
                                  fontSize: labelSize,
                                  padding: const EdgeInsets.fromLTRB(
                                    28,
                                    8,
                                    14,
                                    32,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: wedges,
                  height: wedges,
                  child: const CustomPaint(
                    painter: PlateDividerPainter(),
                  ),
                ),
                Container(
                  width: well,
                  height: well,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.plateWell,
                    border: Border.all(
                      color: AppColors.plateRim,
                      width: 3,
                    ),
                  ),
                ),
                AddFoodButton(
                  onPressed: onAddPressed,
                  size: addSize,
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 6,
                  child: Center(
                    child: GestureDetector(
                      onTap: onAddPressed,
                      child: const AddFoodChip(),
                    ),
                  ),
                ),
                Positioned(
                  right: (stage - plate) / 2 - plate * 0.03,
                  top: plate * 0.02,
                  child: DairyBadge(size: dairySize),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
