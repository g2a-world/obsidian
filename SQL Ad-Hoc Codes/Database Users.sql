SET NOCOUNT ON
GO

select '--- '+@@SERVERNAME+'   '+db_name()

-------------------------------------------------------------
----Databases users and roles
DECLARE @SQLStatement NVARCHAR(4000) 
DECLARE @T_DBuser TABLE (dbname SYSNAME, UserName SYSNAME, AssociatedDBRole NVARCHAR(256), LoginName nvarchar(256), Type nvarchar(256))
SET @SQLStatement='
SELECT db_name() AS DBName,dp.name AS UserName,USER_NAME(drm.role_principal_id) AS AssociatedDBRole , sp.name as LoginName, dp.type as Type
FROM sys.database_principals dp
LEFT OUTER JOIN sys.database_role_members drm ON dp.principal_id=drm.member_principal_id 
left outer join sys.server_principals sp on sp.sid = dp.sid
WHERE dp.sid NOT IN (0x01) 
AND dp.sid IS NOT NULL 
AND dp.type NOT IN (''C'') 
AND dp.is_fixed_role <> 1 
AND dp.name NOT LIKE ''##%'' 
AND ''?'' NOT IN (''master'',''msdb'',''model'',''tempdb'') 
and NOT (dp.type = ''R'' and dp.name = ''public'')
ORDER BY DBName
'
INSERT @T_DBuser
exec sp_executesql @SQLStatement
--- EXEC sp_MSforeachdb @SQLStatement
--- SELECT * FROM @T_DBuser ORDER BY DBName

SELECT distinct 'USE ['+coalesce(dbname,'xxxx')+']; CREATE USER ['+coalesce(UserName,'xxxx')+'] FOR LOGIN ['+coalesce(LoginName,'xxxx')+']'
FROM @T_DBuser where UserName is not null and LoginName is not null
ORDER BY 1 

SELECT distinct 'USE ['+coalesce(dbname,'xxxx')+']; CREATE ROLE ['+coalesce(UserName,'xxxx')+']'
FROM @T_DBuser where UserName is not null and Type = 'R'
ORDER BY 1 

SELECT 'USE ['+dbname+']; ALTER ROLE ['+AssociatedDBRole+'] ADD MEMBER ['+UserName+']'
FROM @T_DBuser where UserName is not null and AssociatedDBRole is not null
ORDER BY dbname
 
select 'GO'

--------------------------------------------------------------
select 'sp_change_users_login ''auto_fix'','''+name+'''
GO'
from sysusers
where issqluser = 1 and hasdbaccess = 1
and name not in ('dbo','sys')




/***
--https://dbaeyes.wordpress.com/2013/04/19/fully-script-out-a-mssql-database-role/
****/

set nocount on

DECLARE @crlf VARCHAR(2)
SET @crlf = CHAR(13) + CHAR(10)

SELECT  convert (VARCHAR(500),
		'USE ['+db_name()+']; '+  
        CASE dp.state
            WHEN 'D' THEN 'DENY '
            WHEN 'G' THEN 'GRANT '
            WHEN 'R' THEN 'REVOKE '
            WHEN 'W' THEN 'GRANT '
        END + 
        dp.permission_name + ' ' +
        CASE dp.class
            WHEN 0 THEN ''
            WHEN 1 THEN --table or column subset on the table
                CASE WHEN dp.major_id < 0 THEN
                    + 'ON [sys].[' + OBJECT_NAME(dp.major_id) + '] '
                ELSE
                    + 'ON [' +
                    (SELECT SCHEMA_NAME(schema_id) + '].[' + name FROM sys.objects WHERE object_id = dp.major_id)
                        + -- optionally concatenate column names
                    CASE WHEN MAX(dp.minor_id) > 0 
                         THEN '] ([' + REPLACE(
                                        (SELECT name + '], [' 
                                         FROM sys.columns 
                                         WHERE object_id = dp.major_id 
                                            AND column_id IN (SELECT minor_id 
                                                              FROM sys.database_permissions 
                                                              WHERE major_id = dp.major_id
                                                                ----AND USER_NAME(grantee_principal_id) IN (@roleName)
                                                             )
                                         FOR XML PATH('')
                                        ) --replace final square bracket pair
                                    + '])', ', []', '')
                         ELSE ']'
                    END + ' '
                END
            WHEN 3 THEN 'ON SCHEMA::[' + SCHEMA_NAME(dp.major_id) + '] '
            WHEN 4 THEN 'ON ' + (SELECT RIGHT(type_desc, 4) + '::[' + name FROM sys.database_principals WHERE principal_id = dp.major_id) + '] '
            WHEN 5 THEN 'ON ASSEMBLY::[' + (SELECT name FROM sys.assemblies WHERE assembly_id = dp.major_id) + '] '
            WHEN 6 THEN 'ON TYPE::[' + (SELECT name FROM sys.types WHERE user_type_id = dp.major_id) + '] '
            WHEN 10 THEN 'ON XML SCHEMA COLLECTION::[' + (SELECT SCHEMA_NAME(schema_id) + '.' + name FROM sys.xml_schema_collections WHERE xml_collection_id = dp.major_id) + '] '
            WHEN 15 THEN 'ON MESSAGE TYPE::[' + (SELECT name FROM sys.service_message_types WHERE message_type_id = dp.major_id) + '] '
            WHEN 16 THEN 'ON CONTRACT::[' + (SELECT name FROM sys.service_contracts WHERE service_contract_id = dp.major_id) + '] '
            WHEN 17 THEN 'ON SERVICE::[' + (SELECT name FROM sys.services WHERE service_id = dp.major_id) + '] '
            WHEN 18 THEN 'ON REMOTE SERVICE BINDING::[' + (SELECT name FROM sys.remote_service_bindings WHERE remote_service_binding_id = dp.major_id) + '] '
            WHEN 19 THEN 'ON ROUTE::[' + (SELECT name FROM sys.routes WHERE route_id = dp.major_id) + '] '
            WHEN 23 THEN 'ON FULLTEXT CATALOG::[' + (SELECT name FROM sys.fulltext_catalogs WHERE fulltext_catalog_id = dp.major_id) + '] '
            WHEN 24 THEN 'ON SYMMETRIC KEY::[' + (SELECT name FROM sys.symmetric_keys WHERE symmetric_key_id = dp.major_id) + '] '
            WHEN 25 THEN 'ON CERTIFICATE::[' + (SELECT name FROM sys.certificates WHERE certificate_id = dp.major_id) + '] '
            WHEN 26 THEN 'ON ASYMMETRIC KEY::[' + (SELECT name FROM sys.asymmetric_keys WHERE asymmetric_key_id = dp.major_id) + '] '
         END COLLATE SQL_Latin1_General_CP1_CI_AS
         + 'TO [' + USER_NAME(dp.grantee_principal_id) + ']' + 
         CASE dp.state WHEN 'W' THEN ' WITH GRANT OPTION' ELSE '' END
		 ) as stmt

----------------------------------------------------------------

,CASE dp.state
            WHEN 'D' THEN 'DENY '
            WHEN 'G' THEN 'GRANT '
            WHEN 'R' THEN 'REVOKE '
            WHEN 'W' THEN 'GRANT '
        END as state_type
,dp.permission_name
,(CASE dp.class
            WHEN 0 THEN ''
            WHEN 1 THEN --table or column subset on the table
                CASE WHEN dp.major_id < 0 THEN
                    + '[sys].[' + OBJECT_NAME(dp.major_id) + '] '
                ELSE
                    + '[' +
                    (SELECT SCHEMA_NAME(schema_id) + '].[' + name FROM sys.objects WHERE object_id = dp.major_id)
                        + -- optionally concatenate column names
                    CASE WHEN MAX(dp.minor_id) > 0 
                         THEN '] ([' + REPLACE(
                                        (SELECT name + '], [' 
                                         FROM sys.columns 
                                         WHERE object_id = dp.major_id 
                                            AND column_id IN (SELECT minor_id 
                                                              FROM sys.database_permissions 
                                                              WHERE major_id = dp.major_id
                                                                ----AND USER_NAME(grantee_principal_id) IN (@roleName)
                                                             )
                                         FOR XML PATH('')
                                        ) --replace final square bracket pair
                                    + '])', ', []', '')
                         ELSE ']'
                    END + ' '
                END
            WHEN 3 THEN 'SCHEMA::[' + SCHEMA_NAME(dp.major_id) + '] '
            WHEN 4 THEN '' + (SELECT RIGHT(type_desc, 4) + '::[' + name FROM sys.database_principals WHERE principal_id = dp.major_id) + '] '
            WHEN 5 THEN 'ASSEMBLY::[' + (SELECT name FROM sys.assemblies WHERE assembly_id = dp.major_id) + '] '
            WHEN 6 THEN 'TYPE::[' + (SELECT name FROM sys.types WHERE user_type_id = dp.major_id) + '] '
            WHEN 10 THEN 'XML SCHEMA COLLECTION::[' + (SELECT SCHEMA_NAME(schema_id) + '.' + name FROM sys.xml_schema_collections WHERE xml_collection_id = dp.major_id) + '] '
            WHEN 15 THEN 'MESSAGE TYPE::[' + (SELECT name FROM sys.service_message_types WHERE message_type_id = dp.major_id) + '] '
            WHEN 16 THEN 'CONTRACT::[' + (SELECT name FROM sys.service_contracts WHERE service_contract_id = dp.major_id) + '] '
            WHEN 17 THEN 'SERVICE::[' + (SELECT name FROM sys.services WHERE service_id = dp.major_id) + '] '
            WHEN 18 THEN 'REMOTE SERVICE BINDING::[' + (SELECT name FROM sys.remote_service_bindings WHERE remote_service_binding_id = dp.major_id) + '] '
            WHEN 19 THEN 'ROUTE::[' + (SELECT name FROM sys.routes WHERE route_id = dp.major_id) + '] '
            WHEN 23 THEN 'FULLTEXT CATALOG::[' + (SELECT name FROM sys.fulltext_catalogs WHERE fulltext_catalog_id = dp.major_id) + '] '
            WHEN 24 THEN 'SYMMETRIC KEY::[' + (SELECT name FROM sys.symmetric_keys WHERE symmetric_key_id = dp.major_id) + '] '
            WHEN 25 THEN 'CERTIFICATE::[' + (SELECT name FROM sys.certificates WHERE certificate_id = dp.major_id) + '] '
            WHEN 26 THEN 'ASYMMETRIC KEY::[' + (SELECT name FROM sys.asymmetric_keys WHERE asymmetric_key_id = dp.major_id) + '] '
         END COLLATE SQL_Latin1_General_CP1_CI_AS
) as class
,('[' + USER_NAME(dp.grantee_principal_id) + ']') as target

----------------------------------------------------------------
into #tempind
FROM    sys.database_permissions dp
---WHERE    USER_NAME(dp.grantee_principal_id) IN (@roleName)
where USER_NAME(dp.grantee_principal_id) not in ('public')
and USER_NAME(dp.grantee_principal_id) not like 'db_%'
GROUP BY dp.state, dp.major_id, dp.permission_name, dp.class, dp.grantee_principal_id

/******
SELECT	 coalesce(('EXECUTE sp_AddRoleMember ''' + roles.name + ''', ''' + users.name + '''') ,'') 
+'   --- role: '+coalesce(users.name,'')+'  user: '+coalesce(roles.name,'')
FROM	sys.database_principals users
		LEFT JOIN sys.database_role_members link 
			ON link.member_principal_id = users.principal_id
		LEFT JOIN sys.database_principals roles 
			ON roles.principal_id = link.role_principal_id
********/

select stmt as [--stmt] from #tempind

drop table #tempind
