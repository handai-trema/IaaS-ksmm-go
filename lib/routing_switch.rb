#$LOAD_PATH.unshift File.join(__dir__, '../vendor/topology/lib')

require 'active_support/core_ext/module/delegation'
require 'optparse'
require 'path_in_slice_manager'
require 'path_manager'
require 'topology_controller'

# L2 routing switch
class RoutingSwitch < Trema::Controller
  # Command-line options of RoutingSwitch
  class Options
    attr_reader :slicing

    def initialize(args)
      @opts = OptionParser.new
      @opts.on('-s', '--slicing') { @slicing = true }
      @opts.parse [__FILE__] + args
    end
  end

  timer_event :flood_lldp_frames, interval: 1.sec
  #timer_event :send_flowstatsrequest, interval: 1.sec
  timer_event :send_aggregatestatsrequest, interval: 1.sec

  delegate :flood_lldp_frames, to: :@topology
  delegate :send_flowstatsrequest, to: :@topology
  delegate :send_aggregatestatsrequest, to: :@topology

  def slice
    fail 'Slicing is disabled.' unless @options.slicing
    Slice
  end

#  def update_slice
#ここで可視化のためにトポロジに追加する、以前はbin/sliceにこのメソッドを呼ぶ記述をしていたが、routing_switchなどでスライスの作成を自動化する場合はその部分で呼ぶ必要がある
#    @topology.update_slice(Slice.all)
#  end

  def start(args)
    @options = Options.new(args)
    @path_manager = start_path_manager
    @topology = start_topology
    @path_manager.add_observer @topology
    mac_test = Mac.new("11:11:11:11:11:11")
    puts mac_test.class
    logger.info 'Routing Switch started.'
  end

  delegate :switch_ready, to: :@topology
  delegate :features_reply, to: :@topology
  delegate :switch_disconnected, to: :@topology
  delegate :port_modify, to: :@topology
  delegate :flow_stats_reply, to: :@path_manager
  delegate :aggregate_stats_reply, to: :@path_manager

  def packet_in(dpid, packet_in)
    @topology.packet_in(dpid, packet_in)
    @path_manager.packet_in(dpid, packet_in) unless packet_in.lldp?
  end

  private

  def start_path_manager
    fail unless @options
    (@options.slicing ? PathInSliceManager : PathManager).new.tap(&:start)
  end

  def start_topology
    fail unless @path_manager
    TopologyController.new { |topo| topo.add_observer @path_manager }.start
  end
end
