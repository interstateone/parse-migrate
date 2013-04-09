require "parse-ruby-client"
require "logger"
require "yaml"

module Migrate
  class Migrator
    attr_accessor :file_types
    attr_accessor :user_block

    @@logger = Logger.new STDOUT
    @@logger.formatter = proc do |severity, datetime, progname, msg|
      "#{msg}\n"
    end

    def initialize(classes)
      return if classes.empty? or !classes.is_a? Array
      @classes = classes

      # Load the config
      @config = {
        PRODUCTION_APP_ID: ENV['PRODUCTION_APP_ID'],
        PRODUCTION_API_KEY: ENV['PRODUCTION_API_KEY'],
        STAGING_APP_ID: ENV['STAGING_APP_ID'],
        STAGING_MASTER_KEY: ENV['STAGING_MASTER_KEY']
      }
      if @config.any?{|v| v.nil? || v.length == 0}
        @@logger.fatal("Please check your app keys")
        Kernel.exit
      end

      # Relates class names to field names for relationships in other classes
      # If you don't follow this naming convention, this won't work
      # @class_keys = {"_User" => "user", etc.}
      @class_keys = Hash[@classes.collect { |c| [c, c.gsub(/[^0-9A-Za-z]/, '').downcase] }]

      # Tracks old/new object ids for updating the new app
      # old Parse::Object.parse_object_id => new Parse::Object.pointer
      @pointers = Hash[@class_keys.collect { |k, v| [v, {}] }]
    end

    def migrate(class_name, &each_block)

      @@logger.info "\nOverwriting #{class_name} in staging"

      each_block ||= Proc.new do |object, index|
        data = object.safe_hash
        data.each do |key, value|
          if value.kind_of? Parse::File
            api_base = Parse.client.session.base_url
            Parse.client.session.base_url = ""
            response = Parse.client.session.request(:get, value.url, {})
            body = response.body
            Parse.client.session.base_url = api_base
            file_data = {
              local_filename: class_name.downcase,
              body: body
            }
            content_type = @file_types[@class_keys[class_name]]
            content_type ||= response.headers["Content-Type"]
            if !content_type.empty?
              file_data[:content_type] = content_type
            end
            new_file = Parse::File.new file_data
            new_file.save
            data[key] = new_file
          end
        end
        new_object = Parse::Object.new class_name, data
        # If a pointer to another object is present, update it to its new object id
        @pointers.each do |key, hash|
          next if !object.has_key?(key) or !object[key].kind_of?(Parse::Pointer)
          if !hash[object[key].parse_object_id].nil?
            new_object[key] = hash[object[key].parse_object_id]
          end
        end
        new_object
      end

      Parse.init application_id: @config[:PRODUCTION_APP_ID], api_key: @config[:PRODUCTION_API_KEY]

      @@logger.info "--> Getting production objects from Parse app ID: #{Parse.client.application_id}"
      production_count = get_object_count(class_name)
      production_objects = get_all_objects(class_name, production_count)
      @@logger.info "--> Received #{production_count} production objects"

      # Switch to staging
      Parse.init application_id: @config[:STAGING_APP_ID], master_key: @config[:STAGING_MASTER_KEY]
      @@logger.info "--> Getting staging objects from Parse app ID: #{Parse.client.application_id}"
      staging_count = get_object_count(class_name)
      staging_objects = get_all_objects(class_name, staging_count)

      # Delete existing staging objects
      delete_with_batch(staging_objects)
      @@logger.info "--> Deleted #{staging_count} existing objects from staging"

      # Duplicate objects to create new Parse IDs
      new_objects = []
      production_objects.each_slice(50) do |object_slice|
        create_batch = Parse::Batch.new
        object_slice.each_with_index do |object, index|
          create_batch.create_object(instance_exec(object, index, &each_block))
        end
        new_objects << create_batch.run!
      end
      new_objects.flatten!(1)

      # Don't do this for users since we aren't creating them with batch commands
      if @class_keys.has_key?(class_name) and class_name != "_User"
        track_pointers(production_objects, new_objects)
      end

      @@logger.info "--> Inserted #{production_count} new staging objects"
    end

    def get_object_count(class_name)
      query = Parse::Query.new(class_name).count
      query.limit = 0
      query.get["count"]
    end

    # Note that in this case "all" means "up to 11 000"
    # Parse will allow you to fetch 1000 objects per batch request, with a maximum
    # "skip" pagination offset of 10 000
    def get_all_objects(class_name, count)
      per_page = 1000
      objects = []
      times = [(count/per_page.to_f).ceil, 10].min
      0.upto(times) do |offset|
        query = Parse::Query.new(class_name)
        query.limit = per_page
        query.skip = offset * per_page
        objects << query.get
      end
      objects.flatten(1)
    end

    def delete_with_batch(collection)
      collection.each_slice(50) do |object_slice|
        delete_batch = Parse::Batch.new
        object_slice.each do |object|
            delete_batch.delete_object object
        end
        delete_batch.run!
      end
    end

    # Relates new and old object ids from batch collections
    def track_pointers(old_objects, new_objects)
      old_objects.each_with_index do |old_object, index|
        next if new_objects[index].has_key?("error")
        new_pointer = Parse::Pointer.new({
          Parse::Protocol::KEY_CLASS_NAME => old_object.class_name,
          Parse::Protocol::KEY_OBJECT_ID => new_objects[index]["success"][Parse::Protocol::KEY_OBJECT_ID]
        })
        @pointers[@class_keys[old_object.class_name]][old_object.parse_object_id] = new_pointer
      end
    end

    def run
      @classes.each do |class_name|
        # API doesn't allow fetching Installation classes
        next if class_name == "_Installation"
        if class_name == "_User"
          migrate(class_name, &@user_block)
        else
          migrate(class_name)
        end
      end
    end
  end
end
