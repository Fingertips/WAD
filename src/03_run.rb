if ARGV.index('-v')
  require 'logger'
  Presss.logger = Logger.new($stdout)
end

if ARGV.index('-t')
  Wad.test
else
  Wad.setup
end
