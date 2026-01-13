# Seed File Logging Ruleset

# 1. Start with a clear action statement

puts 'Seeding [resource name]...'

# 2. Log any destructive actions

# Example: Category.destroy_all

# (No explicit log needed, but can add if desired)

# 3. Log data gathering/preparation steps

puts "Found #{count} total [resources]"
puts 'Creating [specific action]...'

# 4. Track metrics during processing

records_created = 0
records_skipped = 0

# 5. Log individual operations with checkmarks

puts " ✓ [Success message] (additional info)"
puts " ✗ Failed: [error details]"

# 6. Log warnings for missing data

puts "Warning: [What was not found]"

# 7. End with a summary section using separators

puts "\n" + "="*60
puts "[Resource] Seeding Complete!"
puts "="*60
puts "✓ Created: #{records_created} [resource type]"
puts "✓ [Other success metric]"
puts "⚠ Skipped: #{records_skipped} (reason)"

# 8. Optional: Show sample data

puts "\nSample [resources] by [category]:"
puts "-" \* 40

# Display sample records

# Symbols to use:

# ✓ - Success

# ✗ - Failure

# ⚠ - Warning

# → - Relationship/connection indicator

# ↔ - Bidirectional relationship
