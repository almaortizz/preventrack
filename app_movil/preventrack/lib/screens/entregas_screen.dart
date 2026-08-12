import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class EntregasScreen extends StatelessWidget {
  const EntregasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 64,
            color: AppColors.textPrimary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'Entregas',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textPrimary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Próximamente',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}
