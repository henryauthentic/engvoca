import 'package:flutter/material.dart';
import '../utils/constants.dart';

class QuizOptionTile extends StatelessWidget {
  final String option;
  final int index;
  final bool isSelected;
  final bool? isCorrect;
  final VoidCallback onTap;

  const QuizOptionTile({
    super.key,
    required this.option,
    required this.index,
    required this.isSelected,
    this.isCorrect,
    required this.onTap,
  });

  Color _getBackgroundColor() {
    if (isCorrect != null) {
      if (isCorrect!) {
        return AppConstants.secondaryColor.withOpacity(0.2);
      } else if (isSelected) {
        return AppConstants.errorColor.withOpacity(0.2);
      }
    } else if (isSelected) {
      return AppConstants.primaryColor.withOpacity(0.2);
    }
    return Colors.white;
  }

  Color _getBorderColor() {
    if (isCorrect != null) {
      if (isCorrect!) {
        return AppConstants.secondaryColor;
      } else if (isSelected) {
        return AppConstants.errorColor;
      }
    } else if (isSelected) {
      return AppConstants.primaryColor;
    }
    return Colors.grey[300]!;
  }

  IconData? _getIcon() {
    if (isCorrect != null) {
      if (isCorrect!) {
        return Icons.check_circle;
      } else if (isSelected) {
        return Icons.cancel;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final optionLabels = ['A', 'B', 'C', 'D'];

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      child: InkWell(
        onTap: isCorrect == null ? onTap : null,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(
              color: _getBorderColor(),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _getBorderColor(),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    optionLabels[index],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              Expanded(
                child: Text(
                  option,
                  style: AppConstants.bodyStyle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_getIcon() != null) ...[
                const SizedBox(width: AppConstants.paddingSmall),
                Icon(
                  _getIcon(),
                  color: _getBorderColor(),
                  size: 28,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}