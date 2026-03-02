import 'package:flutter/material.dart';

class StepIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep;
  final List<String>? labels;

  const StepIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: List.generate(totalSteps * 2 - 1, (index) {
        if (index.isOdd) {
          // Connector line
          final stepBefore = index ~/ 2;
          return Expanded(
            child: Container(
              height: 2,
              color: stepBefore < currentStep ? primary : Colors.grey.shade700,
            ),
          );
        }
        final step = index ~/ 2;
        final isCompleted = step < currentStep;
        final isCurrent = step == currentStep;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? primary
                    : isCurrent
                        ? primary.withValues(alpha: 0.3)
                        : Colors.grey.shade800,
                border: isCurrent
                    ? Border.all(color: primary, width: 2)
                    : null,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(
                        '${step + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isCurrent ? primary : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            if (labels != null && step < labels!.length) ...[
              const SizedBox(height: 4),
              Text(
                labels![step],
                style: TextStyle(
                  fontSize: 10,
                  color: isCurrent ? primary : Colors.grey,
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}
