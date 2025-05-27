// lib/widgets/prediction_result_card.dart - Result display widget
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:trip_tank_fuely/predicionResult.dart';
import 'package:trip_tank_fuely/segmentConsumption.dart';

class PredictionResultCard extends StatelessWidget {
    final PredictionResult result;

    const PredictionResultCard({
        super.key,
        required this.result,
    });

    @override
    Widget build(BuildContext context) {
        developer.log('Building PredictionResultCard: ${result.totalFuelConsumption} L');
        
        return Card(
            elevation: 4,
            child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        const Text(
                            'Prediction Result',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        _buildDetailRow(
                            'Total Distance:',
                            '${result.totalDistance.toStringAsFixed(2)} km',
                        ),
                        _buildDetailRow(
                            'Total Consumption:',
                            '${result.totalFuelConsumption.toStringAsFixed(2)} L',
                        ),
                        _buildDetailRow(
                            'Consumption Rate:',
                            '${result.fuelConsumptionRate.toStringAsFixed(2)} L/100km',
                        ),
                        _buildDetailRow(
                            'Estimated Cost:',
                            '${(result.costEstimate * 30.0).toStringAsFixed(2)} EGP',
                        ),
                        _buildDetailRow(
                            'CO₂ Emissions:',
                            '${result.co2Emissions.toStringAsFixed(2)} kg',
                        ),

                        // Expand/collapse button for more details
                        if (result.segmentConsumptions.isNotEmpty)
                            ExpansionTile(
                                title: const Text('Influencing Factors'),
                                children: [
                                    Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: _buildFactorsWidgets(result.segmentConsumptions.first),
                                        ),
                                    ),
                                ],
                            ),
                    ],
                ),
            ),
        );
    }

    Widget _buildDetailRow(String label, String value) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(value),
                ],
            ),
        );
    }

    List<Widget> _buildFactorsWidgets(SegmentConsumption segment) {
        // Safety check to handle empty influencing factors
        if (segment.influencingFactors.isEmpty) {
            return [const Text('No factors available')];
        }
        
        try {
            final factors = segment.influencingFactors.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

            return factors.map((factor) {
                // Ensure percentage is within reasonable bounds
                final value = factor.value.isNaN || factor.value.isInfinite 
                    ? 0.0 
                    : factor.value.clamp(0.0, 100.0);
                    
                return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                        children: [
                            Expanded(
                                flex: 2,
                                child: Text(factor.key),
                            ),
                            Expanded(
                                flex: 3,
                                child: LinearProgressIndicator(
                                    value: value / 100,
                                    backgroundColor: Colors.grey[300],
                                    color: _getColorForFactor(factor.key),
                                ),
                            ),
                            const SizedBox(width: 8),
                            Text('${value.toStringAsFixed(1)}%'),
                        ],
                    ),
                );
            }).toList();
        } catch (e) {
            developer.log('Error building factor widgets: $e');
            return [Text('Error displaying factors: $e')];
        }
    }

    Color _getColorForFactor(String factor) {
        switch (factor) {
            case 'Weight':
                return Colors.blue;
            case 'Engine':
                return Colors.red;
            case 'Cylinders':
                return Colors.orange;
            case 'Aerodynamics':
                return Colors.purple;
            case 'Wind':
                return Colors.teal;
            case 'Temperature':
                return Colors.amber;
            case 'Rain':
                return Colors.lightBlue;
            case 'Elevation':
                return Colors.green;
            case 'Driving Style':
                return Colors.deepOrange;
            default:
                return Colors.grey;
        }
    }
}