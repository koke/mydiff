require "highline"

class MyDiff
  class CLI < HighLine
    def initialize(parent)
      @md = parent
      super()
    end
    
    def main_menu
      while true
        choose do |menu|
          menu.prompt = "What now?"
          
          menu.choice("Status") { status }
          menu.choice("Quit") { exit }
        end
      end
    end
    
    def status
      say "New tables"
      say "----------"
      count = 1
      @md.new_tables.each do |table|
        say "%2d. +%-4d    %s" % [count, @md.count_rows(@md.newdb, table), table]
        count += 1
      end
      
      say "Dropped tables"
      say "--------------"
      @md.dropped_tables.each do |table|
        say "%2d. -%-4d    %s" % [count, @md.count_rows(@md.olddb, table), table]
        count += 1
      end
      
      say "Changed tables"
      say "--------------"
      @md.changed_tables.each do |table|
        new_rows = @md.new_rows(table).size
        deleted_rows = @md.deleted_rows(table).size
        changed_rows = @md.changed_rows(table).size
        new_rows += changed_rows
        deleted_rows += changed_rows
        changed_rows = "+#{new_rows}/-#{deleted_rows}"
        say "%2d. %8s    %s" % [count, changed_rows, table]
        count += 1
      end
      
      
    end
  end
end