require 'singleton'
require 'rest-client'
require 'json/pure'

module Gooddata

  # = GoodData HTTP wrapper
  #
  # Provides a convenient HTTP wrapper for talking with the GoodData API.
  #
  # Remember that the connection is shared amongst the entire application.
  # Therefore you can't be logged in to more than _one_ GoodData account.
  # per session. Simultaneous connections to multiple GoodData accounts is not
  # supported at this time.
  #
  # The GoodData API is a RESTful API that communicates using JSON. This wrapper
  # makes sure that the session is stored between requests and that the JSON is
  # parsed both when sending and receiving.
  #
  # == Usage
  #
  # Since this is a singleton class, it's not possible to create a new instance.
  # Instead you call the instance method on the class:
  #
  #   Gooddata::Connection.instance
  #
  # This will return the current instance.
  #
  # Before a connection can be made to the GoodData API, you have to supply the user
  # credentials using the set_credentials method:
  #
  #   Gooddata::Connection.instance.set_credentials(username, password)
  #
  # To send a HTTP request use either the get, post or delete methods documented below.
  #
  class Connection
    include Singleton

    GOODDATA_SERVER = 'https://secure.gooddata.com'
    LOGIN_PATH = '/gdc/account/login'
    TOKEN_PATH = '/gdc/account/token'

    # Set the GoodData account credentials.
    #
    # This have to be performed before any calls to the API.
    #
    # === Parameters
    #
    # * +username+ - The GoodData account username
    # * +password+ - The GoodData account password
    def set_credentials(username, password)
      @status = :not_connected
      @username = username
      @password = password
    end

    # Returns the user JSON object of the currently logged in GoodData user account.
    def user
      ensure_connection
      @user
    end

    # Performs a HTTP GET request.
    #
    # Retuns the JSON response formatted as a Hash object.
    #
    # === Parameters
    #
    # * +path+ - The HTTP path on the GoodData server (must be prefixed with a forward slash)
    #
    # === Examples
    #
    #   Gooddata::Connection.instance.get '/gdc/projects'
    def get(path)
      Gooddata.logger.debug "GET #{path}"
      ensure_connection
      process_response { @server[path].get cookies }
    end

    # Performs a HTTP GET request.
    #
    # Retuns the JSON response formatted as a Hash object.
    #
    # === Parameters
    #
    # * +path+ - The HTTP path on the GoodData server (must be prefixed with a forward slash)
    # * +data+ - The payload data in the format of a Hash object
    #
    # === Examples
    #
    #   Gooddata::Connection.instance.post '/gdc/projects', { ... }
    def post(path, data)
      json = JSON.generate(data)
      Gooddata.logger.debug "POST #{path}, payload: #{json.inspect}"
      ensure_connection
      process_response { @server[path].post json, cookies }
    end

    # Performs a HTTP DELETE request.
    #
    # Retuns the JSON response formatted as a Hash object.
    #
    # === Parameters
    #
    # * +path+ - The HTTP path on the GoodData server (must be prefixed with a forward slash)
    #
    # === Examples
    #
    #   Gooddata::Connection.instance.delete '/gdc/project/1'
    def delete(path)
      Gooddata.logger.debug "DELETE #{path}"
      ensure_connection
      process_response { @server[path].delete cookies }
    end

    # Get the cookies associated with the current connection.
    def cookies
      @cookies ||= { :cookies => {} }
    end

    # Set the cookies used when communicating with the GoodData API.
    def merge_cookies!(cookies)
      self.cookies
      @cookies[:cookies].merge! cookies
    end

    # Returns true if a connection have been established to the GoodData API
    # and the login was successful.
    def logged_in?
      @status == :logged_in
    end

    # The connection will automatically be established once it's needed, which it
    # usually is when either the user, get, post or delete method is called. If you
    # want to force a connection (or a re-connect) you can use this method.
    def connect!
      connect
    end

    private

    def ensure_connection
      connect if @status == :not_connected
    end

    def connect
      Gooddata.logger.info "Connecting to GoodData..."
      @status = :connecting
      authenticate
    end

    def authenticate
      credentials = {
        'postUserLogin' => {
          'login' => @username,
          'password' => @password,
          'remember' => 1
        }
      }

      @server = RestClient::Resource.new GOODDATA_SERVER, :headers => { 
        :content_type => :json,
        :accept => :json,
        :user_agent => Gooddata::Client.gem_version_string
      }

      Gooddata.logger.debug "Logging in..."
      @user = post(LOGIN_PATH, credentials)['userLogin']

      Gooddata.logger.debug "Getting authentication token..."
      get TOKEN_PATH

      @status = :logged_in
    end

    def process_response
      begin
        response = yield
        merge_cookies! response.cookies
        json = response.to_str == '""' ? {} : JSON.parse(response.to_str)
        Gooddata.logger.debug "Response: #{json.inspect}"
        json
      rescue RestClient::Exception => e
        Gooddata.logger.debug "Response: #{e.response}"
        raise $!
      end
    end
  end
end