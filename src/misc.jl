mutable struct OmniSciConnection
    session::TSessionId
    c::MapDClient
end

#connect function to abstract away needing to build MapDClient
#user passes OmniSciConnection created from connect instead of individual pieces
#not strictly part of the mapd.thrift generated code
function connect(host::String, port::Int, user::String, passwd::String, dbname::String)

    socket = TSocket(host, port)

    #create libuv socket and keep-alive
    tcp = connect(host, port)
    err = ccall(:uv_tcp_keepalive, Cint, (Ptr{Nothing}, Cint, Cuint), tcp.handle, 1, 1)
    err != 0 && error("error setting keepalive on socket")

    Thrift.set_field!(socket, :io, tcp)
    #transport = TBufferedTransport(socket) # https://github.com/tanmaykm/Thrift.jl/issues/12
    proto = TBinaryProtocol(socket, false, true)
    c = OmniSci.MapDClient(proto)

    session = OmniSci.connect(c, user, passwd, dbname)

    return OmniSciConnection(session, c)

end

function load_buffer(handle::Vector{UInt8}, size::Int, own::Bool=false)

    # get key as UInt32, then get string value instead of len 1 array
    shmkey = reinterpret(UInt32, handle)[1]

    # use <sys/ipc.h> from C standard library to get shared memory id
    # validate that shmget returns a valid id
    shmid = ccall(:shmget, Cint, (Cuint, Int32, Int32), shmkey, size, 0)
    shmid == -1 ? error("Invalid shared memory key: $shmkey") : nothing

    # with shmid, get shared memory start address
    ptr = ccall(:shmat, Ptr{Nothing}, (Cint, Ptr{Nothing}, Cint), shmid, C_NULL, 0)

    # makes a zero-copy reference to memory, true gives ownership to julia
    # validate that memory no longer needs to be released using MapD methods
    return unsafe_wrap(Array, convert(Ptr{UInt8}, ptr), size, own = own)

end

######################################## connection, admin
disconnect(conn::OmniSciConnection) =
    disconnect(conn.c, conn.session) #consider printing to console that disconnection happened

get_status(conn::OmniSciConnection) =
    get_status(conn.c, conn.session)

get_hardware_info(conn::OmniSciConnection) =
    get_hardware_info(conn.c, conn.session)

get_tables(conn::OmniSciConnection) =
    get_tables(conn.c, conn.session)

get_physical_tables(conn::OmniSciConnection) =
    get_physical_tables(conn.c, conn.session)

get_views(conn::OmniSciConnection) =
    get_views(conn.c, conn.session)

get_tables_meta(conn::OmniSciConnection) =
    get_tables_meta(conn.c, conn.session)

get_table_details(conn::OmniSciConnection, table_name::String) =
    get_table_details(conn.c, conn.session, table_name)

get_users(conn::OmniSciConnection) =
    get_users(conn.c, conn.session)

get_databases(conn::OmniSciConnection) =
    get_databases(conn.c, conn.session)

get_version(conn::OmniSciConnection) =
    get_version(conn.c)

get_memory(conn::OmniSciConnection, memory_level::String) =
    get_memory(conn.c, conn.session, memory_level)

clear_cpu_memory(conn::OmniSciConnection) =
    clear_cpu_memory(conn.c, conn.session)

clear_gpu_memory(conn::OmniSciConnection) =
    clear_gpu_memory(conn.c, conn.session)

######################################## query, render

sql_execute(conn::OmniSciConnection, query::String, column_format::Bool, first_n::Int, at_most_n::Int) =
    sql_execute(conn.c, conn.session, query, column_format, randstring(32), Int32(first_n), Int32(at_most_n))

sql_execute_df(conn::OmniSciConnection, query::String, device_type::Int, device_id::Int, first_n::Int) =
    sql_execute_df(conn.c, conn.session, query, Int32(device_type), Int32(device_id), Int32(first_n))

sql_execute_gdf(conn::OmniSciConnection, query::String, device_id::Int, first_n::Int) =
    sql_execute_gdf(conn.c, conn.session, query, Int32(device_id), Int32(first_n))

deallocate_df(conn::OmniSciConnection, df::TDataFrame, device_type::Int, device_id::Int) =
    deallocate_df(conn.c, conn.session, df, Int32(device_type), Int32(device_id))

interrupt(conn::OmniSciConnection) =
    interrupt(conn.c, conn.session)

#need a try/catch with this? either returns data or exception
#seems almost like a true/false or internal function
sql_validate(conn::OmniSciConnection, query::String) =
    sql_validate(conn.c, conn.session, query)

set_execution_mode(conn::OmniSciConnection, mode::TExecuteMode.Enum) =
    set_execution_mode(conn.c, conn.session, mode.value)

render_vega(conn::OmniSciConnection, widget_id::Int, vega_json::String, compression_level::Int) =
    render_vega(conn.c, conn.session, Int64(widget_id), vega_json, Int32(compression_level), randstring(32))

######################################## dashboard

get_dashboard(conn::OmniSciConnection, dashboard_id::Int) =
    get_dashboard(conn.c, conn.session, Int32(dashboard_id))

get_dashboards(conn::OmniSciConnection) =
    get_dashboards(conn.c, conn.session)

create_dashboard(conn::OmniSciConnection, dashboard_name::String, dashboard_state::String, image_hash::String, dashboard_metadata::String) =
    create_dashboard(conn.c, conn.session, dashboard_name, dashboard_state, image_hash, dashboard_metadata)

replace_dashboard(conn::OmniSciConnection, dashboard_id::Int, dashboard_name::String, dashboard_owner::String, dashboard_state::String, image_hash::String, dashboard_metadata::String) =
    replace_dashboard(conn.c, conn.session, Int32(dashboard_id), dashboard_name, dashboard_owner, dashboard_state, image_hash, dashboard_metadata)

delete_dashboard(conn::OmniSciConnection, dashboard_id::Int) =
    delete_dashboard(conn.c, conn.session, Int32(dashboard_id))

share_dashboard(conn::OmniSciConnection, dashboard_id::Int, groups::Vector{String}, objects::Vector{String}, permissions::TDashboardPermissions) =
    share_dashboard(conn.c, conn.session, Int32(dashboard_id), groups, objects, permissions)

unshare_dashboard(conn::OmniSciConnection, dashboard_id::Int, groups::Vector{String}, objects::Vector{String}, permissions::TDashboardPermissions) =
    unshare_dashboard(conn.c, conn.session, Int32(dashboard_id), groups, objects, permissions)

get_dashboard_grantees(conn::OmniSciConnection, dashboard_id::Int) =
    get_dashboard_grantees(conn.c, conn.session, Int32(dashboard_id))

######################################## import

load_table_binary(conn::OmniSciConnection, table_name::String, rows::Vector{TRow}) =
    load_table_binary(conn.c, conn.session, table_name, rows)

load_table_binary_columnar(conn::OmniSciConnection, table_name::String, cols::Vector{TColumn}) =
    load_table_binary_columnar(conn.c, conn.session, table_name, cols)

load_table_binary_arrow(conn::OmniSciConnection, table_name::String, arrow_stream::Vector{UInt8}) =
    load_table_binary_arrow(conn.c, conn.session, table_name, arrow_stream)

load_table(conn::OmniSciConnection, table_name::String, rows::Vector{TStringRow}) =
    load_table(conn.c, conn.session, table_name, rows)

detect_column_types(conn::OmniSciConnection, file_name::String, copy_params::TCopyParams) =
    detect_column_types(conn.c, conn.session, file_name, copy_params)

create_table(conn::OmniSciConnection, table_name::String, row_desc::TRowDescriptor, table_type::TTableType.Enum) =
    create_table(conn.c, conn.session, table_name, row_desc, table_type.value)

import_table(conn::OmniSciConnection, table_name::String, file_name::String, copy_params::TCopyParams) =
    import_table(conn.c, conn.session, table_name, file_name, copy_params)

import_geo_table(conn::OmniSciConnection, table_name::String, file_name::String, copy_params::TCopyParams, row_desc::TRowDescriptor) =
    import_geo_table(conn.c, conn.session, table_name, file_name, copy_params, row_desc)

import_table_status(conn::OmniSciConnection, import_id::String) =
    import_table_status(conn.c, conn.session, import_id)

######################################## object privileges

get_roles(conn::OmniSciConnection) =
    get_dashboards(conn.c, conn.session)

get_db_objects_for_grantee(conn::OmniSciConnection, roleName::String) =
    get_db_objects_for_grantee(conn.c, conn.session, roleName)

get_db_object_privs(conn::OmniSciConnection, objectName::String, type_::Int) =
    get_db_object_privs(conn.c, conn.session, objectName, Int32(type_))

get_all_roles_for_user(conn::OmniSciConnection, userName::String) =
    get_all_roles_for_user(conn.c, conn.session, userName)

######################################## licensing

set_license_key(conn::OmniSciConnection, key::String) =
    set_license_key(conn.c, conn.session, key, randstring(32))

get_license_claims(conn::OmniSciConnection) =
    get_license_claims(conn.c, conn.session, randstring(32))
