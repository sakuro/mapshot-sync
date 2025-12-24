#!/usr/bin/env ruby

require 'erb'
require 'json'
require 'pathname'

if ARGV.empty?
  puts "Specify mapshot output dir"
  exit 1
end

maps_dir = Pathname(ARGV[0])
if !maps_dir.exist?
  puts "#{maps_dir} does not exist"
  exit 1
end

maps = maps_dir.glob("*").map do |map_dir|
  next [] unless map_dir.directory?
  index_path = (map_dir / "index.html").relative_path_from(maps_dir)
  dirs = map_dir.glob("d-*").map do |dir|
    path = dir.basename.to_s
    metadata = JSON.parse((dir / "mapshot.json").read, symbolize_names: true)
    tick = metadata[:tick]
    days, _ = metadata[:tick].divmod(25000)
    {path:, days:, tick:}
  end.sort_by {|e| e[:tick] }.reverse
  {index_path:, dirs:}
end

template = DATA.read
erb = ERB.new(template, trim_mode: "-")
erb.run

__END__
<!doctype html>
<html>
  <body>
    <ul>
      <%- maps.each do |map| -%>
      <li>
        <a href="<%= map[:index_path] %>"><%= map[:index_path].dirname %></a>
        <ul>
          <%- map[:dirs].each do |dir| -%>
          <li><a href="<%= map[:index_path] %>?path=<%= dir[:path] %>"><%= dir[:days] %> days</a></li>
          <%- end -%>
        </ul>
      </li>
      <%- end -%>
    </ul>
  </body>
</html>
