if Rails.application.credentials.dig(:flickr)
  flickr_api_key = Rails.application.credentials.dig(:flickr, :api_key)
  flickr_shared_secret = Rails.application.credentials.dig(:flickr, :secret_key)
end
