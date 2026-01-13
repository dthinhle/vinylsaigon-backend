puts 'Seeding system configurations...'

# Idempotent seed for system configuration key/values.
# Uses find_or_initialize_by so repeated runs are safe even if migration/Model already exist.
if defined?(SystemConfig)
  configs_created = 0

  [
    { name: 'maxDiscountPercent', value: '50%' },
    { name: 'maxDiscountPerDay', value: '50000000' },
    { name: 'maxDiscountPerUserPerDay', value: '20000000' },
  ].each do |attrs|
    cfg = SystemConfig.find_or_initialize_by(name: attrs[:name])
    was_new = !cfg.persisted?
    cfg.value = attrs[:value]
    cfg.save!
    if was_new
      configs_created += 1
      puts "  ✓ Created system config '#{attrs[:name]}' = #{attrs[:value]}"
    else
      puts "  ↺ Updated system config '#{attrs[:name]}' = #{attrs[:value]}"
    end
  end

  puts "\n" + "="*60
  puts "System Configurations Seeding Complete!"
  puts "="*60
  puts "✓ Created: #{configs_created} system configurations"
else
  puts "⚠ Skipping system_configs seeds because SystemConfig model is not defined yet."
end
