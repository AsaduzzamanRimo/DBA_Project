SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*

	Description:	Lists active connections 
					Some system sessions may not have connection records, use spReport_Active_Sessions instead

*/
CREATE OR ALTER PROCEDURE [dbo].[spReport_Active_Connections] 
	@argHost_Name VARCHAR(128), @argProgram_Name VARCHAR(128), @argLogin_Name VARCHAR(128), @argDB_Name VARCHAR(128)
AS
BEGIN
	SELECT
			S.session_id, S.[host_name], C.client_net_address, S.[program_name], DB_NAME(L.DatabaseId) AS DatabaseName,
			S.login_name, S.original_login_name, '''' + CONVERT(VARCHAR(100), S.login_time, 121)     AS login_time,
			'''' + CONVERT(VARCHAR(100), S.last_request_start_time, 121)                             AS last_request_start_time, S.[status], R.command,
			R.blocking_session_id, R.open_transaction_count, R.wait_type, S.is_user_process,
			S.host_process_id                                                                        AS [client_process_id],
			dbo.fnTransactionIsolationLevel_Description(S.transaction_isolation_level, L.DatabaseId) AS transaction_isolation_level,
			C.net_transport, S.client_interface_name, C.protocol_type,
			CONVERT(VARCHAR(20), CAST(C.protocol_version AS BINARY(4)), 1)                           AS protocol_version,
			S.group_id                                                                               AS workload_group_id, CAST(S.context_info AS VARCHAR(128)) AS context_info
	FROM    sys.dm_exec_sessions    S WITH (NOLOCK)
		INNER JOIN	sys.dm_exec_connections C WITH (NOLOCK) ON S.session_id = C.session_id AND  C.parent_connection_id IS NULL --Only Main Connections, Exclude MARS Sessions (parent_connection_id)
		LEFT OUTER JOIN sys.dm_exec_requests    R WITH (NOLOCK) ON R.session_id = S.session_id
		OUTER APPLY  (
							SELECT
									IIF(ISNULL(MAX(L.resource_database_id), 0) <> 0,
										MAX(L.resource_database_id),
										IIF(ISNULL(R.database_id, 0) <> 0, R.database_id, NULLIF(S.database_id, 0))) AS DatabaseId
							FROM    sys.dm_tran_locks L WITH (NOLOCK)
							WHERE   L.request_session_id = S.session_id
						)                       L
	WHERE  ([host_name] LIKE @argHost_Name OR  @argHost_Name IS NULL)
		AND
		([program_name] LIKE @argProgram_Name OR  @argProgram_Name IS NULL)
		AND
		(login_name LIKE @argLogin_Name OR  @argLogin_Name IS NULL)
		AND
		(DB_NAME(L.DatabaseId) LIKE @argDB_Name OR  @argDB_Name IS NULL)
	ORDER BY S.session_id;
END
