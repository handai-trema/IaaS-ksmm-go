require 'graph'
require 'path'
require 'trema'

# L2 routing path manager
class PathManager < Trema::Controller

  def add_observer(observer)
    @observers << observer
  end

  def start
    @observers = []
    @graph = Graph.new
    @server_mac = {}
    logger.info 'Path Manager started.'
  end

  # This method smells of :reek:FeatureEnvy but ignores them
  def packet_in(_dpid, packet_in)
    #puts "packet_in in path_manager"
    return unless packet_in.data.is_a? Parser::IPv4Packet
    #puts packet_in.source_ip_address.to_a[0].class
    return unless packet_in.source_ip_address.to_a[0] > 191
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
    del_path = Path.find { |each| each.link?(port_a, port_b) }
    # パス情報の取り出し
    #killpath = Path.find { |each| each.link?(port_a, port_b) }
    #host_pair = []
    #killpath.each do |each|
    #  host_pair << each.get_packet_in
    #end
    #puts host_pair.to_s
    Path.find { |each| each.link?(port_a, port_b) }.each(&:destroy)
    # パスの再作成
    #host_pair.each do |each|
    #  maybe_create_shortest_path(each)
    #end
    maybe_send_handler :del_path, del_path#可視化用
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
    p packet_in.source_mac
    p packet_in.destination_mac
    destination_ip = packet_in.destination_ip_address.to_a
    source_ip = packet_in.source_ip_address.to_a
    if destination_ip[3] > 100  && destination_ip[3] <= 200 then
      if @server_mac.has_key?(1) then
        dest = @server_mac[1]
        puts "dest rewrited by saved mac!!"
        p dest
      else
        dest = Mac.new ("00:00:00:00:00:01")
        puts "dest rewrited by new mac!!"
        p dest
      end
    elsif destination_ip[3] > 200 then
      if @server_mac.has_key?(2) then
        dest = @server_mac[2]
        puts "dest rewrited by saved mac!!"
        p dest
      else
        dest = Mac.new ("00:00:00:00:00:02")
        puts "dest rewrited by new mac!!"
        p dest
      end
    else
      dest = packet_in.destination_mac
    end
    if source_ip[3] > 100  && source_ip[3] <= 200 then
      if @server_mac.has_key?(1) then
        source = @server_mac[1]
        puts "source rewrited by saved mac!!"
        p source
      else
        source = Mac.new ("00:00:00:00:00:01")
        puts "source rewrited by new mac!!"
        p source
      end
    elsif source_ip[3] > 200 then
      if @server_mac.has_key?(2) then
        source = @server_mac[2]
        puts "souorce rewrited by saved mac!!"
        p source
      else
        source = Mac.new ("00:00:00:00:00:02")
        puts "source rewrited by new mac!!"
        p source
      end
    else
      source = packet_in.source_mac
    end
    #puts "dump!!!!!!!!!!"
    #puts packet_in.destination_mac
    #puts packet_in.destination_mac.class
    shortest_path =
      #@graph.dijkstra(packet_in.source_mac, packet_in.destination_mac)
      @graph.dijkstra(source, dest)
    return unless shortest_path
#ここで渡す前にパスにコンテナのMACをもどす（shortest_path->shortest_path_in_container
    maybe_send_handler :add_path, shortest_path#可視化用
#    if dest != packet_in.destination_mac then
#      #shortest_path.push(packet_in.destination_mac)
#    end
    puts "パス情報"
    puts shortest_path.class
    Path.create shortest_path, packet_in
  end

  def maybe_send_handler(method, *args)
    @observers.each do |each|
      each.__send__ method, *args if each.respond_to?(method)
    end
  end
end
