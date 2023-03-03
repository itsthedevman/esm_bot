# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `celluloid-io` gem.
# Please instead update this file by running `bin/tapioca gem celluloid-io`.

# source://celluloid-io//lib/celluloid/io/version.rb#1
module Celluloid
  include ::Celluloid::InstanceMethods

  mixes_in_class_methods ::Celluloid::ClassMethods
  mixes_in_class_methods ::Celluloid::Internals::Properties

  # source://forwardable/1.3.1/forwardable.rb#226
  def [](*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def []=(*args, &block); end

  # source://celluloid/0.17.4/lib/celluloid.rb#317
  def abort(cause); end

  # source://celluloid/0.17.4/lib/celluloid.rb#431
  def after(interval, &block); end

  # source://celluloid/0.17.4/lib/celluloid.rb#450
  def async(meth = T.unsafe(nil), *args, &block); end

  # source://celluloid/0.17.4/lib/celluloid.rb#347
  def call_chain_id; end

  # source://celluloid/0.17.4/lib/celluloid.rb#342
  def current_actor; end

  # source://celluloid/0.17.4/lib/celluloid.rb#443
  def defer(&block); end

  # source://celluloid/0.17.4/lib/celluloid.rb#436
  def every(interval, &block); end

  # source://celluloid/0.17.4/lib/celluloid.rb#420
  def exclusive(&block); end

  # source://celluloid/0.17.4/lib/celluloid.rb#425
  def exclusive?; end

  # source://celluloid/0.17.4/lib/celluloid.rb#455
  def future(meth = T.unsafe(nil), *args, &block); end

  # source://celluloid/0.17.4/lib/celluloid.rb#372
  def link(actor); end

  # source://celluloid/0.17.4/lib/celluloid.rb#387
  def linked_to?(actor); end

  # source://celluloid/0.17.4/lib/celluloid.rb#357
  def links; end

  # source://celluloid/0.17.4/lib/celluloid.rb#362
  def monitor(actor); end

  # source://celluloid/0.17.4/lib/celluloid.rb#382
  def monitoring?(actor); end

  # source://celluloid/0.17.4/lib/celluloid.rb#392
  def receive(timeout = T.unsafe(nil), &block); end

  # source://celluloid-supervision/0.20.6/lib/celluloid/supervision/container/instance.rb#81
  def services; end

  # source://celluloid/0.17.4/lib/celluloid.rb#332
  def signal(name, value = T.unsafe(nil)); end

  # source://celluloid/0.17.4/lib/celluloid.rb#402
  def sleep(interval); end

  # source://celluloid/0.17.4/lib/celluloid.rb#352
  def tasks; end

  # source://celluloid/0.17.4/lib/celluloid.rb#327
  def terminate; end

  # source://celluloid/0.17.4/lib/celluloid.rb#412
  def timeout(duration); end

  # source://celluloid/0.17.4/lib/celluloid.rb#377
  def unlink(actor); end

  # source://celluloid/0.17.4/lib/celluloid.rb#367
  def unmonitor(actor); end

  # source://celluloid/0.17.4/lib/celluloid.rb#337
  def wait(name); end

  class << self
    # source://celluloid/0.17.4/lib/celluloid.rb#81
    def actor?; end

    # source://celluloid/0.17.4/lib/celluloid.rb#34
    def actor_system; end

    # source://celluloid/0.17.4/lib/celluloid.rb#27
    def actor_system=(_arg0); end

    # source://celluloid/0.17.4/lib/celluloid.rb#145
    def boot; end

    # source://celluloid/0.17.4/lib/celluloid.rb#96
    def cores; end

    # source://celluloid/0.17.4/lib/celluloid.rb#96
    def cpus; end

    # source://celluloid/0.17.4/lib/celluloid.rb#119
    def detect_recursion; end

    # source://celluloid/0.17.4/lib/celluloid.rb#103
    def dump(output = T.unsafe(nil)); end

    # source://celluloid/0.17.4/lib/celluloid.rb#131
    def exception_handler(&block); end

    # source://celluloid/0.17.4/lib/celluloid.rb#30
    def group_class; end

    # source://celluloid/0.17.4/lib/celluloid.rb#30
    def group_class=(_arg0); end

    # source://celluloid/0.17.4/lib/celluloid.rb#42
    def included(klass); end

    # source://celluloid/0.17.4/lib/celluloid.rb#150
    def init; end

    # source://celluloid/0.17.4/lib/celluloid.rb#29
    def log_actor_crashes; end

    # source://celluloid/0.17.4/lib/celluloid.rb#29
    def log_actor_crashes=(_arg0); end

    # source://celluloid/0.17.4/lib/celluloid.rb#28
    def logger; end

    # source://celluloid/0.17.4/lib/celluloid.rb#28
    def logger=(_arg0); end

    # source://celluloid/0.17.4/lib/celluloid.rb#86
    def mailbox; end

    # source://celluloid/0.17.4/lib/celluloid.rb#96
    def ncpus; end

    # source://celluloid/0.17.4/lib/celluloid.rb#114
    def public_registry; end

    # source://celluloid-essentials/0.20.5/lib/celluloid/notifications.rb#92
    def publish(*args); end

    # source://celluloid/0.17.4/lib/celluloid.rb#162
    def register_shutdown; end

    # source://celluloid/0.17.4/lib/celluloid.rb#158
    def running?; end

    # source://celluloid/0.17.4/lib/celluloid.rb#183
    def shutdown; end

    # source://celluloid/0.17.4/lib/celluloid.rb#32
    def shutdown_timeout; end

    # source://celluloid/0.17.4/lib/celluloid.rb#32
    def shutdown_timeout=(_arg0); end

    # source://celluloid/0.17.4/lib/celluloid.rb#103
    def stack_dump(output = T.unsafe(nil)); end

    # source://celluloid/0.17.4/lib/celluloid.rb#109
    def stack_summary(output = T.unsafe(nil)); end

    # source://celluloid/0.17.4/lib/celluloid.rb#154
    def start; end

    # source://celluloid/0.17.4/lib/celluloid.rb#109
    def summarize(output = T.unsafe(nil)); end

    # source://celluloid-supervision/0.20.6/lib/celluloid/supervision/deprecate/supervise.rb#5
    def supervise(*args, &block); end

    # source://celluloid-supervision/0.20.6/lib/celluloid/supervision/deprecate/supervise.rb#10
    def supervise_as(name, *args, &block); end

    # source://celluloid/0.17.4/lib/celluloid.rb#135
    def suspend(status, waiter); end

    # source://celluloid/0.17.4/lib/celluloid.rb#31
    def task_class; end

    # source://celluloid/0.17.4/lib/celluloid.rb#31
    def task_class=(_arg0); end

    # source://celluloid/0.17.4/lib/celluloid.rb#91
    def uuid; end

    # source://celluloid/0.17.4/lib/celluloid.rb#187
    def version; end
  end
end

# Actors with evented IO support
#
# source://celluloid-io//lib/celluloid/io/version.rb#2
module Celluloid::IO
  include ::Celluloid::InstanceMethods
  include ::Celluloid

  mixes_in_class_methods ::Celluloid::ClassMethods
  mixes_in_class_methods ::Celluloid::Internals::Properties

  private

  # source://celluloid-io//lib/celluloid/io.rb#50
  def wait_readable(io); end

  # source://celluloid-io//lib/celluloid/io.rb#62
  def wait_writable(io); end

  class << self
    # source://celluloid-io//lib/celluloid/io.rb#39
    def copy_stream(src, dst, copy_length = T.unsafe(nil), src_offset = T.unsafe(nil)); end

    # @return [Boolean]
    #
    # source://celluloid-io//lib/celluloid/io.rb#30
    def evented?; end

    # @private
    #
    # source://celluloid-io//lib/celluloid/io.rb#25
    def included(klass); end

    # source://celluloid-io//lib/celluloid/io.rb#35
    def try_convert(src); end

    # source://celluloid-io//lib/celluloid/io.rb#50
    def wait_readable(io); end

    # source://celluloid-io//lib/celluloid/io.rb#62
    def wait_writable(io); end
  end
end

# Default size to read from or write to the stream for buffer operations
#
# source://celluloid-io//lib/celluloid/io.rb#23
Celluloid::IO::BLOCK_SIZE = T.let(T.unsafe(nil), Integer)

# Asynchronous DNS resolver using Celluloid::IO::UDPSocket
#
# source://celluloid-io//lib/celluloid/io/dns_resolver.rb#7
class Celluloid::IO::DNSResolver
  # @return [DNSResolver] a new instance of DNSResolver
  #
  # source://celluloid-io//lib/celluloid/io/dns_resolver.rb#23
  def initialize; end

  # source://celluloid-io//lib/celluloid/io/dns_resolver.rb#35
  def resolve(hostname); end

  private

  # source://celluloid-io//lib/celluloid/io/dns_resolver.rb#72
  def build_query(hostname); end

  # source://celluloid-io//lib/celluloid/io/dns_resolver.rb#91
  def get_address(host); end

  # source://celluloid-io//lib/celluloid/io/dns_resolver.rb#68
  def resolv; end

  # source://celluloid-io//lib/celluloid/io/dns_resolver.rb#80
  def resolve_host(host); end

  # source://celluloid-io//lib/celluloid/io/dns_resolver.rb#60
  def resolve_hostname(hostname); end

  # source://celluloid-io//lib/celluloid/io/dns_resolver.rb#84
  def resolve_ip(klass, host); end

  class << self
    # source://celluloid-io//lib/celluloid/io/dns_resolver.rb#15
    def generate_id; end

    # source://celluloid-io//lib/celluloid/io/dns_resolver.rb#19
    def nameservers; end
  end
end

# source://celluloid-io//lib/celluloid/io/dns_resolver.rb#10
Celluloid::IO::DNSResolver::DNS_PORT = T.let(T.unsafe(nil), Integer)

# Maximum UDP packet we'll accept
#
# source://celluloid-io//lib/celluloid/io/dns_resolver.rb#9
Celluloid::IO::DNSResolver::MAX_PACKET_SIZE = T.let(T.unsafe(nil), Integer)

# An alternative implementation of Celluloid::Mailbox using Reactor
#
# source://celluloid-io//lib/celluloid/io/mailbox.rb#4
class Celluloid::IO::Mailbox < ::Celluloid::Mailbox::Evented
  # @return [Mailbox] a new instance of Mailbox
  #
  # source://celluloid-io//lib/celluloid/io/mailbox.rb#5
  def initialize; end
end

# React to external I/O events. This is kinda sorta supposed to resemble the
# Reactor design pattern.
#
# source://celluloid-io//lib/celluloid/io/reactor.rb#7
class Celluloid::IO::Reactor
  extend ::Forwardable

  # @return [Reactor] a new instance of Reactor
  #
  # source://celluloid-io//lib/celluloid/io/reactor.rb#15
  def initialize; end

  # Run the reactor, waiting for events or wakeup signal
  #
  # source://celluloid-io//lib/celluloid/io/reactor.rb#57
  def run_once(timeout = T.unsafe(nil)); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def shutdown(*args, &block); end

  # Wait for the given IO operation to complete
  #
  # source://celluloid-io//lib/celluloid/io/reactor.rb#30
  def wait(io, set); end

  # Wait for the given IO object to become readable
  #
  # source://celluloid-io//lib/celluloid/io/reactor.rb#20
  def wait_readable(io); end

  # Wait for the given IO object to become writable
  #
  # source://celluloid-io//lib/celluloid/io/reactor.rb#25
  def wait_writable(io); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def wakeup(*args, &block); end
end

# SSLServer wraps a TCPServer to provide immediate SSL accept
#
# source://celluloid-io//lib/celluloid/io/ssl_server.rb#6
class Celluloid::IO::SSLServer
  extend ::Forwardable

  # @return [SSLServer] a new instance of SSLServer
  #
  # source://celluloid-io//lib/celluloid/io/ssl_server.rb#13
  def initialize(server, ctx); end

  # source://celluloid-io//lib/celluloid/io/ssl_server.rb#19
  def accept; end

  # source://forwardable/1.3.1/forwardable.rb#226
  def close(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def closed?(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def listen(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def shutdown(*args, &block); end

  # Returns the value of attribute start_immediately.
  #
  # source://celluloid-io//lib/celluloid/io/ssl_server.rb#10
  def start_immediately; end

  # Sets the attribute start_immediately
  #
  # @param value the value to set the attribute start_immediately to.
  #
  # source://celluloid-io//lib/celluloid/io/ssl_server.rb#10
  def start_immediately=(_arg0); end

  # Returns the value of attribute tcp_server.
  #
  # source://celluloid-io//lib/celluloid/io/ssl_server.rb#11
  def tcp_server; end

  # source://forwardable/1.3.1/forwardable.rb#226
  def to_io(*args, &block); end
end

# SSLSocket with Celluloid::IO support
#
# source://celluloid-io//lib/celluloid/io/ssl_socket.rb#6
class Celluloid::IO::SSLSocket < ::Celluloid::IO::Stream
  # @return [SSLSocket] a new instance of SSLSocket
  #
  # source://celluloid-io//lib/celluloid/io/ssl_socket.rb#20
  def initialize(io, ctx = T.unsafe(nil)); end

  # source://celluloid-io//lib/celluloid/io/ssl_socket.rb#35
  def accept; end

  # source://forwardable/1.3.1/forwardable.rb#226
  def cert(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def cipher(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def client_ca(*args, &block); end

  # source://celluloid-io//lib/celluloid/io/ssl_socket.rb#27
  def connect; end

  # source://forwardable/1.3.1/forwardable.rb#226
  def peer_cert(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def peer_cert_chain(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def peeraddr(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def post_connection_check(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def sync_close=(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def verify_result(*args, &block); end
end

# Base class for all classes that wrap a ruby socket.
#
# @abstract
#
# source://celluloid-io//lib/celluloid/io/socket.rb#5
class Celluloid::IO::Socket
  include ::Socket::Constants
  extend ::Forwardable

  # @param socket [BasicSocket, OpenSSL::SSL::SSLSocket]
  # @return [Socket] a new instance of Socket
  #
  # source://celluloid-io//lib/celluloid/io/socket.rb#13
  def initialize(socket); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def addr(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def close(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def close_read(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def close_write(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def closed?(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def fcntl(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def getsockname(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def getsockopt(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def read_nonblock(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def setsockopt(*args, &block); end

  # Returns the wrapped socket.
  #
  # @return [BasicSocket, OpenSSL::SSL::SSLSocket]
  #
  # source://celluloid-io//lib/celluloid/io/socket.rb#24
  def to_io; end

  # source://forwardable/1.3.1/forwardable.rb#226
  def write_nonblock(*args, &block); end

  class << self
    # source://forwardable/1.3.1/forwardable.rb#226
    def accept_loop(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def binread(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def binwrite(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def console(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def copy_stream(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def do_not_reverse_lookup(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def do_not_reverse_lookup=(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def for_fd(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def foreach(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def getaddrinfo(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def gethostbyaddr(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def gethostbyname(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def gethostname(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def getifaddrs(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def getnameinfo(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def getservbyname(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def getservbyport(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def ip_address_list(*args, &block); end

    # Celluloid::IO:Socket.new behaves like Socket.new for compatibility.
    # This is is not problematic since Celluloid::IO::Socket is abstract.
    # To instantiate a socket use one of its subclasses.
    #
    # source://celluloid-io//lib/celluloid/io/socket.rb#35
    def new(*args); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def open(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def pack_sockaddr_in(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def pack_sockaddr_un(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def pair(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def pipe(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def popen(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def read(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def readlines(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def select(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def sockaddr_in(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def sockaddr_un(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def socketpair(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def sysopen(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def tcp(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def tcp_server_loop(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def tcp_server_sockets(*args, &block); end

    # Tries to convert the given ruby socket into a subclass of GenericSocket.
    #
    # @param socket
    # @return [SSLSocket, TCPServer, TCPSocket, UDPSocket, UNIXServer, UNIXSocket]
    # @return [nil] if the socket can't be converted
    #
    # source://celluloid-io//lib/celluloid/io/socket.rb#47
    def try_convert(socket, convert_io = T.unsafe(nil)); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def udp_server_loop(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def udp_server_loop_on(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def udp_server_recv(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def udp_server_sockets(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def unix(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def unix_server_loop(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def unix_server_socket(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def unpack_sockaddr_in(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def unpack_sockaddr_un(*args, &block); end

    # source://forwardable/1.3.1/forwardable.rb#226
    def write(*args, &block); end
  end
end

# Compatibility
#
# source://celluloid-io//lib/celluloid/io/socket.rb#29
Celluloid::IO::Socket::Constants = Socket::Constants

# Base class of all streams in Celluloid::IO
#
# source://celluloid-io//lib/celluloid/io/stream.rb#11
class Celluloid::IO::Stream < ::Celluloid::IO::Socket
  include ::Enumerable

  # @return [Stream] a new instance of Stream
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#19
  def initialize(socket); end

  # Writes +s+ to the stream.  +s+ will be converted to a String using
  # String#to_s.
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#256
  def <<(s); end

  # Closes the stream and flushes any unwritten data.
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#311
  def close; end

  # Executes the block for every line in the stream where lines are separated
  # by +eol+.
  #
  # See also #gets
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#181
  def each(eol = T.unsafe(nil)); end

  # Calls the given block once for each byte in the stream.
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#216
  def each_byte; end

  # Executes the block for every line in the stream where lines are separated
  # by +eol+.
  #
  # See also #gets
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#181
  def each_line(eol = T.unsafe(nil)); end

  # Returns true if the stream is at file which means there is no more data to
  # be read.
  #
  # @return [Boolean]
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#241
  def eof; end

  # Returns true if the stream is at file which means there is no more data to
  # be read.
  #
  # @return [Boolean]
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#241
  def eof?; end

  # Flushes buffered data to the stream.
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#301
  def flush; end

  # Reads one character from the stream.  Returns nil if called at end of
  # file.
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#211
  def getc; end

  # Reads the next line from the stream.  Lines are separated by +eol+.  If
  # +limit+ is provided the result will not be longer than the given number of
  # bytes.
  #
  # +eol+ may be a String or Regexp.
  #
  # Unlike IO#gets the line read will not be assigned to +$_+.
  #
  # Unlike IO#gets the separator must be provided if a limit is provided.
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#155
  def gets(eol = T.unsafe(nil), limit = T.unsafe(nil)); end

  # Writes +args+ to the stream.
  #
  # See IO#print for full details.
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#284
  def print(*args); end

  # Formats and writes to the stream converting parameters under control of
  # the format string.
  #
  # See Kernel#sprintf for format string details.
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#295
  def printf(s, *args); end

  # Writes +args+ to the stream along with a record separator.
  #
  # See IO#puts for full details.
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#264
  def puts(*args); end

  # Reads +size+ bytes from the stream.  If +buf+ is provided it must
  # reference a string which will receive the data.
  #
  # See IO#read for full details.
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#87
  def read(size = T.unsafe(nil), buf = T.unsafe(nil)); end

  # Reads a one-character string from the stream.  Raises an EOFError at end
  # of file.
  #
  # @raise [EOFError]
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#224
  def readchar; end

  # Reads a line from the stream which is separated by +eol+.
  #
  # Raises EOFError if at end of file.
  #
  # @raise [EOFError]
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#204
  def readline(eol = T.unsafe(nil)); end

  # Reads lines from the stream which are separated by +eol+.
  #
  # See also #gets
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#191
  def readlines(eol = T.unsafe(nil)); end

  # Reads at most +maxlen+ bytes from the stream.  If +buf+ is provided it
  # must reference a string which will receive the data.
  #
  # See IO#readpartial for full details.
  #
  # @raise [EOFError]
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#117
  def readpartial(maxlen, buf = T.unsafe(nil)); end

  # The "sync mode" of the stream
  #
  # See IO#sync for full details.
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#17
  def sync; end

  # The "sync mode" of the stream
  #
  # See IO#sync for full details.
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#17
  def sync=(_arg0); end

  # System read via the nonblocking subsystem
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#37
  def sysread(length = T.unsafe(nil), buffer = T.unsafe(nil)); end

  # System write via the nonblocking subsystem
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#53
  def syswrite(string); end

  # Pushes character +c+ back onto the stream such that a subsequent buffered
  # character read will return it.
  #
  # Unlike IO#getc multiple bytes may be pushed back onto the stream.
  #
  # Has no effect on unbuffered reads (such as #sysread).
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#235
  def ungetc(c); end

  # Wait until the current object is readable
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#31
  def wait_readable; end

  # Wait until the current object is writable
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#34
  def wait_writable; end

  # Writes +s+ to the stream.  If the argument is not a string it will be
  # converted using String#to_s.  Returns the number of bytes written.
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#249
  def write(s); end

  private

  # Consumes +size+ bytes from the buffer
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#332
  def consume_rbuff(size = T.unsafe(nil)); end

  # Writes +s+ to the buffer.  When the buffer is full or #sync is true the
  # buffer is flushed to the underlying stream.
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#345
  def do_write(s); end

  # Fills the buffer from the underlying stream
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#321
  def fill_rbuff; end
end

# Perform an operation exclusively, uncontested by other tasks
#
# source://celluloid-io//lib/celluloid/io/stream.rb#369
class Celluloid::IO::Stream::Latch
  # @return [Latch] a new instance of Latch
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#370
  def initialize; end

  # Synchronize an operation across all tasks in the current actor
  #
  # source://celluloid-io//lib/celluloid/io/stream.rb#377
  def synchronize; end
end

# TCPServer with combined blocking and evented support
#
# source://celluloid-io//lib/celluloid/io/tcp_server.rb#6
class Celluloid::IO::TCPServer < ::Celluloid::IO::Socket
  # @overload initialize
  # @overload initialize
  # @overload initialize
  # @return [TCPServer] a new instance of TCPServer
  #
  # source://celluloid-io//lib/celluloid/io/tcp_server.rb#22
  def initialize(*args); end

  # @return [TCPSocket]
  #
  # source://celluloid-io//lib/celluloid/io/tcp_server.rb#35
  def accept; end

  # @return [TCPSocket]
  #
  # source://celluloid-io//lib/celluloid/io/tcp_server.rb#41
  def accept_nonblock; end

  # source://forwardable/1.3.1/forwardable.rb#226
  def addr(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def listen(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def sysaccept(*args, &block); end

  class << self
    # Convert a Ruby TCPServer into a Celluloid::IO::TCPServer
    #
    # @deprecated Use .new instead.
    #
    # source://celluloid-io//lib/celluloid/io/tcp_server.rb#47
    def from_ruby_server(ruby_server); end
  end
end

# TCPSocket with combined blocking and evented support
#
# source://celluloid-io//lib/celluloid/io/tcp_socket.rb#7
class Celluloid::IO::TCPSocket < ::Celluloid::IO::Stream
  # @overload initialize
  # @overload initialize
  # @return [TCPSocket] a new instance of TCPSocket
  #
  # source://celluloid-io//lib/celluloid/io/tcp_socket.rb#45
  def initialize(*args); end

  # @return [Resolv::IPv4, Resolv::IPv6]
  #
  # source://celluloid-io//lib/celluloid/io/tcp_socket.rb#71
  def addr; end

  # source://forwardable/1.3.1/forwardable.rb#226
  def peeraddr(*args, &block); end

  # Receives a message
  #
  # source://celluloid-io//lib/celluloid/io/tcp_socket.rb#58
  def recv(maxlen, flags = T.unsafe(nil)); end

  # Send a message
  #
  # source://celluloid-io//lib/celluloid/io/tcp_socket.rb#64
  def send(msg, flags, dest_sockaddr = T.unsafe(nil)); end

  private

  # source://celluloid-io//lib/celluloid/io/tcp_socket.rb#84
  def create_socket(remote_host, remote_port = T.unsafe(nil), local_host = T.unsafe(nil), local_port = T.unsafe(nil)); end

  class << self
    # Convert a Ruby TCPSocket into a Celluloid::IO::TCPSocket
    # DEPRECATED: to be removed in a future release
    #
    # @deprecated Use {Celluloid::IO::TCPSocket#new} instead.
    #
    # source://celluloid-io//lib/celluloid/io/tcp_socket.rb#28
    def from_ruby_socket(ruby_socket); end

    # Open a TCP socket, yielding it to the given block and closing it
    # automatically when done (if a block is given)
    #
    # source://celluloid-io//lib/celluloid/io/tcp_socket.rb#14
    def open(*args, &_block); end
  end
end

# UDPSockets with combined blocking and evented support
#
# source://celluloid-io//lib/celluloid/io/udp_socket.rb#4
class Celluloid::IO::UDPSocket < ::Celluloid::IO::Socket
  # @overload initialize
  # @overload initialize
  # @return [UDPSocket] a new instance of UDPSocket
  #
  # source://celluloid-io//lib/celluloid/io/udp_socket.rb#15
  def initialize(*args); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def bind(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def connect(*args, &block); end

  # Receives up to maxlen bytes from socket. flags is zero or more of the
  # MSG_ options. The first element of the results, mesg, is the data
  # received. The second element, sender_addrinfo, contains
  # protocol-specific address information of the sender.
  #
  # source://celluloid-io//lib/celluloid/io/udp_socket.rb#34
  def recvfrom(maxlen, flags = T.unsafe(nil)); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def recvfrom_nonblock(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def send(*args, &block); end

  # Wait until the socket is readable
  #
  # source://celluloid-io//lib/celluloid/io/udp_socket.rb#28
  def wait_readable; end
end

# UNIXServer with combined blocking and evented support
#
# source://celluloid-io//lib/celluloid/io/unix_server.rb#6
class Celluloid::IO::UNIXServer < ::Celluloid::IO::Socket
  # @overload initialize
  # @overload initialize
  # @return [UNIXServer] a new instance of UNIXServer
  #
  # source://celluloid-io//lib/celluloid/io/unix_server.rb#19
  def initialize(socket); end

  # source://celluloid-io//lib/celluloid/io/unix_server.rb#39
  def accept; end

  # source://celluloid-io//lib/celluloid/io/unix_server.rb#44
  def accept_nonblock; end

  # source://forwardable/1.3.1/forwardable.rb#226
  def listen(*args, &block); end

  # source://forwardable/1.3.1/forwardable.rb#226
  def sysaccept(*args, &block); end

  class << self
    # source://celluloid-io//lib/celluloid/io/unix_server.rb#10
    def open(socket_path); end
  end
end

# UNIXSocket with combined blocking and evented support
#
# source://celluloid-io//lib/celluloid/io/unix_socket.rb#7
class Celluloid::IO::UNIXSocket < ::Celluloid::IO::Stream
  # Open a UNIX connection.
  #
  # @return [UNIXSocket] a new instance of UNIXSocket
  #
  # source://celluloid-io//lib/celluloid/io/unix_socket.rb#20
  def initialize(socket_path, &block); end

  class << self
    # Convert a Ruby UNIXSocket into a Celluloid::IO::UNIXSocket
    # DEPRECATED: to be removed in a future release
    #
    # @deprecated use .new instead
    #
    # source://celluloid-io//lib/celluloid/io/unix_socket.rb#15
    def from_ruby_socket(ruby_socket); end

    # Open a UNIX connection.
    #
    # source://celluloid-io//lib/celluloid/io/unix_socket.rb#8
    def open(socket_path, &block); end
  end
end

# source://celluloid-io//lib/celluloid/io/version.rb#3
Celluloid::IO::VERSION = T.let(T.unsafe(nil), String)
