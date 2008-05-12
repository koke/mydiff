require "yaml"

class MyDiff
  # Represents one change to apply to the database
  class Change
    # Can be one of <tt>:new</tt>, <tt>:drop</tt>, <tt>:overwrite</tt> or <tt>:patch</tt>
    attr_accessor :type
    attr_accessor :chunks
    
    # Create a new change for a specific table
    #
    # +parent+:: the MyDiff parent class
    # +type+:: one of <tt>:new</tt>, <tt>:drop</tt>, <tt>:overwrite</tt> or <tt>:patch</tt>
    # +table+:: the table to change
    def initialize(parent, type, table)
      @md = parent
      @type = type
      @table = table
      @chunks = {}
    end
    
    # Adds a chunk to apply in the change. 
    #
    # +type+:: can be either <tt>:new</tt>, <tt>:delete</tt> or <tt>:change</tt>
    # +pkey+:: should be a hash containing primary key fields
    # +fields+:: should be a hash containint the fields not belonging to primary key (only for +type+ = <tt>:new</tt> or <tt>:change</tt>)
    def add_chunk(type, pkey, fields = {})
      raise ArgumentError, "Chunks can be added only if type is :patch" unless @type.eql?(:patch)
      @chunks[pkey.to_yaml] = { :type => type, :pkey => pkey, :fields => fields}
    end
    
    def delete_chunk(pkey)
      @chunks.delete(pkey.to_yaml)
    end
    
    def get_chunk(pkey)
      @chunks[pkey.to_yaml]
    end
    
    def has_chunk?(pkey)
      @chunks.has_key?(pkey.to_yaml)
    end
    
    def apply!
      if @type.eql?(:new)
        puts "** Creating #{@table}"
        @md.select_old
        @md.my.query("CREATE TABLE #{@table} LIKE #{@md.newdb}.#{@table}")
        @md.my.query("INSERT INTO #{@table} SELECT * FROM #{@md.newdb}.#{@table}")
      elsif @type.eql?(:drop)
        puts "** Dropping table #{@table}"
        @md.select_old
        @md.my.query("DROP TABLE #{@table}")
      elsif @type.eql?(:overwrite)
        raise NotImplementedError, "Type :overwrite is not yet in use"
      elsif @type.eql?(:patch)
        printf "** Updating table #{@table}"
        @chunks.each_pair do |pkey, data|
          printf "."
          @md.select_old
          if data[:type].eql?(:new)
            field_list = []
            data_list = []
            data[:pkey].each_pair do |k,v|
              field_list << k
              data_list << "'" + @md.my.escape_string(v) + "'"
            end
            data[:fields].each_pair do |k,v|
              field_list << k
              data_list << "'" + @md.my.escape_string(v) + "'"
            end
            
            puts("INSERT INTO #{@table} (#{field_list.join(',')}) VALUES(#{data_list.join(',')})") if $DEBUG
            @md.my.query("INSERT INTO #{@table} (#{field_list.join(',')}) VALUES(#{data_list.join(',')})")
          elsif data[:type].eql?(:change)
            changes_list = []
            pkey_list = []
            data[:pkey].each_pair do |k,v|
              pkey_list << "#{k} = '" + @md.my.escape_string(v) + "'"
            end
            data[:fields].each_pair do |k,v|
              changes_list << "#{k} = '" + @md.my.escape_string(v) + "'"
            end
            
            puts("UPDATE #{@table} SET #{changes_list.join(',')} WHERE #{pkey_list.join(' AND ')}") if $DEBUG
            @md.my.query("UPDATE #{@table} SET #{changes_list.join(',')} WHERE #{pkey_list.join(' AND ')}")
          elsif data[:type].eql?(:delete)
            pkey_list = []
            data[:pkey].each_pair do |k,v|
              pkey_list << "#{k} = '" + @md.my.escape_string(v) + "'"
            end
            puts("DELETE FROM #{@table} WHERE #{pkey_list.join(' AND ')}") if $DEBUG
            @md.my.query("DELETE FROM #{@table} WHERE #{pkey_list.join(' AND ')}")
          else
            raise NotImplementedError, "Invalid chunk type: #{data[:type]}"
          end
        end
        
        puts
      else
        raise NotImplementedError, "Invalid type #{@type.to_s}"
      end
    end
  end
end