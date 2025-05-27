
class SegmentConsumption {
    final int segmentIndex;
    final double consumption; // in liters
    final Map<String, double> influencingFactors; // factor name to impact percentage

    SegmentConsumption({
        required this.segmentIndex,
        required this.consumption,
        required this.influencingFactors,
    });
}
