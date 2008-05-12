$:.unshift File.dirname(__FILE__) 
 
require "mysql"
require "mydiff/cli"

# MyDiff helps you to apply changes from one MySQL database to another
class MyDiff
  attr_accessor :newdb, :olddb
  attr_accessor :my, :cli
  
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
    @newdb = "#{config[:prefix]}_new"
    @olddb = "#{config[:prefix]}_old"  
    @cli = CLI.new(self)
    @fields = {}
  end
  
  # Recreates the new database
  # 
  # *WARNING*: This method drops and recreates the +newdb+ database, you may lose data!
  def prepare!
    begin
      @my.query("DROP DATABASE #{@newdb}")
      # @my.query("DROP DATABASE #{@olddb}")
    rescue
    end

    @my.query("CREATE DATABASE #{@newdb}")
    # @my.query("CREATE DATABASE #{@olddb}")
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
    
    result = my.query(query)
    changed_rows = []
    while row = result.fetch_hash
      changed_rows << row
    end
    changed_rows.select do |row|
      fields.inject(true) do |s,f|
        s and row["o_#{f["Field"]}"] = row["n_#{f["Field"]}"]
      end
    end
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
  
  def checksum_table(db, table)
    @my.select_db(db)
    @my.query("CHECKSUM TABLE #{table}").fetch_row[1]
  end
  
  def table_changed?(table)
    checksum_table(@olddb, table) != checksum_table(@newdb, table)
  end
end