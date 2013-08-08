desc "Build the distribution version of the script"
task :default do
  files = FileList['src/**/*'].sort
  File.open('bin/wad', 'w') do |file|

    file.puts("#!/usr/bin/env ruby")
    file.puts
    file.puts("# Generated on: #{Time.now.strftime("%d-%m-%Y")} at #{Time.now.strftime("%H:%M")}")
    file.puts

    files.each do |filename|
      file.write(File.read(filename))
      file.puts
    end
  end
end