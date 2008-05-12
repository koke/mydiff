require "highline"

class MyDiff
  class CLI < HighLine
    def initialize(parent)
      @md = parent
      @tables = []
      @md.new_tables.each {|t| @tables << {:status => :new, :table => t}}
      @md.dropped_tables.each {|t| @tables << {:status => :drop, :table => t}}
      @md.changed_tables.each {|t| @tables << {:status => :change, :table => t}}
      
      @tables.sort! {|t1,t2| t1[:table] <=> t2[:table]}
      @changes = {}
      super()
    end
    
    def main_menu
      continue = true
      begin
        while continue
          choose do |menu|
            menu.prompt = "What now?"
          
            menu.choice("Status") { status }
            menu.choice("Accept") { accept }
            menu.choice("Reject") { reject }
            menu.choice("Patch")  { patch  }
            menu.choice("Apply")  { apply! }
            menu.choice("Quit")   { continue = false }
          end
        end
      rescue Interrupt
      end
    end
    
    def status(type = :all)
      type = [type] unless type.is_a?(Array)
      @tables.each_with_index do |table, count|
        if type.include?(:all) or type.include?(table[:status])
          render_row(count, table[:table], table[:status])
        end
      end
    end
    
    def accept
      submenu do |table|
        change = @changes[table[:table]]
        if change #and change.type.eql?(:patch)
          @changes.delete(table[:table])
        end
        @changes[table[:table]] = Change.new(@md, :add, table[:table])
      end
    end

    def reject
      submenu do |table|
        change = @changes[table[:table]]
        if change #and change.type.eql?(:patch)
          @changes.delete(table[:table])
        end
      end
    end
    
    def patch
      submenu([:change, :new]) do |table|
        continue = true
        while continue
          rows = []
          @md.deleted_rows(table[:table]).each {|r| rows << {:status => :delete, :row => r}}
          @md.changed_rows(table[:table]).each {|r| rows << {:status => :change, :row => r}}
          @md.new_rows(table[:table]).each {|r| rows << {:status => :new, :row => r}}
          rows.each_with_index do |row, count|
            status = row[:status]
            row = row[:row]
            pkey = {}
            @md.pkey_of(table[:table]).each do |f|
              pkey[f] = row[f]
            end
            ndata = @md.data_fields_of(table[:table]).map do |f|
              row["n_#{f}"]
            end
            odata = @md.data_fields_of(table[:table]).map do |f|
              row["o_#{f}"]
            end
            
            begin
              if @changes[table[:table]].has_chunk?(pkey)
                status = "*"
              else
                status = " "
              end
            rescue
              status = " "
            end
            say ""
            say "%2d. [%s] (%s) %s" % [count, status, pkey.values.join("||"), odata.join("||")]
            puts "    [%s] (%s) %s" % [status, pkey.values.join("||"), ndata.join("||")]            
            
          end
          
          opt = ask "Which one?"
          if opt.empty? or opt.downcase.eql?("q")
            continue = false
          else
            if opt =~ /(\d+)-(\d+)/
              opts = ($1..$2).to_a
            elsif opt =~ /(\d+)/
              opts = [$1]
            end
            opts.each do |opt|
              row = rows[opt.to_i]
              if row.nil? or not opt =~ /[0-9+]/
                say "Wrong answer!"
                next
              end
              change = @changes[table[:table]]
              if (change and not change.type.eql?(:patch)) or not change
                @changes.delete(table[:table])
                change = Change.new(@md, :patch, table[:table])
              end

              pkey = {}
              @md.pkey_of(table[:table]).each do |f|
                pkey[f] = row[:row][f]
              end
              if change.has_chunk?(pkey)
                change.delete_chunk(pkey)
              else
                data = {}
                @md.data_fields_of(table[:table]).each do |f|
                  data[f] = row[:row]["n_#{f}"]
                end
                change.add_chunk(row[:status], pkey, data)
              end

              @changes[table[:table]] = change
              if change.chunks.empty?
                @changes.delete(table[:table])
              end              
            end
          end
        end
      end      
    end
    
    def apply!
      @changes.each_value do |change|
        change.apply!
      end
    end
    
    private
    def submenu(type = :all)
      continue = true
      while continue
        status(type)
        opt = ask "Which one?"
        if opt.empty? or opt.downcase.eql?("q")
          continue = false
        else
          if opt =~ /(\d+)-(\d+)/
            opts = ($1..$2).to_a
          elsif opt =~ /(\d+)/
            opts = [$1]
          end
          opts.each do |opt|
            table = @tables[opt.to_i]
            if table.nil? or not opt =~ /[0-9+]/
              say "Wrong answer!"
              next
            end
            yield table
          end
        end
      end
    end
    
    def render_row(count, table, status)
      if @changes.has_key?(table)
        if @changes[table].type.eql?(:patch)
          change = "/"
        else
          change = "*"
        end
      else
        change = " "
      end
      
      if status.eql?(:new)
        say "%2d. [%s] N  %8d    %s" % [count, change, "+" + @md.count_rows(@md.newdb, table), table]
      elsif status.eql?(:drop)
        say "%2d. [%s] D  %8d    %s" % [count, change, "-" + @md.count_rows(@md.olddb, table), table]
      elsif status.eql?(:change)
        new_rows = @md.new_rows(table).size
        deleted_rows = @md.deleted_rows(table).size
        changed_rows = @md.changed_rows(table).size
        new_rows += changed_rows
        deleted_rows += changed_rows
        changed_rows = "+#{new_rows}/-#{deleted_rows}"
        say "%2d. [%s] C  %8s    %s" % [count, change, changed_rows, table]
      end
    end    
  end
end