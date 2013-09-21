argv = ARGV.dup

if argv.delete('-v')
  require 'logger'
  Presss.logger = Logger.new($stdout)
end

wad = Wad.new

case argv.shift
when "download"
  wad.download
when "upload"
  wad.upload(argv)
else
  wad.setup
end
