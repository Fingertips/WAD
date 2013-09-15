# Utility class to push and fetch Bundler directories to speed up
# test runs on Travis-CI
class Wad
  class Key
    def default_environment_variables
      []
    end

    def default_files
      [ "#{ENV['BUNDLE_GEMFILE']}.lock" ]
    end

    def environment_variables
      if ENV['WAD_ENVIRONMENT_VARIABLES']
        ENV['WAD_ENVIRONMENT_VARIABLES'].split(',')
      else
        default_environment_variables
      end
    end

    def files
      ENV['WAD_FILES'] ? ENV['WAD_FILES'].split(',') : default_files
    end

    def environment_variable_contents
      environment_variables.map { |v| ENV[v] }
    end

    def file_contents
      files.map { |f| File.read(f) rescue nil }
    end

    def contents
      segments = [ RUBY_VERSION, RUBY_PLATFORM ] + environment_variable_contents + file_contents
      Digest::SHA1.hexdigest(segments.join("\n"))
    end
  end

  def initialize
    s3_configure
  end

  def project_root
    Dir.pwd
  end

  def artifact_name
    @artifact_name ||= Key.new.contents
  end

  def bzip_filename
    File.join(project_root, "tmp/#{artifact_name}.tar.bz2")
  end

  def cache_path
    ENV['WAD_CACHE_PATH'] ? ENV['WAD_CACHE_PATH'].split(",") : [ '.bundle' ]
  end

  def s3_bucket_name
    if bucket = ENV['WAD_S3_BUCKET_NAME'] || ENV['S3_BUCKET_NAME']
      bucket
    else
      abort "Must provide WAD_S3_BUCKET_NAME="
    end
  end

  def s3_credentials
    if creds = ENV['WAD_S3_CREDENTIALS'] || ENV['S3_CREDENTIALS']
      creds.split(':')
    end
  end

  def s3_access_key_id
    s3_credentials && s3_credentials[0]
  end

  def s3_secret_access_key
    s3_credentials && s3_credentials[1]
  end

  def s3_path
    "#{artifact_name}.tar.bz2"
  end

  def s3_configure
    Presss.config = {
      :bucket_name => s3_bucket_name,
      :access_key_id => s3_access_key_id,
      :secret_access_key => s3_secret_access_key,
      :region => ENV['WAD_AWS_REGION'],
      :bucket_in_hostname => (ENV['WAD_BUCKET_IN_HOSTNAME'] == 'true')
    }
  end

  def s3_write
    log "Trying to write Wad to S3"
    if Presss.put(s3_path, bzip_filename)
      log "Wrote Wad to S3"
    else
      log "Failed to write to S3, debug with `wad -v'"
    end
  end

  def s3_read
    if File.exist?(bzip_filename)
      log "Removing bundle from filesystem"
      FileUtils.rm_f(bzip_filename)
    end

    log "Trying to fetch Wad from S3"
    FileUtils.mkdir_p(File.dirname(bzip_filename))
    Presss.download(s3_path, bzip_filename)
  end

  def zip
    log "Creating artifact with tar (#{File.basename(bzip_filename)})"
    system("cd #{project_root} && tar -cjf #{bzip_filename} #{cache_path.join(' ')}")
    $?.success?
  end


  def unzip
    log "Unpacking artifact with tar (#{File.basename(bzip_filename)})"
    system("cd #{project_root} && tar -xjf #{bzip_filename}")
    $?.success?
  end

  def put
    zip
    s3_write
  end

  def get
    if s3_read
      unzip
    end
  end

  def default_command
    bundle_without = ENV['WAD_BUNDLE_WITHOUT'] || "development production"
    "bundle install --path .bundle --without='#{bundle_without}'"
  end

  def install
    log "Installing..."
    command = ENV['WAD_INSTALL_COMMAND'] || default_command
    puts command
    system(command)
    $?.success?
  end

  def setup
    if !s3_credentials || !s3_bucket_name
      log "No S3 credentials defined. Set WAD_S3_CREDENTIALS= and WAD_S3_BUCKET_NAME= for caching."
      install
    elsif get
      install
    elsif install
      put
    else
      abort "Failed properly fetch or install. Please review the logs."
    end
  end

  def log(message)
    puts "[wad] #{message}"
  end
end
