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
}
