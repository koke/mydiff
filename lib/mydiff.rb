class MyDiff
  attr_accessor :newdb, :olddb
  attr_accessor :my
  
  def initialize(config)
    @my = Mysql::new(config[:host], config[:user], config[:password])
    @newdb = "#{config[:prefix]}_new"
    @olddb = "#{config[:prefix]}_old"  
  end
  
  def prepare!
    begin
      @my.query("DROP DATABASE #{@newdb}")
      @my.query("DROP DATABASE #{@olddb}")
    rescue
    end

    @my.query("CREATE DATABASE #{@newdb}")
    @my.query("CREATE DATABASE #{@olddb}")
  end
  
  def list_tables(db)
    @my.select_db(db)
    @my.list_tables
  end
  
  def new_tables
    ntables = list_tables(@newdb)
    otables = list_tables(@olddb)
    
    ntables.select {|t| not otables.include?(t) }
  end
  
  def dropped_tables
    ntables = list_tables(@newdb)
    otables = list_tables(@olddb)
    
    otables.select {|t| not ntables.include?(t) }
  end
  
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
      "n.#{f["Field"]} n_#{f["Field"]}"
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
  
  def fields_from(table)
    @my.select_db(@newdb)
    res = @my.query("DESCRIBE #{table}")
    fields = []
    while (field = res.fetch_hash)
      fields << field
    end
    
    fields
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