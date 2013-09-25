# Utility class to push and fetch Bundler directories to speed up
# test runs on Travis-CI
class Wad
  def initialize
    write_cacert
    s3_configure
  end

  def project_root
    Dir.pwd
  end

  def cacert_filename
    File.join(project_root, 'tmp/cacert.pem')
  end

  def write_cacert
    FileUtils.mkdir_p(File.dirname(cacert_filename))
    File.open(cacert_filename, 'wb') do |file|
      file.write(DATA.read)
    end
  end

  def gemfile_lock
    File.join(project_root, 'Gemfile.lock')
  end

  def bundle_name_parts
    [
      File.read(gemfile_lock),
      RUBY_VERSION,
      RUBY_PLATFORM
    ]
  end

  def bundle_name
    Digest::MD5.hexdigest(bundle_name_parts.join)
  end

  def bzip_filename
    File.join(project_root, "tmp/#{bundle_name}.tar.bz2")
  end

  def bundler_path
    '.bundle'
  end

  def s3_bucket_name
    ENV['S3_BUCKET_NAME']
  end

  def s3_credentials
    ENV['S3_CREDENTIALS'].split(':')
  end

  def s3_access_key_id
    s3_credentials[0]
  end

  def s3_secret_access_key
    s3_credentials[1]
  end

  def s3_path
    "#{bundle_name}.tar.bz2"
  end

  def s3_configure
    Presss.config = {
      :bucket_name => s3_bucket_name,
      :access_key_id => s3_access_key_id,
      :secret_access_key => s3_secret_access_key
    }
  end

  def s3_region
    'eu-west-1'
  end

  def s3_write
    log "Trying to write Wad to S3"
    if Presss.put(s3_path, open(bzip_filename))
      log "Wrote Wad to S3"
    else
      log "Failed to write to S3, debug with `wad -h'"
    end
  end

  def s3_read
    if File.exist?(bzip_filename)
      log "Removing bundle from filesystem"
      FileUtils.rm_f(bzip_filename)
    end

    log "Trying to fetch Wad from S3"
    FileUtils.mkdir_p(File.dirname(bzip_filename))
    if bzip = Presss.get(s3_path)
      File.open(bzip_filename, 'wb') do |file|
        file.write(bzip)
      end
      true
    else
      false
    end
  end

  def zip
    log "Creating Wad with tar (#{bzip_filename})"
    system("cd #{project_root} && tar -cjf #{bzip_filename} #{bundler_path}")
  end


  def unzip
    log "Unpacking Wad with tar (#{bzip_filename})"
    system("cd #{project_root} && tar -xjf #{bzip_filename}")
  end

  def put
    zip
    s3_write
  end

  def get
    if s3_read
      unzip
      true
    else
      false
    end
  end

  def install_bundle(opts = {})
    log "Installing bundle"
    cmd = "bundle install --path .bundle --without='development production'"
    cmd = "travis_retry #{cmd}" if opts.fetch(:retry, true)
    system(cmd)
  end

  def setup
    if get
      install_bundle(:retry => false)
    elsif install_bundle(:retry => true)
      put
    else
      raise "Failed properly fetch or install bundle. Please review the logs."
    end
  end

  def log(message)
    puts "[wad] #{message}"
  end

  def self.setup
    new.setup
  end
end
