class StaticPagesController < ApplicationController

def index
  # Use Rails credentials to securely fetch your API key and secret
  flickr_api_key = Rails.application.credentials.flickr[:api_key]
  flickr_shared_secret = Rails.application.credentials.flickr[:secret_key]

  # Initialize your Flickr client with the credentials
  flickr = Flickr.new(flickr_api_key, flickr_shared_secret)

  user_id = params[:user_id]

  @photos = flickr.people.getPhotos(user_id: user_id)

end



end
