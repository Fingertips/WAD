if ARGV.index('-v')
  require 'logger'
  Presss.logger = Logger.new($stdout)
end

Wad.setup