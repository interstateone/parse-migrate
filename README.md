# parse-migrate

Easier migration for your Parse.com data

[![Code Climate](https://codeclimate.com/github/interstateone/parse-migrate.png)](https://codeclimate.com/github/interstateone/parse-migrate) [![Dependency Status](https://gemnasium.com/interstateone/parse-migrate.png)](https://gemnasium.com/interstateone/parse-migrate)

Note: There is currently a limit of 11 000 objects of a single class that can be migrated between apps. This is due to an API limitation when batch retrieving objects of 1000 objects per page, and 11 pages.

## Usage

Export your app info to the environment:

```
export PRODUCTION_APP_ID="abc"
export PRODUCTION_API_KEY="123"
export STAGING_APP_ID="doremi"
export STAGING_MASTER_KEY="youandme"
```

then:

```
require "parse-migrate"

migrate = Migrate::Migrator.new(["_User", "Location", "Photo"])

migrate.file_types = {
  "photo" => "image/jpeg"
}

migrate.user_block = Proc.new do |old_object, index|
  data = old_object.safe_hash
  data[:email] = "your.email+staging#{Random.rand(100)}@gmail.com"
  data[:password] = "staging"

  new_object = Parse::User.new(data)
  new_object.save

  id = old_object.parse_object_id
  @pointers[@class_keys[old_object.class_name]][id] = new_object.pointer

  new_object
end

migrate.run
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
