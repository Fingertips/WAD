class Presss
  # Computes the Authorization header for a AWS request based on a message,
  # the access key ID and secret access key.
  class Authorization
    attr_accessor :access_key_id, :secret_access_key

    def initialize(access_key_id, secret_access_key)
      @access_key_id, @secret_access_key = access_key_id, secret_access_key
    end

    # Returns the value for the Authorization header for a message contents.
    def header(string)
      'AWS ' + access_key_id + ':' + sign(string)
    end

    # Returns a signature for a AWS request message.
    def sign(string)
      Base64.encode64(hmac_sha1(string)).strip
    end

    def hmac_sha1(string)
      OpenSSL::HMAC.digest('sha1', secret_access_key, string)
    end
  end

  class HTTP
    attr_accessor :config

    def initialize(config)
      @config = config
    end

    # Returns the configured bucket name.
    def bucket_name
      config[:bucket_name]
    end

    def region
      config[:region] || 'us-east-1'
    end

    def domain
      case region
      when 'us-east-1'
        's3.amazonaws.com'
      else
        's3-%s.amazonaws.com' % region
      end
    end

    # Returns the absolute path based on the key for the object.
    def absolute_path(path)
      path.start_with?('/') ? path : '/' + path
    end

    # Returns the canonicalized resource used in the authorization
    # signature for an absolute path to an object.
    def canonicalized_resource(path)
      if bucket_name.nil?
        raise ArgumentError, "Please configure a bucket_name: Presss.config = { bucket_name: 'my-bucket-name }"
      else
        '/' + bucket_name + absolute_path(path)
      end
    end

    # Returns a Presss::Authorization instance for the configured
    # AWS credentials.
    def authorization
      @authorization ||= Presss::Authorization.new(
        config[:access_key_id],
        config[:secret_access_key]
      )
    end

    def signature(verb, expires, path)

    end

    def signed_url(verb, expires, path)
      path = canonicalized_resource(path)
      signature = [ verb.to_s.upcase, nil, nil, expires, path ].join("\n")
      signed = authorization.sign(signature)
      "https://#{domain}#{path}?Signature=#{signed}&Expires=#{expires}&AWSAccessKeyId=#{authorization.access_key_id}"
    end

    def download(path, destination)
      url = signed_url(:get, Time.now.to_i + 600, path)
      Presss.log "path=#{path} signed_url=#{url}"
      system 'curl', '-f', '-o', destination, url
      $?.success?
    end

    # Puts an object with a key using a file or string. Optionally pass in
    # the content-type if you want to set a specific one.
    def put(path, file)
      url = signed_url(:put, Time.now.to_i + 600, path)
      system 'curl', '-f', '-T', file, url
      $?.success?
    end
  end

  class << self
    attr_accessor :config
    attr_accessor :logger
  end
  self.config = {}

  # Get a object with a certain key.
  def self.download(path, destination)
    t0 = Time.now
    request = Presss::HTTP.new(config)
    log("Trying to GET #{path}")
    if request.download(path, destination)
      log("Downloaded in #{(Time.now - t0).to_i} seconds")
      true
    else
      nil
    end
  end

  # Puts an object with a key using a file or string. Optionally pass in
  # the content-type if you want to set a specific one.
  def self.put(path, filename, content_type='application/x-download')
    request = Presss::HTTP.new(config)
    log("Trying to PUT #{path}")
    request.put(path, filename)
  end

  # Logs to the configured logger if a logger was configured.
  def self.log(message)
    if logger
      logger.info('[Presss] ' + message)
    end
  end
end
