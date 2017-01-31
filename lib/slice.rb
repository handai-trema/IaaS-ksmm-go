require 'active_support/core_ext/class/attribute_accessors'
require 'drb'
require 'json'
require 'path_manager'
require 'port'
require 'slice_exceptions'
require 'slice_extensions'
require 'pio'#必要かわからないけどとりあえず
require 'erb'#必要かわからないけどとりあえず

# Virtual slice.
# rubocop:disable ClassLength
class Slice
  extend DRb::DRbUndumped
  include DRb::DRbUndumped

  cattr_accessor(:all, :colors, instance_reader: false) { [] }

  def self.create(name)
    if find_by(name: name)
      fail SliceAlreadyExistsError, "Slice #{name} already exists"
    end
    new(name).tap { |slice| all << slice }
  end

  def self.split(base, *into)
    base_slice = find_by!(name: base)#splited slice (object)
    split_to_name = Array.new().tap{|ary| into.each{|each| ary << each.split(":")[0]}} #slice names spliting to
    split_to_name.each{|each| fail SliceAlreadyExistsError, "Slice #{each} already exists" if find_by(name: each)}

    #each array in hosts_mac_addrs corresponds to each host
    hosts_mac_addrs = Array.new().tap{|ary| into.each{|each| each.split(":")[1] ? ary << each.split(":", 2)[1].split(",") : ary << [] }}
    ports = base_slice.ports
    #each array in macs corresponds to each port
    macs = []
    ports.each{|each| macs << base_slice.mac_addresses(each)} if ports
    #managing port is already added or not
    #find_port returns fail when port isn't added and add_port return fail when port is already added. so it needed.
    is_added = Array.new(2).tap{|ary| ary = {}.tap{|h| ports.each{|port| h[port] = false} if ports}}
    #for each new slice
    split_to_name.zip(hosts_mac_addrs, is_added).each do |slice_name, mac_addrs, is_a|
      tmp_slice = create(slice_name)
      next unless mac_addrs
      mac_addrs.each do |mac_addr|
        macs.zip(ports).each do |each, port|
          each.each do |mac|
            next unless mac == mac_addr
            #only add port when the slice includes the host with the port
            if is_a && !is_a[port]
              tmp_slice.add_port(port)
              is_a[port] = true
            end
            tmp_slice.add_mac_address(mac_addr, port)
            base_slice.delete_mac_address(mac_addr,port)
            base_slice.delete_port(port)
          end
        end
      end
    end
    destroy(base_slice.name) if base_slice.ports.length.zero?
    puts "split #{base} into #{into[0].split(":")[0]} and #{into[1].split(":")[0]}"
    write_slice_info
  end

  def self.join(base, into)
    #slices (object)
    base_slices = Array.new().tap{|slices| base.each{|each| slices << find_by!(name: each)}}
    fail SliceAlreadyExistsError, "Slice #{into} already exists" if find_by(name: into)

    #new slice(object)
    join_to = create(into)
    #managing port is already added or not
    is_added = {}.tap{|h| base_slices.each{|slice| slice.ports.each{|port| h[port] = false}}}
    base_slices.each do |base_slice|
      base_slice.ports.each do |port|
        if is_added && !is_added[port]
          join_to.add_port(port)
          is_added[port] = true
        end
        base_slice.mac_addresses(port).each{|mac| join_to.add_mac_address(mac, port)}
      end
      destroy(base_slice.name)
    end
    puts "join #{base[0]} and #{base[1]} into #{into}"
    write_slice_info
  end

  # This method smells of :reek:NestedIterators but ignores them
  def self.find_by(queries)
    queries.inject(all) do |memo, (attr, value)|
      memo.find_all { |slice| slice.__send__(attr) == value }
    end.first
  end

  def self.find_by!(queries)
    find_by(queries) || fail(SliceNotFoundError,
                             "Slice #{queries.fetch(:name)} not found")
  end

  def self.find(&block)
    all.find(&block)
  end

  def self.destroy(name)
    find_by!(name: name)
    Path.find { |each| each.slice == name }.each(&:destroy)
    all.delete_if { |each| each.name == name }
  end

  def self.destroy_all
    all.clear
  end


  def self.write_slice_info
#    color_list = ["red","green","yellow","blue","cyan","magenda","orange","pink"]
#    idx = 0
#    outtext = ""
#    all.each do |slice|
#      slice.ports.each do |port|
#	slice.mac_addresses(port).each do |mac|
#          outtext += sprintf("nodes.push({id: %d, label: '%s', font: {size:15, color:'%s', face:'sans'}, image:DIR+'switch.jpg', shape: 'image'});", mac.to_i, mac.to_s, color_list[idx])
#	end
#      end
#      idx += 1
#    end
    open("./tmp/slice.json", "w") do |io|  
      JSON.dump(["slices"=>all], io)
    end
  end

  attr_reader :name

  def initialize(name)
    @name = name
    @ports = Hash.new([].freeze)
    #@color = color
  end
  private_class_method :new

  def add_port(port_attrs)
    port = Port.new(port_attrs)
    if @ports.key?(port)
      fail PortAlreadyExistsError, "Port #{port.name} already exists"
    end
    @ports[port] = [].freeze
  end

  def delete_port(port_attrs)
    find_port port_attrs
    Path.find { |each| each.slice == @name }.select do |each|
      each.port?(Topology::Port.create(port_attrs))
    end.each(&:destroy)
    @ports.delete Port.new(port_attrs)
  end

  def find_port(port_attrs)
    mac_addresses port_attrs
    Port.new(port_attrs)
  end

  def each(&block)
    @ports.keys.each do |each|
      block.call each, @ports[each]
    end
  end

  def ports
    @ports.keys
  end

  def add_mac_address(mac_address, port_attrs)
    port = Port.new(port_attrs)
    if @ports[port].include? Pio::Mac.new(mac_address)
      fail(MacAddressAlreadyExistsError,
           "MAC address #{mac_address} already exists")
    end
    @ports[port] += [Pio::Mac.new(mac_address)]
    Slice.write_slice_info
  end

  def delete_mac_address(mac_address, port_attrs)
    find_mac_address port_attrs, mac_address
    @ports[Port.new(port_attrs)] -= [Pio::Mac.new(mac_address)]

    Path.find { |each| each.slice == @name }.select do |each|
      each.endpoints.include? [Pio::Mac.new(mac_address),
                               Topology::Port.create(port_attrs)]
    end.each(&:destroy)
    Slice.write_slice_info
  end

  def find_mac_address(port_attrs, mac_address)
    find_port port_attrs
    mac = Pio::Mac.new(mac_address)
    if @ports[Port.new(port_attrs)].include? mac
      mac
    else
      fail MacAddressNotFoundError, "MAC address #{mac_address} not found"
    end
  end

  def mac_addresses(port_attrs)
    port = Port.new(port_attrs)
    @ports.fetch(port)
  rescue KeyError
    raise PortNotFoundError, "Port #{port.name} not found"
  end

  def member?(host_id)
    puts host_id
    @ports[Port.new(host_id)].include? host_id[:mac]
  rescue
    false
  end

  def to_s
    @name
  end

  def to_json(*_)
    host = []
    @ports.keys.each do |key|
      @ports[key].each do |each| 
        host << each.to_s
      end
    end
    %({"name": "#{@name}", "host": #{host}})
  end

  def method_missing(method, *args, &block)
    @ports.__send__ method, *args, &block
  end
end
# rubocop:enable ClassLength
