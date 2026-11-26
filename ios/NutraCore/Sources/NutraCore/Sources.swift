import Foundation

/// A published guideline a piece of the app's health guidance is based on, shown with a link.
public struct GuidanceSource: Sendable, Hashable {
  public let title: String
  public let publisher: String
  public let url: URL

  init(_ title: String, _ publisher: String, _ url: String) {
    self.title = title
    self.publisher = publisher
    self.url = URL(string: url)!
  }
}

extension ConditionCatalog {
  /// How the daily calorie target is estimated (resting energy × activity, then the weekly pace).
  public static let calorieMethod = GuidanceSource(
    "A new predictive equation for resting energy expenditure in healthy individuals (Mifflin-St Jeor, 1990)",
    "American Journal of Clinical Nutrition", "https://doi.org/10.1093/ajcn/51.2.241")

  private static let dietaryGuidelines = GuidanceSource(
    "Dietary Guidelines for Americans", "USDA and HHS", "https://www.dietaryguidelines.gov/")
  private static let diabetes = GuidanceSource(
    "Healthy Living with Diabetes", "NIDDK, National Institutes of Health",
    "https://www.niddk.nih.gov/health-information/diabetes/overview/healthy-living-with-diabetes")
  private static let dash = GuidanceSource(
    "DASH Eating Plan", "NHLBI, National Institutes of Health", "https://www.nhlbi.nih.gov/health/dash-eating-plan")
  private static let aha = GuidanceSource(
    "The American Heart Association's Diet and Lifestyle Recommendations", "American Heart Association",
    "https://www.heart.org/en/healthy-living/healthy-eating/eat-smart/nutrition-basics/aha-diet-and-lifestyle-recommendations")

  /// Where each condition's targets and advice come from. Every condition in `all` has at least one.
  public static func sources(for id: String) -> [GuidanceSource] {
    switch id {
    case "t2_diabetes", "t1_diabetes": return [diabetes, dietaryGuidelines]
    case "hypertension": return [dash, aha]
    case "heart_disease": return [aha, dash]
    case "high_cholesterol":
      return [GuidanceSource("Cholesterol", "MedlinePlus, National Library of Medicine", "https://medlineplus.gov/cholesterol.html"), aha]
    case "ckd":
      return [GuidanceSource("Healthy Eating for Adults with Chronic Kidney Disease", "NIDDK, National Institutes of Health",
        "https://www.niddk.nih.gov/health-information/kidney-disease/chronic-kidney-disease-ckd/healthy-eating-adults-chronic-kidney-disease")]
    case "liver":
      return [GuidanceSource("Eating, Diet, & Nutrition for Cirrhosis", "NIDDK, National Institutes of Health",
        "https://www.niddk.nih.gov/health-information/liver-disease/cirrhosis/eating-diet-nutrition")]
    case "celiac":
      return [GuidanceSource("Eating, Diet, & Nutrition for Celiac Disease", "NIDDK, National Institutes of Health",
        "https://www.niddk.nih.gov/health-information/digestive-diseases/celiac-disease/eating-diet-nutrition"),
        GuidanceSource("Celiac disease", "GI Nutrition Foundation", "https://www.ginutritionfoundation.org/celiac-disease")]
    case "weight_loss":
      return [GuidanceSource("Weight Management", "NIDDK, National Institutes of Health",
        "https://www.niddk.nih.gov/health-information/weight-management"), dietaryGuidelines]
    case "hypothyroid":
      return [GuidanceSource("Hypothyroidism (Underactive Thyroid)", "NIDDK, National Institutes of Health",
        "https://www.niddk.nih.gov/health-information/endocrine-diseases/hypothyroidism"), dietaryGuidelines]
    case "ibs":
      return [GuidanceSource("Eating, Diet, & Nutrition for Irritable Bowel Syndrome", "NIDDK, National Institutes of Health",
        "https://www.niddk.nih.gov/health-information/digestive-diseases/irritable-bowel-syndrome/eating-diet-nutrition"),
        GuidanceSource("The low FODMAP diet", "Monash University", "https://www.monashfodmap.com/"),
        GuidanceSource("Dietary options for IBS", "GI Nutrition Foundation",
        "https://www.ginutritionfoundation.org/dietary-options-overview-ibs")]
    case "ibd":
      return [GuidanceSource("Eating, Diet, & Nutrition for Crohn's Disease", "NIDDK, National Institutes of Health",
        "https://www.niddk.nih.gov/health-information/digestive-diseases/crohns-disease/eating-diet-nutrition"),
        GuidanceSource("Eating, Diet, & Nutrition for Ulcerative Colitis", "NIDDK, National Institutes of Health",
        "https://www.niddk.nih.gov/health-information/digestive-diseases/ulcerative-colitis/eating-diet-nutrition"),
        GuidanceSource("Dietary options for IBD", "GI Nutrition Foundation",
        "https://www.ginutritionfoundation.org/dietary-options-for-ibd")]
    case "eoe":
      return [GuidanceSource("Eosinophilic Esophagitis", "MedlinePlus, National Library of Medicine",
        "https://medlineplus.gov/eosinophilicesophagitis.html"),
        GuidanceSource("Eosinophilic Esophagitis (EoE)", "GI Nutrition Foundation",
        "https://www.ginutritionfoundation.org/eosinophilic-esophagitis")]
    case "bodybuilding":
      return [GuidanceSource("International Society of Sports Nutrition Position Stand: protein and exercise (2017)",
        "Journal of the International Society of Sports Nutrition", "https://doi.org/10.1186/s12970-017-0177-8")]
    case "endurance":
      return [GuidanceSource("Nutrition and Athletic Performance (ACSM, Academy of Nutrition and Dietetics, Dietitians of Canada, 2016)",
        "Medicine & Science in Sports & Exercise", "https://doi.org/10.1249/MSS.0000000000000852")]
    case "pregnancy":
      return [GuidanceSource("Pregnancy and Nutrition", "MedlinePlus, National Library of Medicine",
        "https://medlineplus.gov/pregnancyandnutrition.html"),
        GuidanceSource("Advice about Eating Fish", "U.S. Food and Drug Administration",
        "https://www.fda.gov/food/consumers/advice-about-eating-fish")]
    default: return [dietaryGuidelines]
    }
  }
}
