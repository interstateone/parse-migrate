require "parse-migrate"

# List classes in order of relationship dependencies
# Parse doesn't provide an endpoint for class lists, so no cheating
migrate = Migrate::Migrator.new(["_User", "Location", "Photo"])

# Parse/S3 may not provide explicit MIME types when fetching
# Provide the proper MIME type for the relationship field name
migrate.file_types = {
  "avatar" => "image/jpeg"
}

# Users require special care and attention
# Pick an email you have control over, not a "fake" email that someone could potentially use
# You must call Parse::Object.save and update pointers since users aren't created in batch
migrate.user_block = Proc.new do |old_object, index|
  data = old_object.safe_hash
  data[:email] = "your.email+staging#{Random.rand(100)}@gmail.com"
  data[:password] = "staging"

  new_object = Parse::User.new data
  new_object.save

  id = old_object.parse_object_id
  @pointers[@class_keys[old_object.class_name]][id] = new_object.pointer
  new_object
end

begin
  migrate.run
rescue SystemExit
end

Kernel.exit
