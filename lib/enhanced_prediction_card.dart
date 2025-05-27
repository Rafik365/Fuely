import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trip_tank_fuely/predicionResult.dart';
import 'package:trip_tank_fuely/segmentConsumption.dart';

class EnhancedPredictionCard extends StatelessWidget {
  final PredictionResult result;
  final VoidCallback? onFeedbackRequested;

  const EnhancedPredictionCard({
    super.key,
    required this.result,
    this.onFeedbackRequested,
  });

  @override
  Widget build(BuildContext context) {
    // Format numbers for display
    final consumptionFormat = NumberFormat("#,##0.00");
    final costFormat = NumberFormat.currency(symbol: '\$');

    // Get primary consumption class based on rate
    String consumptionClass = 'Medium';
    Color consumptionColor = Colors.orange;

    if (result.fuelConsumptionRate < 5.0) {
      consumptionClass = 'Very Low';
      consumptionColor = Colors.green.shade800;
    } else if (result.fuelConsumptionRate < 7.0) {
      consumptionClass = 'Low';
      consumptionColor = Colors.green;
    } else if (result.fuelConsumptionRate < 9.0) {
      consumptionClass = 'Medium';
      consumptionColor = Colors.orange;
    } else if (result.fuelConsumptionRate < 12.0) {
      consumptionClass = 'High';
      consumptionColor = Colors.deepOrange;
    } else {
      consumptionClass = 'Very High';
      consumptionColor = Colors.red;
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with AI badge
            Row(
              children: [
                const Text(
                  'Naive Bayes Prediction',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: Colors.blue.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ML',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(),

            // Consumption class indicator
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: consumptionColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: consumptionColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'Consumption Class:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    consumptionClass,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: consumptionColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Main metrics
            Row(
              children: [
                _buildMetricColumn(
                  'Total',
                  '${consumptionFormat.format(result.totalFuelConsumption)} L',
                  Icons.local_gas_station,
                  Colors.purple,
                ),
                _buildMetricColumn(
                  'Rate',
                  '${consumptionFormat.format(result.fuelConsumptionRate)} L/100km',
                  Icons.speed,
                  Colors.blue,
                ),
                _buildMetricColumn(
                  'Cost',
                  costFormat.format(result.costEstimate),
                  Icons.attach_money,
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // CO2 emissions
            Row(
              children: [
                Icon(Icons.eco, color: Colors.green[700], size: 16),
                const SizedBox(width: 8),
                Text(
                  'CO₂ Emissions:',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  '${consumptionFormat.format(result.co2Emissions)} kg',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        result.co2Emissions > 10
                            ? Colors.red
                            : Colors.green[700],
                  ),
                ),
              ],
            ),

            // Influencing factors
            if (result.segmentConsumptions.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 4),
                  Text(
                    'Contributing Factors:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: _buildFactorsWidgets(
                      result.segmentConsumptions.first,
                    ),
                  ),
                ],
              ),

            // Accuracy disclaimer
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Prediction accuracy improves with your feedback',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFactorsWidgets(SegmentConsumption segment) {
    final factors =
        segment.influencingFactors.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return factors.map((factor) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(factor.key, style: TextStyle(fontSize: 12)),
            ),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: factor.value / 100,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: _getColorForFactor(factor.key),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              child: Text(
                '${factor.value.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Color _getColorForFactor(String factor) {
    switch (factor) {
      case 'Vehicle Type':
        return Colors.purple;
      case 'Route':
        return Colors.blue;
      case 'Weather':
        return Colors.teal;
      case 'Driving Style':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
