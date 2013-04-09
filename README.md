# parse-migrate

Easier migration for your Parse data

## Usage

Export your app info to the environment:

```
export PRODUCTION_API_KEY="abc"
export STAGING_APP_ID="123"
export STAGING_API_KEY="doremi"
export STAGING_MASTER_KEY="youandme"
```

then:

```
load "migrate.rb"

migrate = Migrate.new(["_User", "Location", "Photo"])

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
