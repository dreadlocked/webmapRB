#!/usr/bin/env ruby
require 'curb'
require 'colorize'
require 'nokogiri'
require 'terminal-table'
require 'netaddr' # netaddr -v 1.5.1
require 'csv'
require 'optparse'

# Program options.
USER_AGENT = "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:67.0) Gecko/20100101 Firefox/67.0"

# Default ports to map
$HTTP_PORTS = [80,3000,3128,8000,8001,8080,8081,8081,8083,8084,8085,8086,8087,8088,8089,8888]
$HTTPS_PORTS = [443,4443,8443]

####

$options = {}
$options[:csv] = false
$options[:fast] = false
$options[:threads] = 30 # Tweak this number for optimized performance.
$options[:timeout] = 6 # Decreasing this number could increase performance but skip some slow websites.

OptionParser.new do |opts|
  opts.banner = "Usage: webmap.rb -f example.ranges [options]"

  opts.on("-f FILE_NAME",
    "Specifies the file name with domains and IPs deparated by new line.") do |f|
    $options[:file] = f
  end

  opts.on("--csv", "Extract all the information on CSV files.") do
    $options[:csv] = true
  end

  opts.on("--fast", "Scans just 80, 443 and 8080 ports") do
    $options[:fast] = true
  end

  opts.on("--threads INT", "Number of threads (Default: 30)") do  |t|
    $options[:threads] = t
  end

  opts.on("-t", "--timeout INT", "Seconds for timeout (Default: 6)") do  |to|
    $options[:timeout] = to
  end

  opts.on("-v", "A bit of verbosity") do
    $options[:verbose] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if $options[:fast] then 
  $HTTP_PORTS = [80,8080]
  $HTTPS_PORTS = [443]
end

$res = [] # Stores an array with responses.

class Requester
  def initialize(schema,url,port)
    @schema = schema
    @url = url
    @port = port
    @response = Hash.new()
    run
  end

  def run()
    begin
      base_url = "#{@schema}://" + @url.strip + ":#{@port}/"
      
      print "[*] Testing #{base_url}                                                     \r"
      
      c = Curl::Easy.new(base_url) do |curl|
        curl.headers["User-Agent"] = USER_AGENT
        curl.headers["X-Forwarded-For"] = "127.0.0.1" # Just in case.
        curl.headers["X-Real-IP"] = "127.0.0.1"       # Just in case (2).
      end

      c.ssl_verify_peer = false
      c.ssl_verify_host = false
      c.timeout = $options[:timeout]
      c.follow_location = false
      c.perform

      # Shit done just to be able to pick response headers by name.
      http_response, *http_headers = c.header_str.split(/[\r\n]+/).map(&:strip)
      http_headers = Hash[http_headers.flat_map{ |s| s.scan(/^(\S+): (.+)/) }]

      @response = {
        "body" => c.body_str,
        "headers" => http_headers,
        "length" => c.body_str.length,
        "base_url" => base_url,
        "code" => c.response_code
      }

      noko = Nokogiri::HTML(@response['body'])

      str = "#{@schema}://#{@url}:#{@port} - #{@response['code']}"

      # Tries to look for a symbolic title or a title itself.
      title = noko.css("title").text
      if title == "" then
        title = noko.css("h1").text
        if title == "" then
          title = noko.css("h2").text
        end
      end

      if title != '' then
        # Delete new lines and strip the title.
        title = title.gsub("\n","").strip()

        # Truncate large titles
        if title.length > 45 then
          title = title[0..45].gsub(/\s\w+\s*$/, '...')
        end

        @response['title'] = title

        str += " - Title: #{@response['title']}"
      end

      case c.response_code
      when 200 
        puts str.green
      when 403,401,404,400,500,502
        puts str.yellow
      when 302,301
        location = http_headers["Location"]
        puts str.blue + " -> #{location}"

        # Truncate large Locations
        if location.length > 45 then
          location = location[0..45] + "... "
        end

        @response['title'] = "Redir -> #{location}"
      else
        puts str
      end
      $res << @response
    rescue Exception => e
      #puts "Failed to retrieve at #{@url}".red
      return
    end
  end
end

# Auxiliar function for paralellizing requests.
def parallelize(array,threads)
  mutex = Mutex.new
  threads.times.map {
    Thread.new(array) do |e|
      while e = mutex.synchronize { array.pop }
        yield(e)
      end
    end
  }.each(&:join)
end

# Launches requests using Requester class.
def launch(urls)
  parallelize(urls,$options[:threads]) do |url|

    $HTTP_PORTS.each do |port|
      req = Requester.new("http",url,port)
    end

    $HTTPS_PORTS.each do |port|
      req = Requester.new("https",url,port)
    end
  end
end

# Converts responses to an array.
def to_rows(res)
  rows = []
  res.each do |response|
    row = []
    row << response['base_url']
    row << response['code']
    row << response['title'] 
    row << response['length']
    row << response['headers']['Server']
    rows << row  
  end

  # Sort by response code.
  rows.sort_by! { |base_url,code| code }

  return rows
end

# Convert $res Array of hashes to ASCII table.
def get_table()
  rows = to_rows($res)
  table = Terminal::Table.new :rows => rows
  return table
end

# Generates CSV file from resulting rows
def to_csv(file_name)
  rows = to_rows($res)
  File.open($options[:file] + ".csv", "w") {|f| f.write(rows.inject([]) { |csv, row|  csv << CSV.generate_line(row) }.join(""))}
end

# Normalize IPs on CIDR format.
def normalize(ips)
  res = []
  ips.each { |ip|
    begin  
      a = NetAddr::CIDR.create(ip.gsub("\n",""))
      res << a.enumerate
    rescue
      res << ip
    end
  }
  return res.join(",").split(",")
end


### PROGRAM MAIN

def main
  urls = []

  if ($options[:file] == nil || $options[:help]) then
    puts "File missing, use -f <file>. See help with -h"
    exit
  end

  File.foreach($options[:file]) { |line|  urls << line.chomp}
  urls = normalize(urls)
  launch(urls)
    
  # Save table to a csv.
  if $options[:csv] then
    to_csv($options[:file])
    puts "[+] CSV saved to: #{$options[:file]}.csv".green.bold
  end

  begin
    table = get_table()
  rescue
    puts "Error when generating table."
  end
  
  # Save table to a file.
  file = File.open($options[:file] + ".table", "w")
  file.puts table
  file.close
  puts "[+] ASCII table saved to: #{$options[:file]}.table".green.bold

end

main
