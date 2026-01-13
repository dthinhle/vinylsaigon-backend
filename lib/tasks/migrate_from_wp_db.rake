namespace :migration do
  desc 'Migrate WordPress blogs using BlogMigratorService'
  task blogs: :environment do
    puts '=' * 80
    puts 'WordPress to Rails Blog Migration'
    puts '=' * 80
    puts

    # Initialize WordPress database service
    wp_db_service = WordpressDatabaseService.new

    begin
      # Connect to WordPress database
      wp_db_service.connect
      puts '✓ Successfully connected to WordPress database'
      puts

      # Run migration using BlogMigratorService
      migrator = WordpressMigration::BlogMigratorService.new(wp_db_service)
      stats = migrator.migrate_all

      # Print summary
      puts '=' * 80
      puts 'Migration Complete!'
      puts '=' * 80
      puts "Categories migrated: #{stats[:categories]}"
      puts "Posts inserted: #{stats[:posts_inserted]}"
      puts "Posts updated: #{stats[:posts_updated]}"
      puts "Posts skipped: #{stats[:posts_skipped]}"
      puts "Total posts processed: #{stats[:posts_inserted] + stats[:posts_updated]}"
      puts '=' * 80

    rescue Mysql2::Error => e
      puts "\n✗ Database connection error: #{e.message}"
      puts 'Please check your WordPress database credentials in .env file'
      puts
      puts 'Required environment variables:'
      puts '  WP_DB_HOST=localhost'
      puts '  WP_DB_PORT=3306'
      puts '  WP_DB_USERNAME=your_username'
      puts '  WP_DB_PASSWORD=your_password'
      puts '  WP_DB_NAME=wordpress'
      puts '  WP_TABLE_PREFIX=wp_'
      wp_db_service&.close
    rescue => e
      puts "\n✗ Unexpected error: #{e.message}"
      puts e.backtrace.first(10).join("\n")
      wp_db_service&.close
    end
  end

  desc 'Update blog feature images from WordPress source (Force update feature image only)'
  task update_blog_feature_images: :environment do
    puts '=' * 80
    puts 'Updating Blog Feature Images from WordPress'
    puts '=' * 80
    puts

    # Find blogs that were imported from WordPress
    blogs = Blog.where.not(source_wp_id: nil)
    total_blogs = blogs.count
    processed_count = 0
    error_count = 0

    puts "Found #{total_blogs} blogs imported from WordPress"
    puts '=' * 80

    blogs.find_each do |blog|
      processed_count += 1
      puts "[#{processed_count}/#{total_blogs}] Processing: #{blog.slug} (ID: #{blog.id}, WP ID: #{blog.source_wp_id})"

      begin
        # Force update feature image, skip content images
        BlogImageMigrationJob.perform_later(
          blog.id,
          force_featured_image: true,
          only_featured_image: true
        )
        puts '  ✅ Done'
      rescue => e
        error_count += 1
        puts "  ❌ Error: #{e.message}"
      end
    end

    puts "\n" + '=' * 80
    puts 'SUMMARY'
    puts '=' * 80
    puts "Total blogs: #{total_blogs}"
    puts "Processed: #{processed_count}"
    puts "Errors: #{error_count}"
    puts '=' * 80
    puts '✅ Completed!'
  end

  desc 'Create redirection mappings for blogs (/<slug> -> /tin-tuc/<slug>)'
  task blog_redirections: :environment do
    puts '=' * 80
    puts 'Creating Blog Redirection Mappings'
    puts '=' * 80
    puts

    processed = 0
    created = 0
    errors = 0

    Blog.find_each do |blog|
      processed += 1
      old_slug = "/#{blog.slug}"
      new_slug = "/tin-tuc/#{blog.slug}"

      mapping = RedirectionMapping.find_or_initialize_by(old_slug: old_slug)
      mapping.new_slug = new_slug
      mapping.active = true

      if mapping.save
        created += 1 if mapping.previously_new_record?
        print '.'
      else
        errors += 1
        puts "\n✗ Error saving mapping for #{blog.slug}: #{mapping.errors.full_messages.join(', ')}"
      end
    end

    puts '\n' + '=' * 80
    puts 'SUMMARY'
    puts '=' * 80
    puts "Total blogs: #{processed}"
    puts "Mappings created: #{created}"
    puts "Errors: #{errors}"
    puts '=' * 80
    puts '✅ Completed!'
  end
end
