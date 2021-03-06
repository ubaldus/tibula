-- Copyright (C) 2007-2021 by Ubaldo Porcheddu <ubaldo@eja.it>
--
-- Prelude Op. 23 No. 5


eja.help.tibulaEngine="db engine (maria|mysql|sqlite3) {maria}";
eja.help.tibulaUsername="db username";
eja.help.tibulaPassword="db password";
eja.help.tibulaHostname="db hostname";
eja.help.tibulaDatabase="db name";

tibulaSqlEngine=nil;
tibulaSqlConnection=nil;


function tibulaSqlCheck()	--check if an sql connection has been already established otherwise try to start it
 if not tibulaSqlConnection or not tibulaSqlRun([[SELECT COUNT(*) FROM ejaSessions;]]) then 
  tibulaSqlStart(eja.opt.tibulaEngine, eja.opt.tibulaUsername, eja.opt.tibulaPassword, eja.opt.tibulaHostname, eja.opt.tibulaDatabase);
 end
 return tibulaSqlConnection;
end


function tibulaSqlStart(sqlEngine, sqlUsername, sqlPassword, sqlHostname, sqlDatabase)	--start sql connection
 local sql={}
 sql.engine=sqlEngine or eja.opt.tibulaEngine;
 sql.username=sqlUsername or eja.opt.tibulaUsername; 
 sql.password=sqlPassword or eja.opt.tibulaPassword;
 sql.hostname=sqlHostname or eja.opt.tibulaHostname;
 sql.database=sqlDatabase or eja.opt.tibulaDatabase;

 if not sql.username and not sql.password and not sql.database then
  sql=ejaJsonDecode(ejaString(ejaFileRead(eja.pathEtc.."eja.tibula.json")));
 end
 
 tibulaSqlEngine=sql.engine or "maria";

 if tibulaSqlEngine == "maria" and eja.maria then
  eja.sql=ejaMaria();
 elseif ejaModuleCheck("luasql."..tibulaSqlEngine) then 
  if tibulaSqlEngine == "sqlite3" then eja.sql=require "luasql.sqlite3"; end
  if tibulaSqlEngine == "mysql" then eja.sql=require "luasql.mysql"; end
 else
  ejaError([[[sql] %s library missing]], tibulaSqlEngine);
  return nil;
 end

 if eja.sql then 
  if tibulaSqlEngine == "maria" then tibulaSqlConnection=ejaMariaOpen(sql.hostname, 3306, sql.username, sql.password, sql.database); end
  if tibulaSqlEngine == "mysql" then tibulaSqlConnection=eja.sql.mysql():connect(sql.database, sql.username, sql.password, sql.hostname); end
  if tibulaSqlEngine == "sqlite3" then tibulaSqlConnection=eja.sql.sqlite3():connect(sql.database); end
 end

 if tibulaSqlConnection then 
  ejaDebug([[[sql] %s connection open]], tibulaSqlEngine);
  if tibulaSqlEngine == "maria" or tibulaSqlEngine == "mysql" then
   tibulaSqlRun([[SET SESSION sql_mode = '';]]);
  end
  if tibulaSqlEngine == "sqlite3" then
   tibulaSqlRun([[PRAGMA journal_mode = MEMORY;]]);
   tibulaSqlRun([[PRAGMA temp_store = MEMORY;]]);
   if ejaString(sql.password) ~= "" then tibulaSqlRun([[PRAGMA key = '%s';]], sql.password); end
  end
 else
  ejaError([[[sql] %s connection error]], tibulaSqlEngine);
 end

 return tibulaSqlConnection;   
end


function tibulaSqlStop()	--stop sql connection
 ejaDebug([[[sql] %s connection closed]], tibulaSqlEngine);
 if tibulaSqlEngine == "maria" then 
  return ejaMariaClose(); 
 end
 if tibulaSqlEngine == "mysql" or tibulaSqlEngine == "sqlite3" then
  return tibulaSqlConnection:close(); 
 end
end


function tibulaSqlMatrix(query, ...)	--sql multi rows array
 query=tibulaSqlQuery(query, ...);

 local row={}; 
 local rows={};
 if tibulaSqlEngine == "maria" then
  rows=ejaMariaQuery(query);
  local cols={};
  for rk,rv in next,getmetatable(rows) do
   for rvk,rvv in next,rv do
    if rvk == "name" then cols[#cols+1]=rvv; end
   end
  end
  setmetatable(rows, cols);
 else
  local cur=tibulaSqlConnection:execute(query);
  if cur then
   setmetatable(rows, cur:getcolnames(row));
   row=cur:fetch({}, "a");
   while row do 
    local a={};
    table.insert(rows, row);
    row=cur:fetch({}, "a");
   end
   cur:close();
  end
 end
 
 return rows;
end


function tibulaSqlArray(query, ...)	--sql last row array
 query=tibulaSqlQuery(query, ...);
 
 local rowLast={};
 if tibulaSqlEngine == "maria" then
  for rk,rv in next,ejaMariaQuery(query) do
   rowLast=rv;
  end
 else
  local cur=tibulaSqlConnection:execute(query);
  if cur then
   local row=cur:fetch({}, "a");
   rowLast=row;
   while row do 
    rowLast=row;
    row=cur:fetch({}, "a");
   end
   cur:close();
  end
 end
    
 return ejaTable(rowLast);
end


function tibulaSqlRun(query, ...)	--execute sql command 
 query=tibulaSqlQuery(query, ...);

 local r=nil;
 if tibulaSqlEngine == "maria" then
  rv=ejaMariaQuery(query);
  if rv then 
   for k,v in next,rv do
    if type(v) == "table" then
     for kk,vv in next,v do r=vv; end
    else
     r=v;
    end
   end 
  end
 else
  local cur=tibulaSqlConnection:execute(query);
  if type(cur) == "userdata" then
   local row=cur:fetch({}, "n");
   if row then 
    r=row[1];
   end
  else  
    r=cur;
  end
  if cur and type(cur) ~= "number" then cur:close(); end
 end
 return r;
end


function tibulaSqlLastId()	--retrieve last inserted row id
 if tibulaSqlEngine == "sqlite3" then return ejaNumber(tibulaSqlRun('SELECT last_insert_rowid();')); end
 if tibulaSqlEngine == "maria" or tibulaSqlEngine == "mysql" then 
  return ejaNumber(tibulaSqlRun('SELECT LAST_INSERT_ID();')); 
 end
end


function tibulaSqlTableCreate(tableName)	--create a new table if it does not exist
 local r=0;
 
 if tibulaSqlNameCheck(tableName) and not tibulaSqlRun([[SELECT * FROM %s LIMIT 1;]], tableName) then
  local extra="";
  if tibulaSqlEngine == "maria" or tibulaSqlEngine == "mysql" then extra=" AUTO_INCREMENT "; end  
  if tibulaSqlRun([[CREATE TABLE %s (ejaId INTEGER %s PRIMARY KEY, ejaOwner INTEGER, ejaLog DATETIME);]], tableName, extra) then
   r=1;
  else 
   r=-1;
  end
 end

 return r;
end


function tibulaSqlTableColumnCreate(tableName, columnName, columnType) 	--add a new column field into a table if it does not exist
 local r=0;   
 local dataType=tibulaSqlTableDataType(columnType);

 if tibulaSqlNameCheck(tableName) and tibulaSqlNameCheck(columnName) and ejaString(dataType) ~= "" and not tibulaSqlRun([[SELECT %s FROM %s LIMIT 1;]], columnName, tableName) then
  if tibulaSqlRun([[ALTER TABLE %s ADD %s %s;]], tableName, columnName, dataType) then
   r=1;
  else
   r=-1;
  end
 end

 return r;
end


function tibulaSqlIncludeList(query, ...)   --return a comma separated list of values to be included in IN() clause (only first column will be addded).
 local query=tibulaSqlQuery(query, ...);
 local r="";
 local list={}; 
 for rk,rv in next,tibulaSqlMatrix(query) do
  local k,v=next(rv);
  list[#list+1]=v;
 end
 
 return ejaString(table.concat(list, ","));
end


function tibulaSqlNow()   --return actual datetime 
 return os.date('%Y-%m-%d %H:%M:%S');
end


function tibulaSqlUnixTime(value)	--?convert value to unix or sql timestamp
 local r="";
 
 if tibulaSqlEngine == "sqlite3" then 
  if ejaNumber(value) > 0 then
   r=tibulaSqlRun([[SELECT datetime(%d, 'unixepoch');]], value);
  else
   r=tibulaSqlRun([[SELECT strftime('%%s', '%s');]], tibulaSqlEscape(value)); 
  end
 end
 
 if tibulaSqlEngine == "maria" or tibulaSqlEngine == "mysql" then 
  if ejaNumber(value) > 0 then
   r=tibulaSqlRun([[SELECT FROM_UNIXTIME(%d);]], value);
  else
   r=tibulaSqlRun([[SELECT UNIX_TIMESTAMP('%s');]], tibulaSqlEscape(value)); 
  end
 end
 
 return r or 0;
end


function tibulaSqlEscape(data)	--escape data for sql use in column values
  return ejaString(data):gsub([[\]],[[\\]]):gsub([[']],[[\']]):gsub([["]],[[\"]]):gsub([[\n]],[[\\n]]):gsub([[\0]],[[\\0]]):gsub([[\r]],[[\\r]]):gsub([[`]],[[\`]]);
end


function tibulaSqlNameCheck(name) --check if name is a valid table or column one
 if ejaString(name) ~= "" and name:match("^[0-9a-zA-Z_]*$") and #name <= 32 then
  return true;
 else
  ejaTrace([[[tibula] table/column name not valid]]);
  return false;
 end
end


function tibulaSqlTableDataType(sType)	--return sql data type syntax for sType data type
 local dType="";
 local sType=ejaString(sType);
 if sType=="boolean" 		then dType="INTEGER(1) DEFAULT 0";	end
 if sType=="integer"		then dType="INTEGER DEFAULT 0"; 	end
 if sType=="integerRange"	then dType="INTEGER DEFAULT 0";		end
 if sType=="decimal" 		then dType="DECIMAL(10, 2)"; 		end
 if sType=="date" 		then dType="DATE"; 			end
 if sType=="dateRange" 		then dType="DATE"; 			end
 if sType=="time" 		then dType="TIME"; 			end
 if sType=="timeRange" 		then dType="TIME"; 			end
 if sType=="datetime" 		then dType="DATETIME"; 			end
 if sType=="datetimeRange"	then dType="DATETIME"; 			end
 if sType=="text" 		then dType="TEXT";	 		end
 if sType=="hidden"	 	then dType="TEXT"; 			end
 if sType=="view" 		then dType="TEXT"; 			end
 if sType=="file" 		then dType="TEXT"; 			end
 if sType=="select" 		then dType="TEXT"; 			end
 if sType=="sqlValue" 		then dType="TEXT"; 			end
 if sType=="sqlHidden" 		then dType="TEXT"; 			end
 if sType=="sqlMatrix" 		then dType="TEXT"; 			end
 if sType=="textArea" 		then dType="TEXT"; 			end
 if sType=="htmlArea"		then dType="TEXT";	 		end

 return dType;
end


function tibulaSqlQuery(query, ...)	--filter sql query 
 argIn=table.pack(...);
 argOut={};
 for k,v in next,argIn do
  if tonumber(k) then
   str=tostring(v);
   argOut[k]=str;
  end
 end
 query=string.format(query, table.unpack(argOut));
 
 if not query:upper():match('^SET') and ejaNumber(tibula.ejaOwner) > 0 and ejaNumber(tibula.ejaModuleId) > 0 and ejaString(tibula.ejaModuleName) ~= "ejaFields" and ejaString(tibula.ejaModuleName) ~= "ejaSql" and ejaString(tibula.ejaModuleName) ~= "ejaBackups" then
  query=string.gsub(query, "@ejaOwner", tibula.ejaOwner);
 end

 ejaTrace([[[sql] %s]], query);

 return query;
end


function tibulaSqlOwnerList(ownerId)	--return the allowed id list of owners for active module and ownerId
 local moduleId;
 local ownerId=ejaNumber(ownerId);
 
 if ejaNumber(tibula.ejaModuleLink) > 0 and ejaNumber(tibula.ejaModuleChange) > 0 then 
  moduleId=tibula.ejaModuleChange; 
 else 
  moduleId=tibula.ejaModuleId; 
 end

 local ownerTree="";
 local sub=ownerId;
 local deep=10;
 local value="0";
 local groupOwners=tibulaSqlIncludeList([[SELECT dstFieldId FROM ejaLinks WHERE srcModuleId=%d AND srcFieldId IN (SELECT srcFieldId FROM ejaLinks WHERE srcModuleId=%d AND dstModuleId=%d AND dstFieldId=%d AND srcFieldId IN ( SELECT dstFieldId FROM ejaLinks WHERE srcModuleId=%d AND srcFieldId=%d AND dstModuleId=%d )) AND dstModuleId=%d;]], 
  tibulaSqlModuleGetIdByName("ejaGroups"), 
  tibulaSqlModuleGetIdByName("ejaGroups"), 
  tibulaSqlModuleGetIdByName("ejaUsers"), 
  ownerId, 
  tibulaSqlModuleGetIdByName("ejaModules"), 
  ejaNumber(moduleId), 
  tibulaSqlModuleGetIdByName("ejaGroups"), 
  tibulaSqlModuleGetIdByName("ejaUsers") 
 ); 
 while ejaNumber(deep) > 0 do
  deep=deep-1;
  value=tibulaSqlIncludeList([[SELECT ejaId FROM ejaUsers WHERE ejaOwner IN (%s) AND ejaId NOT IN (%s);]], sub, sub);
  if ejaString(value) ~= "" then 
   sub=value; 
   ownerTree=ownerTree..","..sub;   
  else 
   deep=0;
  end
 end
 local a={};
 local list=ownerId;
 for v in string.gmatch(ownerId..","..groupOwners..","..ownerTree, "%d+") do 
  if v and not a[v] then 
   a[v]=v; 
   if ejaNumber(ownerId) ~= ejaNumber(v) then
    list=list..","..v;
   end
  end
 end
 return list;
end


function tibulaSqlCommandArray(userId, moduleId, actionType)	--return the power ordered list of commands allowed for actionType, moduleId and userId
 local a={};
 local extra=""; 
 local order=""; 
 local linking="";
 local query="";
 local userId=ejaNumber(userId);
 local moduleId=ejaNumber(moduleId);
 local actionType=ejaString(actionType);
 
 if ejaString(tibula.ejaModuleName) == "ejaLogin" then table.insert(a, "login"); end
 if ejaNumber(tibula.ejaModuleId) == 35248 then table.insert(a, "logout"); end
 if ejaTableCount(tibula.ejaCommandArray) > 0 then
  for k,v in next,tibula.ejaCommandArray do
   extra=extra.." OR name='"..tibulaSqlEscape(v).."' ";
   if ejaString(v) == "searchLink" then table.insert(a, "searchLink"); end
  end
 end 
 if tibulaSqlNameCheck(actionType) then order=" ORDER BY power"..actionType.. " ASC";  end
 if ejaNumber(tibula.ejaLinking) > 0 then linking=" AND linking > 0 ";  end
 query=ejaSprintf([[SELECT * FROM ejaCommands WHERE (ejaId IN (SELECT ejaCommandId FROM ejaPermissions WHERE ejaModuleId=%d AND ejaId IN (SELECT srcFieldId FROM ejaLinks WHERE srcModuleId=%d AND ((dstModuleId=%d AND dstFieldId=%d) OR (dstModuleId=%d AND dstFieldId IN (%s))))) %s) %s %s;]], 
  moduleId, 
  tibulaSqlModuleGetIdByName("ejaPermissions"), 
  tibulaSqlModuleGetIdByName("ejaUsers"), 
  userId, 
  tibulaSqlModuleGetIdByName("ejaGroups"), 
  tibulaSqlUserGroupGetList(userId), 
  extra, 
  linking, 
  order
 );
 for k,v in next,tibulaSqlMatrix(query) do
  local commandName=v['name'];
  if ejaString(tibula.ejaAction) == "view" and ejaString(commandName) == "save" then commandName=""; end
  if ejaString(commandName) ~= "" then
   if tibulaSqlNameCheck(actionType) then
    if ejaNumber(v['power'..actionType]) > 0 then table.insert(a, commandName); end
   else 
    table.insert(a, commandName);
   end
  end
 end
 
 return a;
end


function tibulaSqlModuleTree(ownerId, moduleId)	--return path, tree and links array
 local ownerId=ejaNumber(ownerId);
 local moduleId=ejaNumber(moduleId);
 local row;
 local id=moduleId;
 local a={};
 a.pathId={};
 a.pathName={};
 a.treeId={};
 a.treeName={}; 
 a.linkId={};
 a.linkName={};
 a.historyId={};
 a.historyName={};

 --path
 while id do
  row=tibulaSqlArray([[SELECT ejaId, parentId, name FROM ejaModules WHERE ejaId=%d;]], id);
  id=nil;
  if ejaTableCount(row) > 0 and tibulaSqlRun([[SELECT ejaId FROM ejaLinks WHERE srcModuleId=%d AND srcFieldId IN (SELECT ejaId FROM ejaPermissions WHERE ejaModuleId=%d) AND ((dstFieldId=%d AND dstModuleId=%d) || (dstModuleId=%d AND dstFieldId IN (%s))) LIMIT 1;]], tibulaSqlModuleGetIdByName("ejaPermissions"), ejaNumber(row.ejaId), ownerId, tibulaSqlModuleGetIdByName("ejaUsers"), tibulaSqlModuleGetIdByName("ejaGroups"), tibulaSqlUserGroupGetList(ownerId) )  then
   table.insert(a.pathId, row.ejaId);
   table.insert(a.pathName, row.name);
   if ejaNumber(row.parentId) > 0 then
    id=row.parentId;
   end
  end
 end
 --tree 
 row=tibulaSqlMatrix([[SELECT ejaId, name FROM ejaModules WHERE parentId=%d ORDER BY power ASC;]], moduleId);
 if ejaTableCount(row) == 0 then
  if ejaTableCount(a.pathId) == 0 then
   row=tibulaSqlMatrix([[SELECT ejaId, name FROM ejaModules WHERE parentId=0 OR parentId='' AND ejaId != %d ORDER BY power ASC;]], moduleId);
  end
 end
 if ejaTableCount(row) > 0 then
  for k,v in next,row do
   if tibulaSqlRun([[SELECT ejaId FROM ejaLinks WHERE srcModuleId=%d AND srcFieldId IN (SELECT ejaId FROM ejaPermissions WHERE ejaModuleId=%d) AND ((dstFieldId=%d AND dstModuleId=%d) || (dstModuleId=%d AND dstFieldId IN (%s))) LIMIT 1;]], tibulaSqlModuleGetIdByName("ejaPermissions"), ejaNumber(v.ejaId), ownerId, tibulaSqlModuleGetIdByName("ejaUsers"), tibulaSqlModuleGetIdByName("ejaGroups"), tibulaSqlUserGroupGetList(ownerId)) then
    table.insert(a.treeId, v.ejaId);
    table.insert(a.treeName, v.name);
   end
  end
 end
 --links
 if ejaNumber(tibula.ejaId) > 0 then
  for k,v in next,tibulaSqlMatrix([[SELECT srcModuleId, (SELECT name FROM ejaModules WHERE ejaId=srcModuleId) AS srcModuleName FROM ejaModuleLinks WHERE dstModuleId=%d ORDER BY power ASC;]], moduleId) do 
   if (ejaTableCount(tibula.ejaLinkHistory) == 0 or ejaString(tibula.ejaLinkHistory[v.srcModuleId]) == "") and tibulaSqlRun([[SELECT ejaId FROM ejaLinks WHERE srcModuleId=%d AND srcFieldId IN (SELECT ejaId FROM ejaPermissions WHERE ejaModuleId=%d) AND dstFieldId=%d AND dstModuleId=%d LIMIT 1;]], tibulaSqlModuleGetIdByName("ejaPermissions"), ejaNumber(v.srcModuleId), ownerId, tibulaSqlModuleGetIdByName("ejaUsers")) then
    if v.srcModuleName ~= "ejaFiles" then
     table.insert(a.linkId, v.srcModuleId);
     table.insert(a.linkName, v.srcModuleName);
    end
   end
  end
 end
 
 if ejaTableCount(tibula.ejaLinkHistory) > 0 then
  for k,v in next,tibula.ejaLinkHistory do
   if ejaString(k) ~= ejaString(moduleId) and ejaString(v) ~= "" then	
    table.insert(a.historyId, k);
    table.insert(a.historyName, tibulaTranslate(tibulaSqlModuleGetNameById(k)));
   end 
  end 
 end
 
 return a;
end


function tibulaSqlFieldsMatrix(moduleId, actionType) 	--return an array with rowName,rowType,rowValue,rowArray of moduleName for actionType
 local a={};
 local t="";
 local matrix=0;
 local moduleId=ejaNumber(moduleId);
 
 if tibulaSqlNameCheck(actionType) then
  actionType=ejaString(actionType);
 else
  actionType="";
 end
 
 if actionType == "Matrix" then 
  actionType="List"; 
  matrix=1; 
 end 
 
 for k,v in next,tibulaSqlMatrix([[SELECT * FROM ejaFields WHERE ejaModuleId=%d AND power%s>0 AND power%s!='' ORDER BY power%s ASC;]], moduleId, actionType, actionType, actionType) do 
  local rowType=ejaString(v['type']);
  local rowName=ejaString(v['name']);
  local rowValue="";
  local rowArray={};
  local t="view";
  if ejaString(tibula.ejaAction) ~= "view" then 
   if matrix == 1 and ejaNumber(v['matrixUpdate']) > 0 then 
    t="matrix";
   else
    t=rowType; 
   end
  end
  if ejaNumber(v['ejaGroup']) > 0 and ejaString(tibula.ejaActionType) == "Edit" then	--if there is an ejaGroup then restrict to view only mode
   if not tibulaSqlRun([[SELECT ejaId FROM ejaLinks WHERE srcModuleId=%d AND dstModuleId=%d AND dstFieldId=%d AND srcFieldId=%d LIMIT 1;]], tibulaSqlModuleGetIdByName("ejaGroups"), tibulaSqlModuleGetIdByName("ejaUsers"), ejaNumber(tibula.ejaOwner), v['ejaGroup']) then
    t="view";
   end 
  end
  if tibula.ejaValues and tibula.ejaValues[rowName] then 
   rowValue=tibula.ejaValues[rowName]; 
  elseif ejaString(v['value']) ~= "" then
   rowValue=v['value'];
  end
  if rowType == "select" then rowArray=tibulaSelectToArray(v['value']); end
  if rowType == "sqlMatrix" then rowArray=tibulaSelectSqlToArray(v['value']); end
  if rowType == "sqlValue" or rowType == "sqlHidden" then rowValue=tibulaSqlRun(v['value']); end
  if rowType == "sqlTable" then rowArray=tibulaSqlMatrix(v['value']); end
  if t == "view" then 
   if ejaTableCount(rowArray) > 0 then rowValue=rowArray[ tibula.ejaValues[rowName] ]; end
   if rowType == "password" then rowValue="********"; end
  end
  if ejaNumber(v['translate']) > 0 then rowValue=tibulaTranslate(rowValue); end
  if ejaString(actionType) == "Edit" and rowName == "ejaOwner" and ejaNumber(rowValue) < 1 then
   rowValue=tibula.ejaOwner;
  end
  table.insert(a, { name=rowName; type=t; value=rowValue; values=rowArray }); 
 end

 return a;
end


function tibulaSqlSearchMatrix(query, moduleId) 	--return an associative array for the sql query on module or 0, and set total retrieved rows on tibula.ejaSqlCount and total (no limit) rows on tibula.ejaSqlCountTotal
 local y=0;
 local a={};
 local head={};
 local query=ejaString(query);
 local moduleId=ejaNumber(moduleId);
 
 if moduleId > 0 then
  head=tibulaSqlSearchHeader(query, moduleId);
  query=head[1]['query'];
 end

 local sql=tibulaSqlMatrix(query);
 
 if ejaTableCount(sql) > 0 then
  for k,v in next,sql do
   setmetatable(v, getmetatable(sql));
   table.insert(a, tibulaSqlSearchRowFilter(head, v));
   y=y+1;
  end
  setmetatable(a, getmetatable(sql));
 end
 tibula.ejaSqlCountTotal=0;
 local x=""; --?
 local moduleName=tibulaSqlModuleGetNameById(moduleId);
 if tibulaSqlNameCheck(moduleName) then x=string.find(query, "FROM "..moduleName.." WHERE"); end		--? to replace by regex
 if x then
  local queryCountFrom=string.sub(query, x, -1);
  local queryCount=ejaSprintf([[SELECT COUNT(*) %s;]], queryCountFrom);
  local k,l=1,1;
  while l do 
   k,l=string.find(string.sub(queryCount, l), "ORDER BY");
   if k then queryCountLimit=l; end
  end
  if ejaNumber(queryCountLimit) > 0 then 
   queryCount=string.sub(queryCount, 1, queryCountLimit-string.len("ORDER BY"));
   tibula.ejaSqlCountTotal=tibulaSqlRun(queryCount);
  end
 end
 tibula.ejaSqlCount=y;

 return a;
end


function tibulaSqlSearchHeader(query, moduleId) 	--return an associative array with the possible values for each columns and the "right" query to execute. 
 local a={};
 local query=ejaString(query);
 local moduleId=ejaNumber(moduleId);

 if moduleId > 0 then
  for k,v in next,tibulaSqlMatrix([[SELECT * FROM ejaFields WHERE ejaModuleId=%d AND powerList!='' AND powerList>0 ORDER BY powerList;]], moduleId) do
   local rowType=ejaString(v['type']);
   a[v['name']]={};
   if rowType == "boolean" then 
    a[v['name']]['value']={};
    a[v['name']]['value']['0']="FALSE";
    a[v['name']]['value']['1']="TRUE";
   end	
   if rowType == "select" then 
    a[v['name']]['value']=tibulaSelectToArray(v['value']); 
   end	
   if rowType == "sqlMatrix" then 
    a[v['name']]['value']=tibulaSelectSqlToArray(v['value']); 
   end
   if rowType == "sqlValue" or rowType == "sqlHidden" then 
    query=string.gsub(query, v['name'], ejaSprintf('(%s) AS %s', v['value'], v['name']) ); 
   end
   if ejaNumber(v['translate']) > 0 then 
    a[v['name']]['translation']=v['translate'];
   else
    a[v['name']]['translation']=0; 
   end
  end
 end
 a[1]=ejaTable(a[1]);
 a[1]['query']=query;
 
 return a;
end


function tibulaSqlSearchRowFilter(head, row) 	--return filtered row with translation and subQuery substitution if needed.
 local a={};
 local value="";

 for k,v in next,getmetatable(row) do
  value=row[v];

  if ejaTableCount(head[v]) > 0 and ejaTableCount(head[v]['value']) > 0 then --if the v name begins with ejaId use ejaId as v for the value to search for.
   if string.sub(v, 1, 5) == "ejaId" then 
    value=head[v]['value'][a['ejaId']]; 
   else 
    value=head[v]['value'][row[v]];
    if not value then
     for k1,v1 in next,head[v]['value'] do
      if ejaString(k1) == ejaString(row[v]) then
       value=v1;
      end
     end
    end 
   end
  end
  
  if k == 1 then 
   a[v]=value; 
  else 
   if head and head[v] and head[v]['translation'] then 
    a[v]=tibulaTranslate(value);  
   else
    a[v]=value; 
   end
  end
  
 end

 return a;
end


function tibulaSelectSqlToArray(value)   --convert an sql query to bidimensional matrix for selectBox
 local a={};
 local ai={};
 local i,z=0,0;
 
 local queryName,queryValue=value:match('^%w+%s+(%w+)%s*,%s*(%w+)');
 
 for k,v in next,tibulaSqlMatrix(value) do 
  k1,v1=next(v);
  k2,v2=next(v, k1);
  if v1 and v2 then
   if k1 == queryName then 
    table.insert(ai, v1);
    a[v1]=v2;
   else
    table.insert(ai, v2);
    a[v2]=v1;
   end
  end
 end
 setmetatable(a, ai);

 return a;
end


function tibulaSelectToArray(value)      --convert a "|" separated list of "\n" delimited rows to array for selectBox
 local a={};
 local ai={};
 local i=0;
 
 value=string.gsub(value, "\r", "");
 
 if string.find(value, "%|") then
  for k,v in string.gmatch(value, "([^%|%\n]*)%|([^%\n]*)") do 
   a[k]=v; 
   table.insert(ai, k);
  end
 else 
  for k,v in string.gmatch(value, "([^\n]*)") do 
   a[k]=k; 
   if i == 0 then 
    i=1; 
    table.insert(ai, k); 
   else 
    i=0; 
   end
  end
 end
 setmetatable(a, ai);
 
 return a;                      
end


function tibulaSqlModuleGetNameById(id) 
 return ejaString(tibulaSqlRun([[SELECT name FROM ejaModules WHERE ejaId=%d;]], ejaNumber(id)));
end


function tibulaSqlModuleGetIdByName(name) 
 if tibulaSqlNameCheck(name) then
  return ejaNumber(tibulaSqlRun([[SELECT ejaId FROM ejaModules WHERE name='%s';]], name));
 else
  return 0;
 end
end


function tibulaSqlModuleDel(tableId, ownerList)
 local tableId=ejaNumber(tableId);
 local tableName=tibulaSqlRun([[SELECT name FROM ejaModules WHERE ejaId=%d AND ejaOwner IN (%s);]], tableId, tibulaSqlEscape(ownerList));
 if tibulaSqlNameCheck(tableName) then
  tibulaSqlRun([[DROP TABLE %s;]], tableName);
  tibulaSqlRun([[DELETE FROM ejaFields WHERE ejaModuleId=%d;]], tableId);
  tibulaSqlRun([[DELETE FROM ejaPermissions WHERE ejaModuleId=%d;]], tableId);
  tibulaSqlRun([[DELETE FROM ejaHelps WHERE ejaModuleId=%d;]], tableId);
  tibulaSqlRun([[DELETE FROM ejaTranslations WHERE ejaModuleId=%d;]], tableId);
  tibulaSqlRun([[DELETE FROM ejaModuleLinks WHERE dstModuleId=%d;]], tableId); 
  return true;
 else
  return false;
 end
end


function tibulaSqlLinkGetPower(srcModule, srcField, dstModule, dstField)
 return tibulaSqlArray([[SELECT ejaId, power FROM ejaLinks WHERE srcModuleId=%d AND srcFieldId=%d AND dstModuleId=%d AND dstFieldId=%d;]], ejaNumber(srcModule), ejaNumber(srcField), ejaNumber(dstModule), ejaNumber(dstField));
end


function tibulaSqlLinkSetPower(power, id, ownerList)
 return tibulaSqlRun([[UPDATE ejaLinks SET power=%d WHERE ejaId=%d AND ejaOwner IN (%s);]], ejaNumber(power), ejaNumber(id), tibulaSqlEscape(ownerList));
end


function tibulaSqlLinkAdd(userId, srcModuleId, srcFieldId, dstModuleId, dstFieldId, power)
 return tibulaSqlRun([[INSERT INTO ejaLinks (ejaOwner, ejaLog, srcModuleId, srcFieldId, dstModuleId, dstFieldId, power) VALUES (%d, '%s', %d, %d, %d, %d, '%s');]], ejaNumber(userId), tibulaSqlNow(), ejaNumber(srcModuleId), ejaNumber(srcFieldId), ejaNumber(dstModuleId), ejaNumber(dstFieldId), tibulaSqlEscape(power));
end


function tibulaSqlLinkDel(id, ownerList) 
 return tibulaSqlRun([[DELETE FROM ejaLinks WHERE ejaId=%d AND ejaOwner IN (%s);]], ejaNumber(id), tibulaSqlEscape(ownerList));
end


function tibulaSqlLinkCopy(userId, dstFieldNew, dstModule, dstFieldOriginal)
 return tibulaSqlRun([[INSERT INTO ejaLinks (ejaId, ejaOwner, ejaLog, srcModuleId, srcFieldId, dstModuleId, dstFieldId, power) SELECT NULL, %d, '%s', srcModuleId, srcFieldId, dstModuleId, %d, power FROM ejaLinks WHERE dstModuleId=%d AND dstFieldId=%d;]], ejaNumber(userId), tibulaSqlNow(), ejaNumber(dstFieldNew), ejaNumber(dstModule), ejaNumber(dstFieldOriginal));
end


function tibulaSqlModuleLinkGetSrcField(dstModule, srcModule)
 return ejaString(tibulaSqlRun([[SELECT srcFieldName FROM ejaModuleLinks WHERE dstModuleId=%d AND srcModuleId=%d;]], ejaNumber(dstModule), ejaNumber(srcModule)));
end


function tibulaSqlHelpGetText(moduleId, actionType, language) 
 return ejaString(tibulaSqlRun([[SELECT text FROM ejaHelps WHERE (ejaModuleId=0 OR ejaModuleId=%d) AND (actionType='%s' OR actionType='') AND ejaLanguage='%s' ORDER BY actionType DESC, ejaModuleId DESC LIMIT 1;]], ejaNumber(moduleId), tibulaSqlEscape(actionType), tibulaSqlEscape(language)));
end


function tibulaSqlUserGetIdByUsername(username)
 return ejaNumber(tibulaSqlRun([[SELECT ejaId FROM ejaUsers WHERE username='%s' LIMIT 1;]], ejaString(username)));
end


function tibulaSqlUserGetIdByUserAndPass(username, password)
 return ejaNumber(tibulaSqlRun([[SELECT ejaId FROM ejaUsers WHERE username='%s' AND CASE WHEN LENGTH(password) = 64 THEN password='%s' ELSE password='%s' END;]], tibulaSqlEscape(username), ejaSha256(password), tibulaSqlEscape(password)));
end


function tibulaSqlSessionResetByUserId(userId)
 return tibulaSqlRun([[DELETE FROM ejaSessions WHERE ejaOwner=%d;]], ejaNumber(userId));
end


function tibulaSqlUserSessionUpdate(session, userId);
 return tibulaSqlRun([[UPDATE ejaUsers SET ejaSession='%s' WHERE ejaId=%d;]], tibulaSqlEscape(session), ejaNumber(userId)); 
end


function tibulaSqlUserGetAllById(userId)
 return tibulaSqlArray([[SELECT * FROM ejaUsers WHERE ejaId=%d;]], ejaNumber(userId));
end


function tibulaSqlUserGetAllBySession(session)
 return tibulaSqlArray([[SELECT * FROM ejaUsers WHERE ejaSession='%s';]], tibulaSqlEscape(session));
end


function tibulaSqlUserSessionReset(userId)
 return tibulaSqlRun([[UPDATE ejaUsers SET ejaSession='' WHERE ejaId=%d;]], ejaNumber(userId));
end


function tibulaSqlUserPermissionCopy(userId, moduleId)
 return tibulaSqlRun([[INSERT INTO ejaLinks (ejaId, ejaOwner, ejaLog, srcModuleId, srcFieldId, dstModuleId, dstFieldId, power) SELECT NULL, 1, '%s', %d, ejaId, %d, %d, 2 from ejaPermissions where ejaModuleId=%d;]], tibulaSqlNow(), tibulaSqlModuleGetIdByName("ejaPermissions"), tibulaSqlModuleGetIdByName("ejaUsers"), ejaNumber(userId), ejaNumber(moduleId));
end

function tibulaSqlUserGroupGetList(userId)
 local r=tibulaSqlIncludeList([[SELECT srcFieldId FROM ejaLinks WHERE srcModuleId=%d AND dstModuleId=%d AND dstFieldId=%d;]], tibulaSqlModuleGetIdByName("ejaGroups"), tibulaSqlModuleGetIdByName("ejaUsers"), ejaNumber(userId));
 if r == "" then 
  return "0";
 else
  return r;
 end
end


function tibulaSqlTableNew(tableName, userId, tableId)
 if tibulaSqlNameCheck(tableName) and ejaNumber(userId) > 0 then
  if ejaNumber(tableId) == 0 then tableId="NULL"; end
  tibulaSqlRun([[INSERT INTO %s (ejaId, ejaOwner, ejaLog) VALUES (%s, %d, '%s');]], tableName, tableId, userId, tibulaSqlNow());
  return tibulaSqlLastId();
 else
  return 0;
 end
end


function tibulaSqlTableUpdateById(tableName, colName, colValue, id, ownerList)
 if tibulaSqlNameCheck(tableName) and tibulaSqlNameCheck(colName) then
  return tibulaSqlRun([[UPDATE %s SET %s='%s' WHERE ejaId=%d AND ejaOwner IN (%s);]], tableName, colName, tibulaSqlEscape(colValue), ejaNumber(id), tibulaSqlEscape(ownerList));
 else
  return false;
 end
end


function tibulaSqlTableGetAllById(tableName, tableId)
 if tibulaSqlNameCheck(tableName) then
  return tibulaSqlArray([[SELECT * FROM %s WHERE ejaId=%d;]], tableName, ejaNumber(tableId));
 else
  return {};
 end
end


function tibulaSqlTableDelete(tableName, tableId, ownerList)
 if tibulaSqlNameCheck(tableName) and ejaNumber(tableId) > 0 then
  local moduleId=tibulaSqlModuleGetIdByName(tableName);
  tibulaSqlRun([[DELETE FROM %s WHERE ejaId=%d AND ejaOwner IN (%s);]], tableName, tableId, tibulaSqlEscape(ownerList)); 
  tibulaSqlRun([[DELETE FROM ejaLinks WHERE (dstModuleId=%d AND dstFieldId=%d) OR (srcModuleId=%d AND srcFieldId=%d) AND ejaOwner IN (%s);]], moduleId, tableId, moduleId, tableId, tibulaSqlEscape(ownerList));
  return true
 else
  return false;
 end
end


function tibulaSqlPermissionCount(moduleId)
 return ejaNumber(tibulaSqlRun([[SELECT COUNT(*) FROM ejaPermissions WHERE ejaModuleId=%d;]], ejaNumber(moduleId)));
end


function tibulaSqlPermissionAdd(userId, moduleId, commandName)
 return tibulaSqlRun([[INSERT INTO ejaPermissions (ejaId, ejaOwner, ejaLog, ejaModuleId, ejaCommandId) SELECT NULL, %d, '%s', %d, ejaId FROM ejaCommands WHERE name='%s';]], ejaNumber(userId), tibulaSqlNow(), ejaNumber(moduleId), tibulaSqlEscape(commandName));
end


function tibulaSqlPermissionAddDefault(userId, moduleId)
 return tibulaSqlRun([[INSERT INTO ejaPermissions (ejaId, ejaOwner, ejaLog, ejaModuleId, ejaCommandId) SELECT NULL, %d, '%s', %d, ejaId FROM ejaCommands WHERE defaultCommand>0;]], ejaNumber(userId), tibulaSqlNow(), ejaNumber(moduleId));
end


function tibulaSqlFieldType(moduleId, fieldName) 
 return ejaString(tibulaSqlRun([[SELECT type FROM ejaFields WHERE ejaModuleId=%d AND name='%s';]], ejaNumber(moduleId), tibulaSqlEscape(fieldName)));
end


function tibulaSqlTranslateMatrix(moduleId, language)	--must be ORDER ASC to overwrite general translation with module one
 return tibulaSqlMatrix([[SELECT * FROM ejaTranslations where ejaLanguage='%s' AND (ejaModuleId=0 OR ejaModuleId='' OR ejaModuleId=%d) ORDER BY ejaModuleId ASC;]], tibulaSqlEscape(language), ejaNumber(moduleId));
end

function tibulaSqlSearchQuery(tableName, valueArray, ownerList)
 local sql={};
 if tibulaSqlNameCheck(tableName) then
  local sqlType={};
  local moduleId=tibulaSqlModuleGetIdByName(tableName);
  sql[#sql+1]="SELECT ejaId";
  for k,v in next,tibulaSqlMatrix([[SELECT * FROM ejaFields WHERE ejaModuleId=%d ORDER BY powerList;]], ejaNumber(moduleId)) do
   if ejaNumber(v.powerList) > 0 then
    sql[#sql+1]=',';
    sql[#sql+1]=v.name;
   end
   sqlType[v.name]=v.type;
  end
  sql[#sql+1]=ejaSprintf([[ FROM %s WHERE ejaOwner IN (%s) ]], tableName, tibulaSqlEscape(ownerList));
  for k,v in next,valueArray do
   local sqlTypeThis=ejaString(sqlType[k]);
   if tibulaSqlNameCheck(k) and ejaString(v) ~= "" and not string.find(k, "%.") then 
    local sqlAnd="";
    v=string.gsub(v, "*", "%%");
    v=string.gsub(v, "%%", "%%%%%%%%");
    if sqlTypeThis == "boolean" or sqlTypeThis == "integer" then 
     local s=ejaString(v);
     if s:sub(1,1) == ">" then
      sqlAnd=ejaSprintf(' AND %s > %d ', k, ejaNumber(s:sub(2)));
     elseif s:sub(1,1) == "<" then
      sqlAnd=ejaSprintf(' AND %s < %d ', k, ejaNumber(s:sub(2)));
     else
      sqlAnd=ejaSprintf(' AND %s = %d ', k, ejaNumber(v)); 
     end
    end
    if sqlTypeThis == "date" or sqlTypeThis == "time" or sqlTypeThis == "datetime" then 
     sqlAnd=ejaSprintf([[ AND %s='%s' ]], k, tibulaDateSet(v, sqlTypeThis)); 
    end
    if sqlTypeThis == "dateRange" or sqlTypeThis == "timeRange" or sqlTypeThis == "datetimeRange" or sqlTypeThis == "integerRange" then
     if ejaString(valueArray[k..".begin"]) ~= "" then 
      sqlAnd=sqlAnd..ejaSprintf([[ AND %s > '%s' ]], k, tibulaDateSet(valueArray[k..".begin"], "")); 
     end
     if ejaString(valueArray[k..".end"]) ~= "" then 
      sqlAnd=sqlAnd..ejaSprintf([[ AND %s < '%s' ]], k, tibulaDateSet(valueArray[k..".end"], "")); 
     end
    end
    if ejaString(sqlAnd) == "" then 
     sqlAnd=ejaSprintf([[ AND %s LIKE '%s' ]], k, tibulaSqlEscape(v));
    end 
    sql[#sql+1]=sqlAnd;
   end
  end
 end
 return table.concat(sql);
end  


function tibulaSqlSearchQueryLink(tableName, linkFieldName, linkFieldId, linkModuleId, ownerList)
 if tibulaSqlNameCheck(tableName) then
  if ejaString(linkFieldName) ~= "" then
   if tibulaSqlNameCheck(linkFieldName) then
    return ejaSprintf([[ AND ejaId IN (SELECT ejaId FROM %s WHERE %s=%d AND ejaOwner IN (%s)) ]], tableName, linkFieldName, ejaNumber(linkFieldId), tibulaSqlEscape(ownerList));
   end
  else
   return ejaSprintf([[ AND ejaId IN (SELECT srcFieldId FROM ejaLinks WHERE srcModuleId=%d AND dstModuleId=%d AND dstFieldId=%d) ]], tibulaSqlModuleGetIdByName(tableName), ejaNumber(linkModuleId), ejaNumber(linkFieldId)); 
  end
 end
 return "";
end


function tibulaSqlSearchQueryOrderAndLimit(order, limit, step)
 if tibulaSqlNameCheck(order:gsub("[,|%s]","")) then
  return ejaSprintf([[ ORDER BY %s LIMIT %d, %d;]], order, ejaNumber(limit), ejaNumber(step));
 else
  return "";
 end
end


function tibulaSqlSessionRead(ownerId)      --return the ejaSessions array for ownerId
 if ejaNumber(ownerId) > 0 then
  for k,v in next,tibulaSqlMatrix([[SELECT name, sub, value FROM ejaSessions WHERE ejaOwner=%d ORDER BY ejaId ASC;]], ownerId) do
   if ejaString(v['sub']) ~= "" then 
    if not tibula[v['name']] then tibula[v['name']]={}; end
    tibula[v['name']][v['sub']]=v['value'];
   else
    tibula[v['name']]=v['value'];
   end
  end
 end
end


function tibulaSqlSessionWrite(ownerId, values)	--write the ejaSession array 
 if ejaNumber(ownerId) > 0 then  
  tibulaSqlRun([[SET @ejaOwner=%d;]], ownerId);	--?
  tibulaSqlRun([[DELETE FROM ejaSessions WHERE ejaOwner=%d;]], ownerId);
  for k,v in next,values do
   if type(v) == "table" then
    for kk,vv in next,v do
     if type(vv) ~= "table" then
      tibulaSqlRun([[INSERT INTO ejaSessions (ejaLog, ejaOwner, name, sub, value) VALUES ('%s', %d, '%s', '%s', '%s');]], tibulaSqlNow(), ownerId, tibulaSqlEscape(k), tibulaSqlEscape(kk), tibulaSqlEscape(vv));
     end
    end
   else
    tibulaSqlRun([[INSERT INTO ejaSessions (ejaLog, ejaOwner, name, value) VALUES ("%s", %d, "%s", "%s");]], tibulaSqlNow(), ownerId, tibulaSqlEscape(k), tibulaSqlEscape(v)); 
   end
  end
 else
  tibulaSqlRun([[SET @ejaOwner=0;]]);
 end 
end


function tibulaSqlModuleExport(name)   --export a tibula module with fields and commands
 local a={};
 if tibulaSqlNameCheck(name) then
  local id=tibulaSqlModuleGetIdByName(name);
  a.name=name;
  a.module=tibulaSqlArray([[SELECT a.searchLimit, a.sqlCreated, a.power, a.sortList, a.lua, (SELECT x.name FROM ejaModules AS x WHERE x.ejaId=a.parentId) AS parentName FROM ejaModules AS a WHERE ejaId=%s;]], id);
  a.field=tibulaSqlMatrix([[SELECT translate, matrixUpdate, powerEdit, name, type, powerList, powerSearch, value FROM ejaFields WHERE ejaModuleId=%s;]], id);
  a.translation=tibulaSqlMatrix([[SELECT ejaLanguage, word, translation, (SELECT ejaModules.name FROM ejaModules WHERE ejaModules.ejaId=ejaModuleId) AS ejaModuleName FROM ejaTranslations WHERE ejaModuleId=%s OR word='%s';]], id, name);
  a.command={};
  for _,row in next,tibulaSqlMatrix([[SELECT name from ejaCommands WHERE ejaId IN (SELECT ejaCommandId FROM ejaPermissions WHERE ejaModuleId=%s);]], id) do
   a.command[#a.command+1]=row.name;
  end
 end
 return a;
end


function tibulaSqlModuleImport(a, tableName)	--import a tibula module with fields, commands and permission
 local id=nil;
 local a=ejaTable(a);
 local tableName=tableName or a.name; 
 if tibulaSqlNameCheck(tableName) then
  if not a.module then a.module={}; end
  local owner=1;
  local id=tibulaSqlModuleGetIdByName(name);
  local parentId=tibulaSqlModuleGetIdByName(a.module.parentName);
  if ejaNumber(a.module.sqlCreated) > 0 then 
   tibulaSqlTableCreate(tableName);
  end
  if id < 1 then
   tibulaSqlRun([[INSERT INTO ejaModules (ejaId, ejaOwner, ejaLog, name, power, searchLimit, lua, sqlCreated, sortList, parentId) VALUES (NULL, %d, '%s', '%s', %d, %d, '%s', %d, '%s', %d);]],
   owner, tibulaSqlNow(), tableName, ejaNumber(a.module.power), ejaNumber(a.module.searchLimit), tibulaSqlEscape(a.module.lua), ejaNumber(a.module.sqlCreated), tibulaSqlEscape(a.module.sortList), parentId);
   id=tibulaSqlLastId();
  end
  if id > 0 then
   tibulaSqlRun([[DELETE FROM ejaFields WHERE ejaModuleId=%d;]], id);
   for k,v in next,a.field do
    if ejaNumber(a.module.sqlCreated) > 0 then
     tibulaSqlTableColumnCreate(tableName, v.name, v.type);
    end
    tibulaSqlRun([[INSERT INTO ejaFields (ejaId, ejaOwner, ejaLog, ejaModuleId, name, type, value, translate, matrixUpdate, powerSearch, powerList, powerEdit) VALUES (NULL, %d, '%s', %d, '%s', '%s', '%s', '%s', %d, %d, %d, %d);]],
     owner, tibulaSqlNow(), id, tibulaSqlEscape(v.name), tibulaSqlEscape(v.type), tibulaSqlEscape(v.value), tibulaSqlEscape(v.translate), ejaNumber(v.matrixUpdate), ejaNumber(v.powerSearch), ejaNumber(v.powerList), ejaNumber(v.powerEdit));
   end
   local src=tibulaSqlModuleGetIdByName("ejaPermissions");
   local dst=tibulaSqlModuleGetIdByName("ejaUsers"); 
   tibulaSqlRun([[DELETE FROM ejaLinks WHERE dstModuleId=%d AND srcModuleId=%d AND srcFieldId IN (SELECT c.ejaId FROM ejaPermissions AS c WHERE c.ejaModuleId=%d);]], dst, src, id);
   tibulaSqlRun([[DELETE FROM ejaPermissions WHERE ejaModuleId=%d;]], id);
   for k,v in next,a.command do
    tibulaSqlRun([[INSERT INTO ejaPermissions (ejaId, ejaOwner, ejaLog, ejaModuleId, ejaCommandId) VALUES (NULL, %d, '%s', %d, (SELECT x.ejaId FROM ejaCommands AS x WHERE x.name='%s' LIMIT 1));]], owner, tibulaSqlNow(), id, tibulaSqlEscape(v))
    tibulaSqlRun([[INSERT INTO ejaLinks (ejaId, ejaOwner, ejaLog, srcModuleId, srcFieldId, dstModuleId, dstFieldId, power) VALUES (NULL, %d, '%s', %d, %d, %d, %d, 1);]], 
     owner, tibulaSqlNow(), src, tibulaSqlLastId(), dst, owner);     
   end
   tibulaSqlRun([[DELETE FROM ejaTranslations WHERE ejaModuleId=%d;]], id);
   tibulaSqlRun([[DELETE FROM ejaTranslations WHERE word='%s' AND ejaModuleId < 1;]], tibulaSqlEscape(tableName));
   for _,row in next,a.translation do
    local tmpId=id;
    if ejaString(row.ejaModuleName) ~= tableName then tmpId=0 end
    tibulaSqlRun([[INSERT INTO ejaTranslations (ejaId, ejaOwner, ejaLog, ejaModuleId, ejaLanguage, word, translation) VALUES (NULL, %d, '%s', %d, '%s', '%s', '%s');]], owner, tibulaSqlNow(), tmpId, tibulaSqlEscape(row.ejaLanguage), tibulaSqlEscape(row.word), tibulaSqlEscape(row.translation));
   end
  end
 end
 return id; 
end
