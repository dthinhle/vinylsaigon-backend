module Admin::RelatedCategoriesHelper
  def weight_badge_classes(weight)
    case weight
    when 8..10 then 'bg-green-100 text-green-800'
    when 5..7 then 'bg-amber-100 text-amber-800'
    when 3..4 then 'bg-zinc-100 text-zinc-800'
    else 'bg-gray-100 text-gray-800'
    end
  end

  def compatibility_level_text(weight)
    case weight
    when 8..10 then 'Essential/Perfect Match'
    when 5..7 then 'High Compatibility'
    when 3..4 then 'Medium Compatibility'
    else 'Low Compatibility'
    end
  end

  def compatibility_level_color(weight)
    case weight
    when 8..10 then 'text-red-600'
    when 5..7 then 'text-yellow-600'
    when 3..4 then 'text-blue-600'
    else 'text-gray-600'
    end
  end
end
