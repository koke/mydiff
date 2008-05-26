$:.unshift File.dirname(__FILE__) 
 
require "mysql"
require "mydiff/cli"
require "mydiff/change"

# MyDiff helps you to apply changes from one MySQL database to another
#
# It has some helper methods to 
#
# Example
#
#  md = MyDiff.new(:host => "localhost", :user => "root", :newdb => "mydiff_new", :olddb => "mydiff_old") # => <MyDiff>
#  md.newdb           #=> "mydiff_new"
#  md.olddb           #=> "mydiff_old"
#  md.new_tables      #=> ["new_table1", "new_table2"]
#  md.dropped_tables  #=> ["old_table"]
class MyDiff
  VERSION = '0.0.2'
  
  # Name of the database with changes
  attr_accessor :newdb
  # Name of the current database. Changes will be applied here
  attr_accessor :olddb
  # Command Line Interface. See MyDiff::CLI
  attr_accessor :cli
  attr_accessor :my #:nodoc:
  
  # Creates a new MyDiff instance
  #
  # Config options
  # - <tt>:host</tt> - MySQL host
  # - <tt>:user</tt> - MySQL user
  # - <tt>:password</tt> - MySQL password
  # - <tt>:newdb</tt> - Name of the database with the changes to apply
  # - <tt>:olddb</tt> - Name of the database to apply the changes
  #
  # Returns MyDiff
  def initialize(config)
    @my = Mysql::new(config[:host], config[:user], config[:password])
    @newdb = config[:newdb]
    @olddb = config[:olddb]
    @cli = CLI.new(self)
    @fields = {}
  end
  
  # Recreates the new database
  # 
  # *WARNING*: This method drops and recreates the +newdb+ database, you may lose data!
  def prepare!
    begin
      @my.query("DROP DATABASE #{@newdb}")
    rescue
    end

    @my.query("CREATE DATABASE #{@newdb}")
  end
    
  # Returns an array with table names for the database given in +db+
  def list_tables(db)
    @my.select_db(db)
    @my.list_tables
  end
  
  # Returns an array with table names present on +newdb+ but not on +olddb+
  def new_tables
    ntables = list_tables(@newdb)
    otables = list_tables(@olddb)
    
    ntables.select {|t| not otables.include?(t) }
  end
  
  # Returns an array with table names present on +olddb+ but not on +newdb+
  def dropped_tables
    ntables = list_tables(@newdb)
    otables = list_tables(@olddb)
    
    otables.select {|t| not ntables.include?(t) }
  end
  
  # Returns an array with table names present on +newdb+ and +olddb+ which 
  # are different in content
  def changed_tables
    ntables = list_tables(@newdb)
    otables = list_tables(@olddb)
    
    ntables.select {|t| otables.include?(t) and table_changed?(t) }
  end
  
  # Returns an array with rows present in +newdb+ but not in +olddb+, using the +table+ given
  def new_rows(table)
    fields = fields_from(table)
    pkey, fields = extract_pkey_from(fields)
    my.select_db(@newdb)
    
    query = "SELECT "
    query << pkey.collect do |f|
      "n.#{f["Field"]} #{f["Field"]}"
    end.join(",")
    query << ","
    query << fields.collect do |f|
      "n.#{f["Field"]} n_#{f["Field"]}"
    end.join(",")
    
    query << " FROM #{@newdb}.#{table} AS n LEFT JOIN #{@olddb}.#{table} AS o ON "
    query << pkey.collect do |f|
      "n.#{f["Field"]} = o.#{f["Field"]}"
    end.join(" AND ")
    query << " WHERE "
    query << pkey.collect do |f|
      "o.#{f["Field"]} IS NULL"
    end.join(" AND ")
    
    result = my.query(query)
    new_rows = []
    while row = result.fetch_hash
      new_rows << row
    end
    new_rows
  end

  def deleted_rows(table)
    fields = fields_from(table)
    pkey, fields = extract_pkey_from(fields)
    my.select_db(@olddb)
    
    query = "SELECT "
    query << pkey.collect do |f|
      "o.#{f["Field"]} #{f["Field"]}"
    end.join(",")
    query << ","
    query << fields.collect do |f|
      "o.#{f["Field"]} o_#{f["Field"]}"
    end.join(",")
    
    query << " FROM #{@olddb}.#{table} AS o LEFT JOIN #{@newdb}.#{table} AS n ON "
    query << pkey.collect do |f|
      "n.#{f["Field"]} = o.#{f["Field"]}"
    end.join(" AND ")
    query << " WHERE "
    query << pkey.collect do |f|
      "n.#{f["Field"]} IS NULL"
    end.join(" AND ")
    
    result = my.query(query)
    deleted_rows = []
    while row = result.fetch_hash
      deleted_rows << row
    end
    deleted_rows
  end

  def changed_rows(table)
    fields = fields_from(table)
    pkey, fields = extract_pkey_from(fields)
    my.select_db(@olddb)
    
    query = "SELECT "
    query << pkey.collect do |f|
      "o.#{f["Field"]} #{f["Field"]}"
    end.join(",")
    query << ","
    query << fields.collect do |f|
      "o.#{f["Field"]} o_#{f["Field"]}, n.#{f["Field"]} n_#{f["Field"]}"
    end.join(",")
    
    query << " FROM #{@olddb}.#{table} AS o INNER JOIN #{@newdb}.#{table} AS n ON "
    query << pkey.collect do |f|
      "n.#{f["Field"]} = o.#{f["Field"]}"
    end.join(" AND ")
    
    unless fields.empty?
      query << " WHERE "
      query << fields.collect do |f|
        "n.#{f["Field"]} <> o.#{f["Field"]}"
      end.join(" OR ")
    end
    
    result = my.query(query)
    changed_rows = []
    while row = result.fetch_hash
      changed_rows << row
    end
    
    changed_rows
  end
  
  def fields_from(table)
    return @fields[table] if @fields[table]
    @my.select_db(@newdb)
    res = @my.query("DESCRIBE #{table}")
    fields = []
    while (field = res.fetch_hash)
      fields << field
    end
    
    @fields[table] ||= fields
  end  
  
  def count_rows(db, table)
    @my.select_db(db)
    res = @my.query("SELECT COUNT(*) FROM #{table}")
    res.fetch_row[0]
  end
  
  def extract_pkey_from(fields)
    fields.partition {|f| f["Key"] == "PRI" }    
  end
  
  def pkey_of(table)
    fields_from(table).select {|f| f["Key"] == "PRI"}.map {|f| f["Field"]}
  end

  def data_fields_of(table)
    fields_from(table).select {|f| f["Key"] != "PRI"}.map {|f| f["Field"]}
  end
  
  def checksum_table(db, table)
    @my.select_db(db)
    @my.query("CHECKSUM TABLE #{table}").fetch_row[1]
  end
  
  def table_changed?(table)
    checksum_table(@olddb, table) != checksum_table(@newdb, table)
  end
  
  def select_new
    @my.select_db(@newdb)
  end
  
  def select_old
    @my.select_db(@olddb)
  end  
end