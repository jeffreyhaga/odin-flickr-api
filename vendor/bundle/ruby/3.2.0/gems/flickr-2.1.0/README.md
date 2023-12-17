# Flickr

Flickr (formerly FlickRaw) is a library to access the [Flickr](https://flickr.com) API in a simple way.
It maps exactly the methods described in [the official API documentation](https://www.flickr.com/services/api/).
It also tries to present the data returned in a simple and intuitive way.
The methods are fetched from Flickr when loading the library by using introspection capabilities.
So it is always up-to-date with regards to new methods added by Flickr.

The github repository: https://github.com/cyclotron3k/flickr

# Upgrading from FlickRaw?

If you're upgrading from FlickRaw 0.9.x there are a few breaking changes to be aware of:
*   Instantiate a new object with `client = Flickr.new` instead of `FlickRaw::Flickr.new`.
*   The global `flickr` variable is no longer created.
*   Local caching of the Flickr API specification is no longer achieved with a separate gem.


# Installation
Type this in a console (you might need to be superuser)

    gem install flickr

This will recreate the documentation by fetching the method descriptions from Flickr and then virtually plugging them in standard rdoc documentation.

    $ cd flickr
    $ rake rdoc

# Features

*   Minimal dependencies
*   Complete support of Flickr API. This doesn't require an update of the library
*   Ruby syntax similar to the Flickr API
*   Flickr authentication
*   HTTPS Support
*   Photo upload
*   Proxy support
*   Flickr URLs helpers


# Usage

## Getting started

To use the Flickr API, you must first obtain an API key and shared secret from Flickr.
You can do this by logging in to Flickr and creating an application [here](https://www.flickr.com/services/apps/create/apply).
API keys are usually granted automatically and instantly.

```ruby
require 'flickr'

# The credentials can be provided as parameters:

flickr = Flickr.new "YOUR API KEY", "YOUR SHARED SECRET"

# Alternatively, if the API key and Shared Secret are not provided, Flickr will attempt to read them
# from environment variables:
# ENV['FLICKR_API_KEY']
# ENV['FLICKR_SHARED_SECRET']

flickr = Flickr.new

# Flickr will raise an error if either parameter is not explicitly provided, or available via environment variables.
```

## Simple

```ruby
list   = flickr.photos.getRecent

id     = list[0].id
secret = list[0].secret
info   = flickr.photos.getInfo :photo_id => id, :secret => secret

puts info.title           # => "PICT986"
puts info.dates.taken     # => "2006-07-06 15:16:18"

sizes = flickr.photos.getSizes :photo_id => id

original = sizes.find { |s| s.label == 'Original' }
puts original.width       # => "800" -- may fail if they have no original marked image
```

## Authentication

```ruby
token = flickr.get_request_token
auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => 'delete')

puts "Open this url in your browser to complete the authentication process: #{auth_url}"
puts "Copy here the number given when you complete the process."
verify = gets.strip

begin
  flickr.get_access_token(token['oauth_token'], token['oauth_token_secret'], verify)
  login = flickr.test.login
  puts "You are now authenticated as #{login.username} with token #{flickr.access_token} and secret #{flickr.access_secret}"
rescue Flickr::FailedResponse => e
  puts "Authentication failed : #{e.msg}"
end
```

If the user has already been authenticated, you can reuse the access token and access secret:

```ruby
flickr.access_token = "... Your access token ..."
flickr.access_secret = "... Your access secret ..."

# From here you are logged:
login = flickr.test.login
puts "You are now authenticated as #{login.username}"
```

If you need to have several users authenticated at the same time in your application (ex: a public web application) you need to create separate Flickr objects since it keeps the authentication data internally.

```ruby
flickr = Flickr.new
```

## Upload

```ruby
PHOTO_PATH = 'photo.jpg'

# You need to be authenticated to do that, see the previous examples.
flickr.upload_photo PHOTO_PATH, :title => "Title", :description => "This is the description"
```

## Caching

The first time the Flickr object is instantiated, it will download the current Flickr API definition and dynamically create all the required classes and
objects.
This is how the gem remains up-to-date without requiring updates.

Unfortunately this adds a significant delay to startup, but the Flickr gem can be configured to cache the API definition to a local file.
Just set a file location before the Flickr class is instantiated:

```ruby
Flickr.cache = '/tmp/flickr-api.yml'
flickr = Flickr.new
```

## Proxy

```ruby
require 'flickr'
Flickr.proxy = "https://user:pass@proxy.example.com:3129/"
```

### Server Certificate Verification

Server certificate verification is enabled by default. If you don't want to check the server certificate:

```ruby
require 'flickr'
Flickr.check_certificate = false
```

### CA Certificate File Path

`OpenSSL::X509::DEFAULT_CERT_FILE` is used as a CA certificate file. If you want to change the path:

```ruby
require 'flickr'
Flickr.ca_file = '/path/to/cacert.pem'
```

You can also specify a path to a directory with a number of certifications:

```ruby
Flickr.ca_path = '/path/to/certificates'
```

## Flickr URL Helpers

There are some helpers to build Flickr urls:

### url, url_m, url_s, url_t, url_b, url_z, url_q, url_n, url_c, url_o

```ruby
# url_s : Square
# url_q : Large Square
# url_t : Thumbnail
# url_m : Small
# url_n : Small 320
# url   : Medium
# url_z : Medium 640
# url_c : Medium 800
# url_b : Large
# url_o : Original

info = flickr.photos.getInfo(:photo_id => "3839885270")
Flickr.url_b(info) # => "https://farm3.static.flickr.com/2485/3839885270_6fb8b54e06_b.jpg"
```

### url_profile

```ruby
info = flickr.photos.getInfo(:photo_id => "3839885270")
Flickr.url_profile(info) # => "https://www.flickr.com/people/41650587@N02/"
```

### url_photopage

```ruby
info = flickr.photos.getInfo(:photo_id => "3839885270")
Flickr.url_photopage(info) # => "https://www.flickr.com/photos/41650587@N02/3839885270"
```

### url_photoset, url_photosets

```ruby
info = flickr.photos.getInfo(:photo_id => "3839885270")
Flickr.url_photosets(info) # => "https://www.flickr.com/photos/41650587@N02/sets/"
```

### url_short, url_short_m, url_short_s, url_short_t

```ruby
info = flickr.photos.getInfo(:photo_id => "3839885270")
Flickr.url_short(info) # => "https://flic.kr/p/6Rjq7s"
```

### url_photostream

```ruby
info = flickr.photos.getInfo(:photo_id => "3839885270")
Flickr.url_photostream(info) # => "https://www.flickr.com/photos/41650587@N02/"
```

## Examples

See the *examples* directory to find more examples.
