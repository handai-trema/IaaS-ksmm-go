require 'dijkstra'
require 'dijkstra_optimal'

# Network topology graph
class Graph
  def initialize
    @graph = Hash.new([].freeze)
  end

  def get_length
    @graph.length
  end

  def get_graph(key)
    @graph[key]
  end

  def fetch(node)
    @graph.fetch(node)
  end

  def delete_node(node)
    fail unless node.is_a?(Topology::Port)
    #puts "--before--"
    #puts "@graph[#{node}] is #{@graph[node]}"
    #puts "@graph[#{node.dpid}] is #{@graph[node.dpid]}"
    #@graph.delete(node)
    @graph[node] = []
    @graph[node.dpid] -= [node]
    #puts "#{node} is deleted"
    #puts "@graph[#{node}] is #{@graph[node]}"
    #puts "@graph[#{node.dpid}] is #{@graph[node.dpid]}"
  end

  def add_link(node_a, node_b)
    #puts caller(0)
#    if node_a.is_a? Pio::Mac then
#      puts "host is registered in graph"
#      dammy = Pio::Mac.new("88:88:88:88:88:88")
#      @graph[node_b] += [dammy]
#    end
    #puts "--before--"
    #puts "@graph[#{node_a}] is #{@graph[node_a]}"
    #puts "@graph[#{node_b}] is #{@graph[node_b]}"
    @graph[node_a] += [node_b]
    @graph[node_b] += [node_a]
    #puts "#{node_a} - #{node_b} is added"
    #puts "@graph[#{node_a}] is #{@graph[node_a]}"
    #puts "@graph[#{node_b}] is #{@graph[node_b]}"
    #puts "--end--"
    #puts "--node_a--"
    #puts node_a
    #puts "--node_b--"
    #puts node_b
  end

  def delete_link(node_a, node_b)
    #puts "--before--"
    #puts "@graph[#{node_a}] is #{@graph[node_a]}"
    #puts "@graph[#{node_b}] is #{@graph[node_b]}"
    @graph[node_a] -= [node_b]
    @graph[node_b] -= [node_a]
    #puts "#{node_a} - #{node_b} is deleted"
    #puts "@graph[#{node_a}] is #{@graph[node_a]}"
    #puts "@graph[#{node_b}] is #{@graph[node_b]}"
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
    #@graph.each do |key,val|
    #  puts "#{key} -> #{val}"
    #end
    route = Dijkstra.new(@graph).run(source_mac, destination_mac)
    #route = DijkstraOpt.new(@graph,@load_table).run(source_mac, destination_mac)
    route.reject { |each| each.is_a? Integer }
  end
end
