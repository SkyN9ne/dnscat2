##
# dnscat2_server.rb
# Created March, 2013
# By Ron Bowes
#
# See: LICENSE.md
#
# Implements basically the full Dnscat2 protocol. Doesn't care about
# lower-level protocols.
##

$LOAD_PATH << File.dirname(__FILE__) # A hack to make this work on 1.8/1.9

require 'controller/controller'
require 'libs/settings'
require 'tunnel_drivers/driver_dns'
require 'tunnel_drivers/driver_tcp'
require 'tunnel_drivers/tunnel_drivers'

# Option parsing
require 'trollop'

# version info
NAME = "dnscat2"
VERSION = "0.03"

window = SWindow.new(nil, true, { :prompt => "dnscat2> ", :name => "main" })
window.puts("Welcome to dnscat2! Some documentation may be out of date.")
window.puts()

controller = Controller.new(window)

# Options
opts = Trollop::options do
  version(NAME + " v" + VERSION + " (server)")

  opt :version,   "Get the dnscat version",
    :type => :boolean, :default => false

  opt :dns,       "Start a DNS server",
    :type => :boolean, :default => true
  opt :dnshost,   "The DNS ip address to listen on",
    :type => :string,  :default => "0.0.0.0"
  opt :dnsport,   "The DNS port to listen on",
    :type => :integer, :default => 53
  opt :passthrough, "If set (not by default), unhandled requests are sent to a real (upstream) DNS server",
    :type => :string, :default => ""

#  opt :tcp,       "Start a TCP server",
#    :type => :boolean, :default => true
#  opt :tcphost,   "The TCP ip address to listen on",
#    :type => :string,  :default => "0.0.0.0"
#  opt :tcpport,    "The port to listen on",
#    :type => :integer, :default => 4444

  opt :debug,     "Min debug level [info, warning, error, fatal]",
    :type => :string,  :default => "warning"

  opt :auto_command,   "Send this to each client that connects",
    :type => :string,  :default => ""
  opt :auto_attach,    "Automatically attach to new sessions",
    :type => :boolean, :default => false
  opt :packet_trace,   "Display incoming/outgoing dnscat packets",
    :type => :boolean,  :default => false
  opt :process,        "If set, the given process is run for every incoming console/exec session and given stdin/stdout. This has security implications.",
    :type => :string,   :default => nil
end

domains = ARGV.clone()

begin
  Settings::GLOBAL.create("packet_trace", Settings::TYPE_BOOLEAN, opts[:packet_trace].to_s(), "If set to 'true', will open some extra windows that will display incoming/outgoing dnscat2 packets, and also parsed command packets for command sessions.") do |old_val, new_val|
    # We don't have any callbacks
  end

  Settings::GLOBAL.create("passthrough", Settings::TYPE_BLANK_IS_NIL, opts[:passthrough].to_s(), "Send queries to the given upstream host (note: this can cause weird recursion problems). Expected: 'set passthrough host:port'. Set to blank to disable.") do |old_val, new_val|
    if(new_val.nil?)
      window.puts("passthrough => disabled")

      DriverDNS.set_passthrough(nil, nil)
      next
    end

    host, port = new_val.split(/:/, 2)
    port = port || 53

    DriverDNS.set_passthrough(host, port)
    window.puts("passthrough => #{host}:#{port}")
  end

  Settings::GLOBAL.create("auto_attach", Settings::TYPE_BOOLEAN, opts[:auto_attach].to_s(), "If true, the UI will automatically open new sessions") do |old_val, new_val|
    window.puts("auto_attach => #{new_val}")
  end

  Settings::GLOBAL.create("auto_command", Settings::TYPE_BLANK_IS_NIL, opts[:auto_command], "The command (or semicolon-separated list of commands) will automatically be executed for each new session as if they were typed at the keyboard.") do |old_val, new_val|
    window.puts("auto_command => #{new_val}")
  end

  Settings::GLOBAL.create("process", Settings::TYPE_BLANK_IS_NIL, opts[:process] || "", "If set, this process is spawned for each new console session ('--console' on the client), and it handles the session instead of getting the i/o from the keyboard.") do |old_val, new_val|
    window.puts("process => #{new_val}")
  end
rescue Settings::ValidationError => e
  window.puts("There was an error with one of your commandline arguments:")
  window.puts(e)
  window.puts()

  Trollop::die("Check your command-line arguments")
end

TunnelDrivers.start(controller, DriverDNS.new(opts[:dnshost], opts[:dnsport], domains, window))

# Wait for the input window to finish its thing
SWindow.wait()
