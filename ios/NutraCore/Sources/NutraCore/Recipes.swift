import Foundation

/// A recipe idea on the GI Nutrition Foundation's site. The app shows the title, a one-line summary of
/// its own and the time, and links out for the ingredients and method.
public struct Recipe: Sendable, Hashable, Identifiable {
  public let title: String
  public let summary: String
  public let url: URL
  /// Prep plus cook time, when the recipe gives both.
  public let minutes: Int?
  /// The site's diet labels: CDED, SCD, IBD-AID, AIP, Mediterranean, Gentle GI.
  public let diets: [String]
  /// What to change for this condition, if anything.
  public let tip: String?
  public var id: URL { url }

  init(_ title: String, _ slug: String, minutes: Int?, diets: [String], _ summary: String, tip: String? = nil) {
    self.title = title
    self.summary = summary
    self.url = URL(string: "https://www.ginutritionfoundation.org/recipes/" + slug)!
    self.minutes = minutes
    self.diets = diets
    self.tip = tip
  }
}

extension ConditionCatalog {
  public static let recipePublisher = "GI Nutrition Foundation"
  public static let recipeIndex = URL(string: "https://www.ginutritionfoundation.org/recipes")!

  /// Recipe ideas for the digestive conditions. Each was checked against the condition's common triggers
  /// by its ingredient list; `recipeNote(for:)` says what was checked.
  public static func recipes(for id: String) -> [Recipe] {
    switch id {
    case "ibd":
      return [
        Recipe("Chicken Meatballs with Spinach and Mashed Potatoes", "chicken-meatballs-with-spinach-and-mashed-potatoes",
               minutes: 35, diets: ["CDED", "mSCD", "Gentle GI"],
               "Soft chicken and spinach meatballs over mashed potato.",
               tip: "Olive oil works in place of the butter."),
        Recipe("Turkey Meatloaf", "turkey-meatloaf", minutes: 35, diets: ["SCD", "IBD-AID", "Gentle GI"],
               "A simple turkey and carrot loaf: lean protein that's easy to digest."),
        Recipe("Millet Congee with Jujube (Red Dates)", "millet-congee-with-jujube-red-dates",
               minutes: 45, diets: ["Gentle GI", "Mediterranean"],
               "A soft, warming millet porridge with carrot, ginger and turmeric."),
        Recipe("Creamy Pumpkin Millet Porridge", "creamy-pumpkin-millet-porridge",
               minutes: 40, diets: ["CDED", "Gentle GI", "Mediterranean"],
               "Pumpkin cooked into millet for a smooth, filling breakfast."),
        Recipe("Persian Jujeh Kebab with Saffron Rice", "persian-jujeh-kebab-with-saffron-rice-and-zereshk-dried-barberries",
               minutes: 65, diets: ["CDED", "mSCD"],
               "Saffron and lemon chicken with basmati rice; fits CDED phase 1.",
               tip: "Marinate the chicken for 2 to 4 hours first."),
        Recipe("Eggs From the Oven with Warm Smoked Salmon", "eggs-from-the-oven-with-warm-smoked-salmon-oeufs-en-cocotte",
               minutes: 25, diets: ["SCD", "IBD-AID", "CDED"],
               "Baked eggs with smoked salmon and herbs: quick protein on low-appetite days."),
      ]
    case "ibs":
      return [
        Recipe("Vietnamese Chicken Pho", "vietnamese-chicken-pho", minutes: 15, diets: ["CDED", "Mediterranean"],
               "Rice noodles, chicken and greens in a hot broth.",
               tip: "Use only the green part of the scallions, and a broth made without onion or garlic."),
        Recipe("Broiled Salmon", "broiled-salmon", minutes: 17, diets: ["SCD", "AIP", "Mediterranean"],
               "Salmon with just olive oil, salt and pepper: no onion or garlic."),
        Recipe("Millet with Dill", "millet-with-dill-a-simple-flavorful-side-dish", minutes: 15,
               diets: ["CDED", "Mediterranean"], "A quick millet side with carrot, dill and mild curry.",
               tip: "Leave out the optional bell pepper, as the recipe suggests for low-FODMAP."),
        Recipe("Quinoa and Vegetable Salad", "quinoa-and-vegetable-salad", minutes: 15, diets: ["Mediterranean"],
               "Quinoa with cucumber, tomato, pepper and a boiled egg.",
               tip: "Keep the optional tahini to a small drizzle."),
        Recipe("Thyme Blueberry Pork Patties", "thyme-blueberry-pork-patties", minutes: 15, diets: ["AIP", "SCD"],
               "Four-ingredient breakfast patties with fresh blueberries."),
        Recipe("Baked Chicken Nuggets", "baked-chicken-nuggets", minutes: 35, diets: ["CDED", "mSCD"],
               "Chicken strips in a rice-flour and spice coating, baked instead of fried."),
      ]
    case "celiac":
      return [
        Recipe("Grain-Free Cauliflower Tabouli Salad", "grain-free-cauliflower-tabouli-salad", minutes: 40,
               diets: ["SCD", "Mediterranean"], "Tabouli made with riced cauliflower instead of bulgur wheat."),
        Recipe("Shish Tavuk (Chicken Skewers)", "shish-tavuk-chicken-skewers", minutes: 40, diets: ["SCD", "CDED"],
               "Chicken marinated in yogurt, lemon and spices, cooked on skewers.",
               tip: "Marinate for at least 3 hours."),
        Recipe("Millet with Beetroot, Carrots and Fresh Herbs", "millet-with-beetroot-carrots-and-fresh-herbs",
               minutes: 35, diets: ["Gentle GI", "Mediterranean"],
               "Millet, a naturally gluten-free grain, with beets, carrots and warm spices.",
               tip: "Buy millet labeled gluten-free; plain grains can pick up wheat in processing."),
        Recipe("Mediterranean Salmon Salad", "mediterranean-salmon-salad-with-a-lemon-oregano-dressing", minutes: 20,
               diets: ["SCD", "Mediterranean"], "Salmon, egg, avocado and olives on lettuce with a lemon dressing.",
               tip: "Check the canned salmon's label for added ingredients."),
        Recipe("Banana Blueberry Muffins", "banana-blueberry-muffins", minutes: 40, diets: ["SCD", "Mediterranean"],
               "Muffins made with almond flour and banana instead of wheat flour."),
        Recipe("Kulish (Ukrainian Millet and Chicken Porridge)", "kulish-ukrainian-millet-and-chicken-porridge",
               minutes: 50, diets: ["CDED", "Gentle GI"], "A hearty one-pot porridge of chicken, potato and millet.",
               tip: "Use gluten-free millet and a broth labeled gluten-free."),
      ]
    case "eoe":
      return [
        Recipe("Classic Chicken Soup", "classic-chicken-soup", minutes: 50, diets: ["SCD", "CDED"],
               "Chicken, carrots and celery simmered with thyme.",
               tip: "Choose a broth without milk, wheat or soy."),
        Recipe("AIP Taco Meat", "aip-taco-meat", minutes: 20, diets: ["AIP", "SCD"],
               "Seasoned ground beef or turkey for rice bowls or lettuce wraps."),
        Recipe("Traditional Mujadara", "traditional-mujadara-with-soft-caramelized-onions", minutes: 55,
               diets: ["CDED", "Mediterranean"], "Rice and lentils with slow-cooked onions and cumin."),
        Recipe("Roasted Rosemary Baby Potatoes", "roasted-rosemary-baby-potatoes", minutes: 50, diets: ["AIP", "CDED"],
               "Crisp roasted potatoes with rosemary and olive oil."),
        Recipe("Curried Chicken, Sweet Potato, and Kale Soup", "curried-chicken-sweet-potato-and-kale-soup",
               minutes: nil, diets: ["AIP", "SCD", "Mediterranean"],
               "A coconut-milk curry soup with chicken, sweet potato and kale."),
        Recipe("Thyme Blueberry Pork Patties", "thyme-blueberry-pork-patties", minutes: 15, diets: ["AIP", "SCD"],
               "Four-ingredient breakfast patties with fresh blueberries."),
      ]
    default:
      return []
    }
  }

  /// Why these recipes, shown under the list.
  public static func recipeNote(for id: String) -> String? {
    switch id {
    case "ibd":
      return "From the site's IBD diets (CDED, IBD-AID, SCD, Gentle GI). Softer dishes suit a flare; check with your care team which diet you're on."
    case "ibs":
      return "Chosen because their ingredients avoid common high-FODMAP foods such as onion, garlic, wheat, beans and lactose. Portion sizes still matter."
    case "celiac":
      return "Made without wheat, barley, rye or regular oats. Check packaged ingredients like broth and spices for gluten and cross-contact."
    case "eoe":
      return "Made without the six common trigger foods: milk, wheat, egg, soy, nuts and seafood. Your own plan may remove fewer foods; check labels for hidden allergens."
    default:
      return nil
    }
  }
}
