/// Title, company, requirements, and how-to-apply content for a job
/// listing — read aloud for the user after AI Filtering & Matching
/// narrates it. See spec.md §6 "AI Filtering & Matching".
class JobListing {
  final String title;
  final String company;
  final String requirements;
  final String howToApply;

  const JobListing({
    required this.title,
    required this.company,
    required this.requirements,
    required this.howToApply,
  });

  factory JobListing.fromJson(Map<String, dynamic> json) => JobListing(
    title: (json['title'] as String?) ?? '',
    company: (json['company'] as String?) ?? '',
    requirements: (json['requirements'] as String?) ?? '',
    howToApply: (json['howToApply'] as String?) ?? '',
  );
}
