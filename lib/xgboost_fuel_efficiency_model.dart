import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ml_algo/ml_algo.dart';
import 'package:ml_dataframe/ml_dataframe.dart';
import 'package:ml_preprocessing/ml_preprocessing.dart';
import 'package:ml_linalg/linalg.dart';

class XGBoostFuelEfficiencyModel {
  Future<void> trainAndEvaluateModel() async {
    try {
      // Load the data
      final data = await loadCsvData('assets/car_performance_dataset.csv');
      print('Data head:');
      printDataHead(data, 5);
      printDataInfo(data);
      printDataStats(data);

      // Prepare the data
      final features = extractFeatures(data);
      final target = extractTarget(data, 'Fuel_Efficiency');
      
      // Handle categorical features
      final encodedFeatures = oneHotEncodeFeatures(features);
      
      // Split data into train and test sets (80% train, 20% test)
      final splits = splitData(encodedFeatures, target, 0.2, 42);
      final xTrain = splits['xTrain']!;
      final xTest = splits['xTest']!;
      final yTrain = splits['yTrain']!;
      final yTest = splits['yTest']!;
      
      // For demonstration - using simple regression approach
      final featureRows = <List<double>>[];
      for (final feature in xTrain) {
        final row = <double>[];
        feature.forEach((key, value) {
          if (value is num) {
            row.add(value.toDouble());
          } else if (value is String) {
            final numVal = double.tryParse(value);
            if (numVal != null) {
              row.add(numVal);
            } else {
              row.add(0.0); // Default value for non-numeric
            }
          } else {
            row.add(0.0); // Default value
          }
        });
        featureRows.add(row);
      }
      
      // Create a simple linear regression model manually
      final coefficients = solveLinearRegression(featureRows, yTrain);
      
      // Make predictions
      final predictions = predictWithLinearModel(coefficients, xTest);
      
      // Calculate metrics
      final metrics = calculateMetrics(yTest, predictions);
      final rmse = metrics['rmse']!;
      final r2 = metrics['r2']!;
      
      print('RMSE (Root Mean Squared Error): ${rmse.toStringAsFixed(4)}');
      print('R² (Coefficient of Determination): ${r2.toStringAsFixed(4)}');
      
      // Create comparison DataFrame
      printComparison(yTest, predictions, 5);
    } catch (e) {
      print('Error during model training: $e');
    }
  }
  
  // Simple linear regression solver - returns coefficients
  List<double> solveLinearRegression(List<List<double>> x, List<double> y) {
    // This is a very simple implementation without matrix operations
    // In a real app, use proper matrix libraries for efficiency
    final n = x.length;
    if (n == 0 || x[0].isEmpty) return [];
    
    final featureCount = x[0].length;
    final coefficients = List<double>.filled(featureCount + 1, 0.0); // +1 for intercept
    
    // Calculate means
    double yMean = 0;
    final xMeans = List<double>.filled(featureCount, 0);
    
    for (int i = 0; i < n; i++) {
      yMean += y[i];
      for (int j = 0; j < featureCount; j++) {
        xMeans[j] += x[i][j];
      }
    }
    
    yMean /= n;
    for (int j = 0; j < featureCount; j++) {
      xMeans[j] /= n;
    }
    
    // Calculate coefficients using normal equations (simplified)
    for (int j = 0; j < featureCount; j++) {
      double numerator = 0;
      double denominator = 0;
      
      for (int i = 0; i < n; i++) {
        numerator += (x[i][j] - xMeans[j]) * (y[i] - yMean);
        denominator += math.pow(x[i][j] - xMeans[j], 2);
      }
      
      if (denominator != 0) {
        coefficients[j + 1] = numerator / denominator;
      }
    }
    
    // Calculate intercept
    coefficients[0] = yMean;
    for (int j = 0; j < featureCount; j++) {
      coefficients[0] -= coefficients[j + 1] * xMeans[j];
    }
    
    return coefficients;
  }
  
  // Predict using coefficients
  List<double> predictWithLinearModel(List<double> coefficients, List<Map<String, dynamic>> testData) {
    final predictions = <double>[];
    
    for (final feature in testData) {
      final row = <double>[];
      feature.forEach((key, value) {
        if (value is num) {
          row.add(value.toDouble());
        } else if (value is String) {
          final numVal = double.tryParse(value);
          if (numVal != null) {
            row.add(numVal);
          } else {
            row.add(0.0);
          }
        } else {
          row.add(0.0);
        }
      });
      
      // Calculate prediction: intercept + sum(coef * feature)
      double prediction = coefficients[0]; // intercept
      for (int i = 0; i < row.length && i < coefficients.length - 1; i++) {
        prediction += coefficients[i + 1] * row[i];
      }
      
      predictions.add(prediction);
    }
    
    return predictions;
  }
  
  Future<List<List<dynamic>>> loadCsvData(String filePath) async {
    try {
      final file = File(filePath);
      final csvString = await file.readAsString();
      return const CsvToListConverter().convert(csvString);
    } catch (e) {
      print('Error loading CSV data: $e');
      return [];
    }
  }
  
  void printDataHead(List<List<dynamic>> data, int rows) {
    final header = data[0];
    print('Columns: $header');
    
    for (var i = 1; i <= rows && i < data.length; i++) {
      print('Row $i: ${data[i]}');
    }
  }
  
  void printDataInfo(List<List<dynamic>> data) {
    final rowCount = data.length - 1; // Exclude header
    final columnCount = data[0].length;
    
    print('\nDataset Info:');
    print('Number of rows: $rowCount');
    print('Number of columns: $columnCount');
    print('Column names: ${data[0].join(", ")}');
  }
  
  void printDataStats(List<List<dynamic>> data) {
    final header = data[0] as List<String>;
    final numRows = data.length - 1;
    
    print('\nDataset Statistics:');
    
    for (var colIndex = 0; colIndex < header.length; colIndex++) {
      final colName = header[colIndex];
      final values = <double>[];
      
      // Try to extract numeric values
      for (var i = 1; i < data.length; i++) {
        final val = data[i][colIndex];
        if (val is num) {
          values.add(val.toDouble());
        } else if (val is String) {
          final numVal = double.tryParse(val);
          if (numVal != null) {
            values.add(numVal);
          }
        }
      }
      
      if (values.isNotEmpty) {
        values.sort();
        final mean = values.reduce((a, b) => a + b) / values.length;
        final minVal = values.first;
        final maxVal = values.last;
        final median = values[values.length ~/ 2];
        
        print('$colName: mean=$mean, min=$minVal, max=$maxVal, median=$median');
      } else {
        print('$colName: categorical with ${countUniqueValues(data, colIndex)} unique values');
      }
    }
  }
  
  int countUniqueValues(List<List<dynamic>> data, int colIndex) {
    final uniqueValues = <dynamic>{};
    for (var i = 1; i < data.length; i++) {
      uniqueValues.add(data[i][colIndex]);
    }
    return uniqueValues.length;
  }
  
  List<Map<String, dynamic>> extractFeatures(List<List<dynamic>> data) {
    final headers = data[0] as List<String>;
    final features = <Map<String, dynamic>>[];
    
    // Find the index of the target column
    final targetIndex = headers.indexOf('Fuel_Efficiency');
    
    for (var i = 1; i < data.length; i++) {
      final row = data[i];
      final featureMap = <String, dynamic>{};
      
      for (var j = 0; j < headers.length; j++) {
        // Skip target column
        if (j != targetIndex) {
          featureMap[headers[j]] = row[j];
        }
      }
      
      features.add(featureMap);
    }
    
    return features;
  }
  
  List<double> extractTarget(List<List<dynamic>> data, String targetName) {
    final headers = data[0] as List<String>;
    final targetIndex = headers.indexOf(targetName);
    final target = <double>[];
    
    for (var i = 1; i < data.length; i++) {
      final value = data[i][targetIndex];
      if (value is num) {
        target.add(value.toDouble());
      } else if (value is String) {
        final numVal = double.tryParse(value);
        if (numVal != null) {
          target.add(numVal);
        } else {
          target.add(0.0); // Default value for non-numeric
        }
      } else {
        target.add(0.0); // Default value
      }
    }
    
    return target;
  }
  
  List<Map<String, dynamic>> oneHotEncodeFeatures(List<Map<String, dynamic>> features) {
    final result = <Map<String, dynamic>>[];
    final categoricalColumns = <String>{};
    final uniqueValues = <String, Set<dynamic>>{};
    
    // Identify categorical columns and their unique values
    if (features.isNotEmpty) {
      for (final key in features[0].keys) {
        final firstValue = features[0][key];
        if (firstValue is String && double.tryParse(firstValue) == null) {
          categoricalColumns.add(key);
          uniqueValues[key] = <dynamic>{};
        }
      }
      
      // Collect unique values for each categorical column
      for (final feature in features) {
        for (final column in categoricalColumns) {
          uniqueValues[column]!.add(feature[column]);
        }
      }
    }
    
    // Create one-hot encoded features
    for (final feature in features) {
      final encodedFeature = <String, dynamic>{};
      
      // Copy numeric features as is
      for (final key in feature.keys) {
        if (!categoricalColumns.contains(key)) {
          encodedFeature[key] = feature[key];
        }
      }
      
      // Add one-hot encoded features
      for (final column in categoricalColumns) {
        for (final value in uniqueValues[column]!) {
          final newKey = '${column}_$value';
          encodedFeature[newKey] = feature[column] == value ? 1.0 : 0.0;
        }
      }
      
      result.add(encodedFeature);
    }
    
    return result;
  }
  
  Map<String, dynamic> splitData(
    List<Map<String, dynamic>> features, 
    List<double> target, 
    double testSize, 
    int randomSeed
  ) {
    final random = math.Random(randomSeed);
    final indices = List<int>.generate(features.length, (i) => i);
    indices.shuffle(random);
    
    final testCount = (features.length * testSize).round();
    final testIndices = indices.sublist(0, testCount);
    final trainIndices = indices.sublist(testCount);
    
    final xTrain = trainIndices.map((i) => features[i]).toList();
    final xTest = testIndices.map((i) => features[i]).toList();
    final yTrain = trainIndices.map((i) => target[i]).toList();
    final yTest = testIndices.map((i) => target[i]).toList();
    
    return {
      'xTrain': xTrain,
      'xTest': xTest,
      'yTrain': yTrain,
      'yTest': yTest,
    };
  }
  
  Map<String, double> calculateMetrics(List<double> actual, List<double> predicted) {
    // Calculate RMSE
    double sumSquaredError = 0;
    for (int i = 0; i < actual.length; i++) {
      sumSquaredError += math.pow(actual[i] - predicted[i], 2);
    }
    final mse = sumSquaredError / actual.length;
    final rmse = math.sqrt(mse);
    
    // Calculate R²
    final actualMean = actual.reduce((a, b) => a + b) / actual.length;
    double totalSumOfSquares = 0;
    double residualSumOfSquares = 0;
    
    for (int i = 0; i < actual.length; i++) {
      totalSumOfSquares += math.pow(actual[i] - actualMean, 2);
      residualSumOfSquares += math.pow(actual[i] - predicted[i], 2);
    }
    
    final r2 = 1 - (residualSumOfSquares / totalSumOfSquares);
    
    return {
      'rmse': rmse,
      'r2': r2,
    };
  }
  
  void printComparison(List<double> actual, List<double> predicted, int rows) {
    print('\nComparison (first $rows rows):');
    print('Actual | Predicted');
    print('-------|----------');
    
    for (var i = 0; i < rows && i < actual.length; i++) {
      print('${actual[i].toStringAsFixed(2)} | ${predicted[i].toStringAsFixed(2)}');
    }
  }
  
  // Widget to display actual vs predicted chart (similar to matplotlib plot)
  Widget buildPredictionChart(List<double> actual, List<double> predicted) {
    // Find min and max for axes
    final allValues = [...actual, ...predicted];
    final minValue = allValues.reduce((a, b) => a < b ? a : b);
    final maxValue = allValues.reduce((a, b) => a > b ? a : b);
    
    // Create scatter plot points
    final scatterData = <ScatterSpot>[];
    for (var i = 0; i < actual.length; i++) {
      scatterData.add(ScatterSpot(actual[i], predicted[i]));
    }
    
    // Create perfect prediction line points
    final lineData = [
      FlSpot(minValue, minValue),
      FlSpot(maxValue, maxValue),
    ];
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        height: 300,
        child: ScatterChart(
          ScatterChartData(
            scatterSpots: scatterData,
            borderData: FlBorderData(show: true),
            gridData: FlGridData(show: true),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(1)),
                ),
                axisNameWidget: const Text('Actual Fuel Efficiency'),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(1)),
                ),
                axisNameWidget: const Text('Predicted Fuel Efficiency'),
              ),
            ),
            scatterTouchData: ScatterTouchData(enabled: true),
          ),
        ),
      ),
    );
  }
}
