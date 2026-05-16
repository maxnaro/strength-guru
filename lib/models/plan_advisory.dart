enum AdvisorySeverity { info, warn }

class PlanAdvisory {
  final AdvisorySeverity severity;
  final String scope;
  final String message;
  final String? source;

  const PlanAdvisory({
    required this.severity,
    required this.scope,
    required this.message,
    this.source,
  });
}
