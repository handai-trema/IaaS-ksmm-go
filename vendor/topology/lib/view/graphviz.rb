require 'graphviz'
require 'pio'

module View
  # Topology controller's GUI (graphviz).
  class Graphviz
    def initialize(output = 'topology.png')
      @output = output
    end

    # rubocop:disable AbcSize
    def update(_event, _changed, topology)
      GraphViz.new(:G, use: 'neato', overlap: false, splines: true) do |gviz|
        nodes = topology.switches.each_with_object({}) do |each, tmp|
          tmp[each] = gviz.add_nodes(each.to_hex, shape: 'box')
        end
        topology.links.each do |each|
          next unless nodes[each.dpid_a] && nodes[each.dpid_b]
          gviz.add_edges nodes[each.dpid_a], nodes[each.dpid_b]
        end
        #added (2016.11.9) add ellipse with ip_address and link between host and switch
        topology.hosts.each do |each|  #for all host
          host = gviz.add_nodes(each[1].to_s, shape: 'ellipse')  #add ellipse with ip_address(each[1])
          gviz.add_edges host, nodes[each[2]]  #add link between host and switch(each[2]:switch dpid)
        end
        gviz.output png: @output
      end
    end
    # rubocop:enable AbcSize

    def to_s
      "Graphviz mode, output = #{@output}"
    end
  end
end
