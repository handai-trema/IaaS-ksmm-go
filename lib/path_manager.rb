require 'graph'
require 'path'
require 'trema'

# L2 routing path manager
class PathManager < Trema::Controller
  def start
    @graph = Graph.new
    @server_mac = nil
    logger.info 'Path Manager started.'
  end

  # This method smells of :reek:FeatureEnvy but ignores them
  def packet_in(_dpid, packet_in)
    return unless packet_in.data.is_a? Parser::IPv4Packet
    puts "packet_in in path_manager"
    #puts packet_in.source_ip_address.to_s
    #puts packet_in.source_ip_address.to_s == "192.168.0.1"
    path = maybe_create_shortest_path(packet_in)
    #puts "@graph.external_ports is here"
    #puts @graph.external_ports
    #puts "@graph.host_ports is here"
    #puts @graph.host_ports
    ports = path ? [path.out_port] : @graph.external_ports
#    p @graph
    ports.each do |each|
#      p each
      #puts each.class
      send_packet_out(each.dpid,
                      raw_data: packet_in.raw_data,
                      actions: SendOutPort.new(each.number))
    end
    unless path then
      #puts "class of external_ports is " + @graph.external_ports.class.to_s
      #puts "class of host_ports is " + @graph.host_ports.class.to_s
      @graph.host_ports.each do |each|
        #puts each.class
        send_packet_out(each.dpid,
                        raw_data: packet_in.raw_data,
                        actions: SendOutPort.new(each.number))
      end
    end
  end

  def add_port(port, _topology)
    @graph.add_link port.dpid, port
  end

  def delete_port(port, _topology)
    @graph.delete_node port
  end

  # TODO: update all paths
  def add_link(port_a, port_b, _topology)
    @graph.add_link port_a, port_b
  end

  def delete_link(port_a, port_b, _topology)
    @graph.delete_link port_a, port_b
    Path.find { |each| each.link?(port_a, port_b) }.each(&:destroy)
  end

  def add_host(mac_address, port, _topology)
    puts "--add_host:" + mac_address + "--"
    @graph.add_link mac_address, port
  end

  private

  # This method smells of :reek:FeatureEnvy but ignores them
  def maybe_create_shortest_path(packet_in)
    puts "enter maybe_create_shortest_path in path_manager"
#    unless packet_in.data.is_a? Parser::IPv4Packet then return end
#    #puts packet_in.destination_ip_address.to_a
#    if packet_in.source_mac == Mac.new("54:53:ed:1c:36:82") then
#      @server_mac = packet_in.source_mac
#      puts "save server_mac!!"
#    elsif packet_in.destination_mac == Mac.new("54:53:ed:1c:36:82") then
#      @server_mac = packet_in.destination_mac
#      puts "save server_mac!!"
#    end
    destination_ip = packet_in.destination_ip_address.to_a
    source_ip = packet_in.source_ip_address.to_a
    if destination_ip[3] > 100 then
      if @server_mac.nil? then
        dest = Mac.new ("54:53:ed:1c:36:82")
      else
        dest = @server_mac
      end
      #dest = "54:53:ed:1c:36:82"
      puts "dest rewrited!!"
    else
      dest = packet_in.destination_mac
    end
    if source_ip[3] > 100 then
      if @server_mac.nil? then
        source = Mac.new ("54:53:ed:1c:36:82")
      else
        source = @server_mac
      end
      #source = "54:53:ed:1c:36:82"
      puts "source rewrited!!"
    else
      source = packet_in.source_mac
    end
    puts "dump!!!!!!!!!!"
    puts packet_in.destination_mac
    puts packet_in.destination_mac.class
    shortest_path =
      #@graph.dijkstra(packet_in.source_mac, packet_in.destination_mac)
      @graph.dijkstra(source, dest)
    return unless shortest_path
#    if dest != packet_in.destination_mac then
#      #shortest_path.push(packet_in.destination_mac)
#    end
    puts shortest_path
    Path.create shortest_path, packet_in
  end
end
