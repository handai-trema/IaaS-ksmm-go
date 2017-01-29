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
    #欠けているグラフ
    @missing_graph = Graph.new
    # スイッチの負荷を表すHash
    @load_table = Hash.new
    #@graphと@missing_graphの使い分けのためのフラグ
    @load_flag = false
    logger.info 'Path Manager started.'
  end

  def flow_stats_reply(dpid,message)
    #puts message.stats.length if message.stats.length != 0
    message.stats.each do |each|
      #puts "0x#{dpid}:#{each["actions"].format}"
      #puts each
      #puts each["actions"].get
    end
  end

  def aggregate_stats_reply(dpid,message)
    #puts "#0x{dpid} -> #{message.packet_count}"
    @load_table[dpid] = message.packet_count
    #puts "--start--"
    #puts message.packet_count
    #puts message.byte_count
    #puts message.flow_count
    #puts "--end--"
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
    #0x6以外のスイッチのポートを登録
    @missing_graph.add_link port.dpid, port unless port.dpid == 6
    #update_path_by_add
  end

  def delete_port(port, _topology)
    @graph.delete_node port
    @missing_graph.delete_node port unless port.dpid == 6
  end

  # TODO: update all paths
  def add_link(port_a, port_b, _topology)
    @graph.add_link port_a, port_b
    @missing_graph.add_link port_a, port_b if (port_a.dpid != 6 && port_b.dpid != 6)
    #puts "--add_link_result--"
    #puts "#{port_a} -> #{@graph.get_graph port_a}"
    #puts "#{port_b} -> #{@graph.get_graph port_b}"
    update_path_by_add
  end

  def update_path_by_add
    all_path = Path.get_all_path
    count_end = all_path.size - 1
    index = 0
    for count in 0..count_end do
      src = all_path[index].source_mac
      dest = all_path[index].destination_mac
      slice_name = all_path[index].slice
      if(slice_name == "slice_a" && @load_table[15] > 20) then
        new_path = @missing_graph.dijkstra(src, dest)
      elsif(slice_name == "slice_b" && @load_table[16] > 20) then
        new_path = @missing_graph.dijkstra(src, dest)
      else
        new_path = @graph.dijkstra(src, dest)
      end
      #puts all_path[index].get_path.to_s
      #puts new_path.to_s
      if all_path[index].get_path.to_s != new_path.to_s then
        packet_in = all_path[index].get_packet_in
        all_path[index].destroy
        Path.create new_path, packet_in
      else
        puts "next index!!"
        index += 1
      end
    end
  end

  def delete_link(port_a, port_b, _topology)
    @graph.delete_link port_a, port_b
    @missing_graph.delete_link port_a, port_b if (port_a.dpid != 6 && port_b.dpid != 6)
    # パス情報の取り出し
    del_path = Path.find { |each| each.link?(port_a, port_b) }
    host_pair = []
    del_path.each do |each|
      host_pair << [each.get_packet_in, each.slice]
    end
    #puts host_pair.to_s
    Path.find { |each| each.link?(port_a, port_b) }.each(&:destroy)
    # パスの再作成
    #host_pair.each do |each|
    #  maybe_create_shortest_path(each)
    #end
    maybe_send_handler :del_path, del_path#可視化用
    host_pair.each do |each|
      if(each[1] == "slice_a" && @load_table[15] > 20) then
        @load_flag = true
      elsif(each[1] == "slice_b" && @load_table[16] > 20) then
        @load_flag = true
      else
        @load_flag = false
      end
      maybe_create_shortest_path(each[0])
    end
  end

  def add_host(mac_address, port, _topology)
    puts "--add_host:" + mac_address + "--"
    @graph.add_link mac_address, port
    @missing_graph.add_link mac_address, port unless port.dpid == 6
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
        src = @server_mac[1]
        puts "source rewrited by saved mac!!"
        p src
      else
        src = Mac.new ("00:00:00:00:00:01")
        puts "source rewrited by new mac!!"
        p src
      end
    elsif source_ip[3] > 200 then
      if @server_mac.has_key?(2) then
        src = @server_mac[2]
        puts "souorce rewrited by saved mac!!"
        p src
      else
        src = Mac.new ("00:00:00:00:00:02")
        puts "source rewrited by new mac!!"
        p src
      end
    else
      src = packet_in.source_mac
    end
    #puts "dump!!!!!!!!!!"
    #puts packet_in.destination_mac
    #puts packet_in.destination_mac.class
    if @load_flag then
      shortest_path =
        #@graph.dijkstra(packet_in.source_mac, packet_in.destination_mac)
        @missing_graph.dijkstra(src, dest)
    else
      shortest_path =
        #@graph.dijkstra(packet_in.source_mac, packet_in.destination_mac)
        @graph.dijkstra(src, dest)
    end
    return unless shortest_path
    maybe_send_handler :add_path, shortest_path#可視化用
#    if dest != packet_in.destination_mac then
#      #shortest_path.push(packet_in.destination_mac)
#    end
    #puts "パス情報"
    #puts shortest_path.class
    Path.create shortest_path, packet_in
  end

  def maybe_send_handler(method, *args)
    @observers.each do |each|
      each.__send__ method, *args if each.respond_to?(method)
    end
  end
end
