require 'Configuration'
require 'onedb_backend'
require 'onevc_backend'
require 'NodeType'
# require 'OpenNebula/Template'

module OpenNebula
    class VirtualCluster
    
        protected

        # client and id order is swapped
        def initialize(client, id=nil)
            read_onedconf
            @db = @backend.db
            @client = client
            @id = id
        end
    
        # Taken from onedb/onedb.rb
        def read_onedconf()
            config = Configuration.new("#{ETC_LOCATION}/oned.conf")

            if config[:db] == nil
                raise "No DB defined."
            end
        
            if config[:db]["BACKEND"].upcase.include? "SQLITE"
                sqlite_file = "#{VAR_LOCATION}/one.db"
                @backend = BackEndSQLite.new(sqlite_file)
            elsif config[:db]["BACKEND"].upcase.include? "MYSQL"
                @backend = BackEndMySQL.new(
                    :server  => config[:db]["SERVER"],
                    :port    => config[:db]["PORT"],
                    :user    => config[:db]["USER"],
                    :passwd  => config[:db]["PASSWD"],
                    :db_name => config[:db]["DB_NAME"]
                )
            else
                raise "Could not load DB configuration from " <<
                      "#{ETC_LOCATION}/oned.conf"
            end

            return 0
        end
    
        def create_node(config)
            node = NodeType.new(@client)
            node.allocate(@id, config)
        end
        
        def validate_node_types
            
        end
    
        public

        # TODO: Complete me
        def allocate(file)
            config = Configuration.new(file)
        
            # Create new VC in the database
            @db[:vc_pool].insert(
                :name => config[:VC_NAME].gsub(/^["|'](.*?)["|']$/,'\1'),
                :body => File.read(file)
            )
        
            # Set vcid for the instance
            @id = @db[:vc_pool].order(:oid.desc).first[:oid]
        
            config[:NODE_TYPE].each do |node_type|
                create_node(node_type)
            end
        
            return @id
        end
    
        # TODO: Resolve and use Node Type Hierachy
        def deploy()
            return Error.new('ID not defined') if !@id
            
            node_types = @db[:node_types].filter(:vcid=>@id).all
            node_types.each do |node_type|
                node_type = NodeType.new(@client, node_type[:oid])
                res = node_type.deploy("#{name()}-#{node_type.name}")
                if OpenNebula.is_error?(res)
                    return res
                end
            end
        end

        def id()
            @id
        end
        
        def name()
            if @name != nil
                return @name
            else
                return @db[:vc_pool].filter(:oid=>@id).first[:name]
            end
        end
    
        # Adapted from PoolElement.info and derevetives
        # Needed to make this class compatible with one_helper
        def info()
            @pe_id = @id.to_i if @id
            return nil
        end
    
    end
end