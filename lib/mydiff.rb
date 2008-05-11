class MyDiff
  attr_accessor :newdb, :olddb
  attr_accessor :my
  
  def initialize(config)
    @my = my = Mysql::new(config[:host], config[:user], config[:password])
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
    
    ntables.select {|t| otables.include?(t) }
  end
  
end