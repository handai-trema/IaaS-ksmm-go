require 'dijkstra'

# Network topology graph
class Graph
  def initialize
    @graph = Hash.new([].freeze)
  end

  def fetch(node)
    @graph.fetch(node)
  end

  def delete_node(node)
    fail unless node.is_a?(Topology::Port)
    @graph.delete(node)
    @graph[node.dpid] -= [node]
  end

  def add_link(node_a, node_b)
    #puts "--add_link_in_graph--"
    #puts caller(0)
#    if node_a.is_a? Pio::Mac then
#      puts "host is registered in graph"
#      dammy = Pio::Mac.new("88:88:88:88:88:88")
#      @graph[node_b] += [dammy]
#    end
    @graph[node_a] += [node_b]
    @graph[node_b] += [node_a]
    #puts node_a.class
    #puts node_b.class
    #puts "--end--"
  end

  def delete_link(node_a, node_b)
    @graph[node_a] -= [node_b]
    @graph[node_b] -= [node_a]
  end

  def external_ports
    @graph.select do |key, value|
      key.is_a?(Topology::Port) && value.size == 1
    end.keys
  end

  def host_ports
    #ホストがつながっているポートを出力するメソッド。自作
    host = @graph.select do |key, value|
      key.is_a?(Pio::Mac)
    end.values
    result = []
    host.each do |ports|
      ports.each do |each|
        #puts each.class
        result << each
      end
    end
    result
  end

  def dijkstra(source_mac, destination_mac)
    #puts "--key--"
    #@graph.each_key do |key|
    #  puts key.class
    #end
    #puts "--value--"
    #@graph.each_value do |value|
    #  puts value.to_s
    #end
    puts "enter dijkstra!!"
    puts "source mac in dijkstra is " + source_mac
    puts "destination mac in dijkstra is " + destination_mac
    #puts @graph[source_mac]
    return if @graph[destination_mac].empty?
    puts "find destination_mac in dijkstra"
    return if @graph[source_mac].empty?
    puts "find source_mac in dijkstra"
    #puts "source mac is " + source_mac
    #puts "destination mac is " + destination_mac
    route = Dijkstra.new(@graph).run(source_mac, destination_mac)
    route.reject { |each| each.is_a? Integer }
  end
end
