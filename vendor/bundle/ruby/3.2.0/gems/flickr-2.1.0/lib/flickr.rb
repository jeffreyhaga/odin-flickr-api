require 'json'
require 'yaml'
require 'flickr/version'
require 'flickr/util'
require 'flickr/errors'
require 'flickr/oauth_client'
require 'flickr/request'
require 'flickr/response'
require 'flickr/response_list'

class Flickr

  USER_AGENT                 = "Flickr/#{VERSION} (+https://github.com/cyclotron3k/flickr)".freeze
  END_POINT                  = 'https://api.flickr.com/services'.freeze
  UPLOAD_END_POINT           = 'https://up.flickr.com/services'.freeze
  FLICKR_OAUTH_REQUEST_TOKEN = (END_POINT + '/oauth/request_token').freeze
  FLICKR_OAUTH_AUTHORIZE     = (END_POINT + '/oauth/authorize').freeze
  FLICKR_OAUTH_ACCESS_TOKEN  = (END_POINT + '/oauth/access_token').freeze
  REST_PATH                  = (END_POINT + '/rest/').freeze
  UPLOAD_PATH                = (UPLOAD_END_POINT + '/upload/').freeze
  REPLACE_PATH               = (UPLOAD_END_POINT + '/replace/').freeze
  PHOTO_SOURCE_URL           = 'https://farm%s.staticflickr.com/%s/%s_%s%s.%s'.freeze
  URL_PROFILE                = 'https://www.flickr.com/people/'.freeze
  URL_PHOTOSTREAM            = 'https://www.flickr.com/photos/'.freeze
  URL_SHORT                  = 'https://flic.kr/p/'.freeze

  # Authenticated access token
  attr_accessor :access_token

  # Authenticated access token secret
  attr_accessor :access_secret

  attr_reader :client

  @@initialized = false
  @@mutex = Mutex.new

  def initialize(api_key = ENV['FLICKR_API_KEY'], shared_secret = ENV['FLICKR_SHARED_SECRET'])

    raise FlickrAppNotConfigured.new("No API key defined!") if api_key.nil?
    raise FlickrAppNotConfigured.new("No shared secret defined!") if shared_secret.nil?

    @access_token = @access_secret = nil
    @oauth_consumer = oauth_consumer api_key, shared_secret

    @@mutex.synchronize do
      unless @@initialized
        build_classes retrieve_endpoints
        @@initialized = true
      end
    end
    @client = self # used for propagating the client to sub-classes
  end

  # This is the central method. It does the actual request to the Flickr server.
  #
  # Raises FailedResponse if the response status is _failed_.
  def call(req, args = {}, &block)
    oauth_args = args.delete(:oauth) || {}
    http_response = @oauth_consumer.post_form(REST_PATH, @access_secret, {:oauth_token => @access_token}.merge(oauth_args), build_args(args, req))
    process_response(req, http_response.body)
  end

  # Get an oauth request token.
  #
  #    token = flickr.get_request_token(:oauth_callback => "https://example.com")
  def get_request_token(args = {})
    @oauth_consumer.request_token(FLICKR_OAUTH_REQUEST_TOKEN, args)
  end

  # Get the oauth authorize url.
  #
  #  auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => 'delete')
  def get_authorize_url(token, args = {})
    @oauth_consumer.authorize_url(FLICKR_OAUTH_AUTHORIZE, args.merge(:oauth_token => token))
  end

  # Get an oauth access token.
  #
  #  flickr.get_access_token(token['oauth_token'], token['oauth_token_secret'], oauth_verifier)
  def get_access_token(token, secret, verify)
    access_token = @oauth_consumer.access_token(FLICKR_OAUTH_ACCESS_TOKEN, secret, :oauth_token => token, :oauth_verifier => verify)
    @access_token, @access_secret = access_token['oauth_token'], access_token['oauth_token_secret']
    access_token
  end

  # Use this to upload the photo in _file_.
  #
  #  flickr.upload_photo '/path/to/the/photo', :title => 'Title', :description => 'This is the description'
  #
  # See https://www.flickr.com/services/api/upload.api.html for more information on the arguments.
  def upload_photo(file, args = {})
    upload_flickr(UPLOAD_PATH, file, args)
  end

  # Use this to replace the photo with :photo_id with the photo in _file_.
  #
  #  flickr.replace_photo '/path/to/the/photo', :photo_id => id
  #
  # See https://www.flickr.com/services/api/replace.api.html for more information on the arguments.
  def replace_photo(file, args = {})
    upload_flickr(REPLACE_PATH, file, args)
  end

  private

  def retrieve_endpoints
    if Flickr.cache and File.exist?(Flickr.cache)
      YAML.load_file Flickr.cache
    else
      endpoints = call('flickr.reflection.getMethods').to_a
      File.open(Flickr.cache, 'w') do |file|
        file.write(YAML.dump endpoints)
      end if Flickr.cache
      endpoints
    end
  end

  def oauth_consumer(api_key, shared_secret)
    client = OAuthClient.new api_key, shared_secret
    client.proxy = Flickr.proxy
    client.check_certificate = Flickr.check_certificate
    client.ca_file = Flickr.ca_file
    client.ca_path = Flickr.ca_path
    client.user_agent = USER_AGENT
    client
  end

  def build_classes(endpoints)

    endpoints.sort.each do |endpoint|

      *breadcrumbs, tail = endpoint.split '.'

      raise "Invalid namespace" unless 'flickr' == breadcrumbs.shift

      base_class = breadcrumbs.reduce(::Flickr) do |memo, klass|

        cklass = klass.capitalize

        if memo.const_defined? cklass, false
          memo.const_get cklass
        else
          new_class = Class.new { include ::Flickr::Request }
          memo.const_set cklass, new_class
          memo.send(:define_method, klass) do
            new_class.new @client
          end
          new_class
        end
      end

      base_class.send(:define_method, tail) do |*args, &block|
        @client.call(endpoint, *args, &block)
      end unless base_class.method_defined? tail

    end

  end

  def build_args(args = {}, method_name = nil)
    args['method'] = method_name if method_name
    args.merge('format' => 'json', 'nojsoncallback' => '1')
  end

  def process_response(req, response)
    puts response.inspect if ENV['FLICKR_DEBUG']

    if /\A<\?xml / === response # upload_photo returns xml data whatever we ask
      if response[/stat="(\w+)"/, 1] == 'fail'
        msg = response[/msg="([^"]+)"/, 1]
        code = response[/code="([^"]+)"/, 1]
        raise FailedResponse.new(msg, code, req)
      end

      type = response[/<(\w+)/, 1]
      h = {
        'secret'         => response[/secret="([^"]+)"/, 1],
        'originalsecret' => response[/originalsecret="([^"]+)"/, 1],
        '_content'       => response[/>([^<]+)<\//, 1]
      }.delete_if { |_, v| v.nil? }

      Response.build h, type
    else
      json = JSON.load(response.empty? ? '{}' : response)
      raise FailedResponse.new(json['message'], json['code'], req) if json.delete('stat') == 'fail'
      type, json = json.to_a.first if json.size == 1 and json.values.all? { |x| Hash === x }

      Response.build json, type
    end
  end

  def upload_flickr(method, file, args = {})
    oauth_args = args.delete(:oauth) || {}
    args = build_args(args)
    if file.respond_to? :read
      args['photo'] = file
    else
      args['photo'] = open(file, 'rb')
      close_after = true
    end

    http_response = @oauth_consumer.post_multipart(method, @access_secret, {:oauth_token => @access_token}.merge(oauth_args), args)
    args['photo'].close if close_after
    process_response(method, http_response.body)
  end

  class << self
    # Your flickr API key, see https://www.flickr.com/services/api/keys for more information
    attr_accessor :api_key

    # The shared secret of _api_key_, see https://www.flickr.com/services/api/keys for more information
    attr_accessor :shared_secret

    # Use a proxy
    attr_accessor :proxy

    # Use ssl connection
    attr_accessor :secure

    # Check the server certificate (ssl connection only)
    attr_accessor :check_certificate

    # Set path of a CA certificate file in PEM format (ssl connection only)
    attr_accessor :ca_file

    # Set path to a directory of CA certificate files in PEM format (ssl connection only)
    attr_accessor :ca_path

    # Set path to a file that can be used to store endpoints
    attr_accessor :cache

    BASE58_ALPHABET = '123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ'.freeze

    def base58(id)
      id = id.to_i
      alphabet = BASE58_ALPHABET.split(//)
      base = alphabet.length
      begin
        id, m = id.divmod(base)
        r = alphabet[m] + (r || '')
      end while id > 0
      r
    end

    def gen_url(r, type)
      PHOTO_SOURCE_URL % [r.farm, r.server, r.id, r.secret, type, 'jpg']
    end

    def url(r); gen_url(r, '') end

    %W{m s t b z q n c h k}.each do |chr|
      define_method "url_#{chr}" do |r|
        gen_url r, "_#{chr}"
      end
    end

    def url_o(r); PHOTO_SOURCE_URL % [r.farm, r.server, r.id, r.originalsecret, '_o', r.originalformat] end
    def url_profile(r); URL_PROFILE + (r.owner.respond_to?(:nsid) ? r.owner.nsid : r.owner) + '/' end
    def url_photopage(r); url_photostream(r) + r.id end
    def url_photosets(r); url_photostream(r) + 'sets/' end
    def url_photoset(r); url_photosets(r) + r.id end
    def url_short(r); URL_SHORT + base58(r.id) end
    def url_short_m(r); URL_SHORT + 'img/' + base58(r.id) + '_m.jpg' end
    def url_short_s(r); URL_SHORT + 'img/' + base58(r.id) + '.jpg'   end
    def url_short_t(r); URL_SHORT + 'img/' + base58(r.id) + '_t.jpg' end
    def url_short_q(r); URL_SHORT + 'img/' + base58(r.id) + '_q.jpg' end
    def url_short_n(r); URL_SHORT + 'img/' + base58(r.id) + '_n.jpg' end
    def url_photostream(r)
      URL_PHOTOSTREAM +
        if r.respond_to?(:pathalias) && r.pathalias
          r.pathalias
        elsif r.owner.respond_to?(:nsid)
          r.owner.nsid
        else
          r.owner
        end + '/'
    end
  end

  self.check_certificate = true

end
