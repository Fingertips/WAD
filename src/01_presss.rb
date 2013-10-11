class Presss
  VERSION = '0.10.0'

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
    class RequestError < StandardError; end

    class Response
      attr_accessor :status_code, :headers, :body

      def initialize(status_code, headers, body=nil)
        @status_code, @headers, @body = status_code.to_i, headers, body
      end

      # Returns _true_ when the status code is in the 2XX range. Returns false otherwise.
      def success?
        status_code >= 200 && status_code < 300
      end
    end

    class << self
      attr_accessor :port
    end
    self.port = 443

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

    def host
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

    # Returns the request headers for a date, message and content-type.
    def headers(date, message, content_type=nil)
      headers = {
        'Authorization' => authorization.header(message),
        'Date' => date,
        'User-Agent' => 'Press/0.9'
      }
      headers['Content-Type'] = content_type if content_type
      headers
    end

    # Returns a Net::HTTP instance with the correct SSL configuration for a
    # request.
    def http
      @http ||= begin
        http = Net::HTTP.new(host, self.class.port)
        http.use_ssl = true
        http.ca_file = 'tmp/cacert.pem'
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http
      end
    end

    # Joins a number of parameters for a valid request message used to compute
    # the request signature.
    def join(verb, body, content_type, date, headers, canonizalized_resource_path)
      [
        verb.to_s.upcase,
        nil,
        content_type,
        date,
        # TODO: aws-x headers?
        canonizalized_resource_path
      ].join("\n")
    end

    # Get an object with a key.
    def get(path, &block)
      path = canonicalized_resource(path)
      date = Time.now.rfc2822
      message = join('GET', nil, nil, date, nil, path)
      request = Net::HTTP::Get.new(path, headers(date, message))
      begin
        if block_given?
          http.start do |http|
            http.request(request) do |response|
              response.read_body(&block)
            end
          end
        else
          response = http.start { |http| http.request(request) }
          Presss::HTTP::Response.new(
            response.code,
            response.instance_variable_get('@header'),
            response.body
          )
        end
      rescue EOFError => error
        raise Presss::HTTP::RequestError, error.message
      end
    end

    def content_length(file)
      if file.respond_to?(:size)
        file.size.to_s
      elsif file.respond_to?(:path)
        File.size(file.path).to_s
      end
    end

    # Puts an object with a key using a file or string. Optionally pass in
    # the content-type if you want to set a specific one.
    def put(path, file, content_type=nil)
      path = canonicalized_resource(path)
      body = file.respond_to?(:read) ? file : file.to_s 
      date = Time.now.rfc2822
      message = join('PUT', body, content_type, date, nil, path)
      headers = headers(date, message, content_type)

      if content_length = content_length(file)
        headers.merge!({'Content-Length' => content_length})
      end

      request = Net::HTTP::Put.new(path, headers)

      if file.respond_to?(:read)
        request.body_stream = file
      else
        request.body = body
      end

      begin
        response = http.start { |http| http.request(request) }
        Presss::HTTP::Response.new(
          response.code,
          response.instance_variable_get('@header'),
          response.body
        )
      rescue EOFError => error
        raise Presss::HTTP::RequestError, error.message
      end
    end
  end

  class << self
    attr_accessor :config
    attr_accessor :logger
  end
  self.config = {}

  # Get a object with a certain key.
  def self.get(path, &block)
    request = Presss::HTTP.new(config)
    log("Trying to GET #{path}")

    if block_given?
      request.get(path, &block)
    else
      response = request.get(path)
      if response.success?
        log("Got response: #{response.status_code}")
        response.body
      else
        nil
      end
    end
  end

  # Puts an object with a key using a file or string. Optionally pass in
  # the content-type if you want to set a specific one.
  def self.put(path, file, content_type='application/x-download')
    request = Presss::HTTP.new(config)
    log("Trying to PUT #{path}")
    response = request.put(path, file, content_type)
    log("Got response: #{response.status_code}")
    log(response.body) unless response.success?
    response.success?
  end

  # Logs to the configured logger if a logger was configured.
  def self.log(message)
    if logger
      logger.info('[Presss] ' + message)
    end
  end
end
