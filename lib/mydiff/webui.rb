require "mongrel"

class MyDiff
  class WebUi < Mongrel::HttpHandler
    attr_accessor :ui_port
    attr_reader :tables, :md
    
    def initialize(parent)
      @md = parent
      
      @tables = []
      @md.new_tables.each {|t| @tables << {:status => :new, :table => t}}
      @md.dropped_tables.each {|t| @tables << {:status => :drop, :table => t}}
      @md.changed_tables.each {|t| @tables << {:status => :change, :table => t}}
      
      @tables.sort! {|t1,t2| t1[:table] <=> t2[:table]}
    end
    
    def start        
      h = Mongrel::HttpServer.new("0.0.0.0", @ui_port)
      th = h.run
      open_browser
      th.join
    end
    
    def open_browser
      if File.directory?("/System")
        `open http://localhost:#{@ui_port}/`
      end
    end
  end
end