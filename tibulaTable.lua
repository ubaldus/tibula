-- Copyright (C) 2007-2018 by Ubaldo Porcheddu <ubaldo@eja.it>
--
-- Polonaise héroïque


function tibulaTableStart()	--set default eja table value
 tibula={};
 tibula['ejaDefaultLanguage']="en";
 tibula['ejaDefaultSearchStep']=15;
 tibula['ejaDefaultSearchOrder']="ejaLog DESC";
 tibula['ejaCommandsArray']={}
 tibula['ejaHttpHeaders']={}
 tibula['ejaSqlType']=tibulaSqlType;
 tibula['ejaLanguage']=tibula['ejaLanguage'] or tibula['ejaDefaultLanguage'];
 tibula['path']=eja.opt.tibulaPath or eja.pathVar..'/tibula/'
end


function tibulaTableImport(a)	--import data into eja table
 for key,value in pairs(a) do
  if type(value) ~= "table" then key=ejaUrlDecode(key) end
  if type(value) ~= "table" then value=ejaUrlDecode(value) end

  if ejaCheck(key,"ejaId")  then tibula['ejaId']=value;  end
  if ejaCheck(key,"ejaAction") then tibula['ejaAction']=value; end
  if ejaCheck(key,"ejaSession") then tibula['ejaSession']=value; end
  if ejaCheck(key,"ejaModuleId") then tibula['ejaModuleId']=value; end
  if ejaCheck(key,"ejaLanguage") then tibula['ejaLanguage']=value; end
  if ejaCheck(key,"ejaLinkPower") then tibula['ejaLinkPower']=value; end
  if ejaCheck(key,"ejaModuleName") then tibula['ejaModuleName']=value; end
  if ejaCheck(key,"ejaSearchStep") then tibula['ejaSearchStep']=value; end
  if ejaCheck(key,"ejaModuleLink") then tibula['ejaModuleLink']=value; end
  if ejaCheck(key,"ejaSearchLimit") then tibula['ejaSearchLimit']=value; end
  if ejaCheck(key,"ejaModuleChange") then tibula['ejaModuleChange']=value; end
  if ejaCheck(key,"ejaModuleLinkBack") then tibula['ejaModuleLinkBack']=value; end
  if ejaCheck(key,"ejaDirectory") and not string.find(value,"%.%.") then tibula['ejaDirectory']=value; end
  if ejaCheck(key,"ejaOut") then tibula['ejaOut']=value; end	--xhtml/xml/json
  if ejaCheck(key,"ejaOutSession") then tibula['ejaOutSession']=value; end
   
  if string.sub(key,1,10) == "ejaAction[" then tibula['ejaAction']=string.sub(string.match(key,"%[%w+%]"),2,-2); end
  if ejaCheck(key,"ejaAction") then tibula['ejaAction']=value; end

  if string.sub(key,1,6) == "ejaId[" then
   if not tibula['ejaIdArray'] then tibula['ejaIdArray']={}; end
   if ejaNumber(tibula['ejaId']) < 1 then tibula['ejaId']=value; end
   table.insert(tibula['ejaIdArray'],value)
  end 
  if ejaCheck(key,"ejaId") and type(value) == 'table' then 
   tibula['ejaIdArray']=value; 
   if ejaNumber(tibula['ejaId']) < 1 then _,tibula['ejaId']=next(value); end   
  end  

  if ejaCheck(key,"ejaFile") and type(value) == "table" then
   tibula['ejaFile']={}
   i=0;
   for k,v in pairs(value) do
    i=i+1;
    if (i == 1) then tibula['ejaFile']['fileName']=v end 
    if (i == 2) then tibula['ejaFile']['fileType']=v end
    if (i == 3) then tibula['ejaFile']['fileData']=v end
    if (i == 4) then tibula['ejaFile']['fileSize']=v end
   end
  end 
  
  if string.sub(key,1,13) == "ejaLinkPower[" then 
   if type(tibula['ejaLinkPower']) ~= "table" then tibula['ejaLinkPower']={} end
   for k,v in string.gmatch(string.sub(key,12),"%[(%w+)%]%[(%w+)%]") do 
    tibula['ejaLinkPower'][k]=v.."."..value
   end
  end
  if ejaCheck(key,"ejaLinkPower") and type(value) == 'table' then tibula['ejaLinkPower']=value; end
  
  if string.sub(key,1,15) == "ejaSearchOrder[" and ejaCheck(value) then
   if type(tibula['ejaSearchOrder']) ~= "table" then tibula['ejaSearchOrder']={} end
   tibula['ejaSearchOrder'][string.sub(string.match(key,"%[%w+%]"),2,-2)]=value; 
  end 
  if ejaCheck(key,"ejaSearchOrder") and type(value) == 'table' then tibula['ejaSearchOrder']=value; end
  
  if string.sub(key,1,10) == "ejaValues[" then
   if type(tibula['ejaValues']) ~= "table" then tibula['ejaValues']={} end
   if string.find(key,"%[(%w+)%]%[(%w+)%]") then
    for k,v in string.gmatch(string.sub(key,9),"%[(%w+)%]%[(%w+)%]") do
     tibula['ejaValues'][k]=v.."."..value
    end
   else 
    local subB,subE=string.find(key,"%[(%w+)%.")
    if subB and subE then
     subKey=string.sub(key,subB+1,subE-1)
     tibula['ejaValues'][string.sub(string.match(key,"%[(.+)%]"),1,-1)]=value;
     if ejaCheck(value) then tibula['ejaValues'][subKey]=value; end
    else
     local k=string.sub(string.match(key,"%[(%w+)%]"),1,-1);
     if ejaCheck(k) then tibula['ejaValues'][k]=value; end
    end
   end
  end
  if ejaCheck(key,"ejaValues") and type(value) == 'table' then tibula['ejaValues']=value; end


 end 
end


function tibulaTableRun(web)	--main tibula engine 
 if ejaCheck(tibula['ejaModuleName']) then tibula['ejaModuleId']=tibulaSqlRun("SELECT ejaId FROM ejaModules WHERE name='%s';",tibula['ejaModuleName']) end
 if not ejaCheck(tibula['ejaModuleId']) then tibula['ejaModuleId']=tibulaSqlRun("SELECT ejaId FROM ejaModules WHERE name='eja';") end
 if not ejaCheck(tibula['ejaModuleId']) then tibula['ejaModuleId']=1 end
 if not ejaCheck(tibula['ejaId']) then tibula['ejaId']=0 end
 if not ejaCheck(tibula['ejaValues']) then tibula['ejaValues']={} end
 if not ejaCheck(tibula['ejaIdArray']) and ejaCheck(tibula['ejaId']) then tibula['ejaIdArray']={}; table.insert(tibula['ejaIdArray'],tibula['ejaId']) end
 if not ejaCheck(tibula['ejaOut']) then tibula['ejaOut']="xhtml" end
 if not tibula['ejaOutSession'] then tibula['ejaOutSession']=1; end

 --login, set a random session value and retrieve defaultModuleId 
 if ejaCheck(tibula['ejaAction'],"login") and ejaCheck(tibula['ejaValues']['username']) and ejaCheck(tibula['ejaValues']['password']) then 
  tibula['ejaOwner']=tibulaSqlRun("SELECT ejaId FROM ejaUsers WHERE username='%s' AND CASE WHEN LENGTH(password) = 64 THEN password='%s' ELSE password='%s' END;",tibula['ejaValues']['username'],ejaSha256(tibula['ejaValues']['password']),tibula['ejaValues']['password']);
  if ejaCheck(tibula['ejaOwner']) then
   tibulaSqlRun('DELETE FROM ejaSessions WHERE ejaOwner=%d;',tibula['ejaOwner']);
   tibulaSqlRun("UPDATE ejaUsers SET ejaSession='%s' WHERE ejaId='%d';",tibulaSessionCode(),tibula['ejaOwner']); 
   local row=tibulaSqlArray('SELECT * FROM ejaUsers WHERE ejaId=%d;',tibula['ejaOwner']);
   tibula['ejaSession']=row['ejaSession'];
   tibula['ejaModuleId']=row['defaultModuleId'];
  end
 end  

 --Session managment
 if ejaCheck(tibula['ejaSession']) then
  --set ejaOwner
  local user=tibulaSqlArray("SELECT * FROM ejaUsers WHERE ejaSession='%s';",tibula['ejaSession']);
  if ejaCheck(user) then
   tibula['ejaOwner']=user['ejaId'];
   --set ejaLanguage
   if ejaCheck(user['ejaLanguage']) then tibula['ejaLanguage']=user['ejaLanguage']; end
   --fill tibula from ejaSessions
   if ejaCheck(tibula['ejaOwner']) and ejaCheck(tibula['ejaOutSession'],1) and not ejaCheck(tibula['ejaAction'],"csvExport") and not ejaCheck(tibula['ejaAction'],"xmlExport") then tibulaSessionRead(tibula['ejaOwner']); end 
  --fill eja with the list and the array of other owners data enabled views
   tibula['ejaOwnerList']=tibulaSqlOwnerList(tibula['ejaOwner']); 
   if not ejaCheck(tibula['ejaOwners']) then tibula['ejaOwners']={}; end
   for v in string.gmatch(tibula['ejaOwnerList'],"%d+") do tibula['ejaOwners'][v]=v; end 
  else 
   tibula['ejaOwner']=0;
  end
 else 
  tibula['ejaOwner']=0;
 end 
 
 --Security checks
 if ejaCheck(tibula['ejaAction'],"logout") then
  --logout 
  if ejaCheck(tibula['ejaOwner']) then tibulaSqlRun("UPDATE ejaUsers SET ejaSession='' WHERE ejaId=%d;",tibula['ejaOwner']); end
  tibula['ejaSession']="";
  tibula['ejaOwner']=0;   
  tibulaReset();
  tibula['ejaLinkHistory']={};
  tibula['ejaLinkModuleId']=0;
  tibula['ejaLinkFieldId']=0; 
 end
 
 -- ejaSession semaphore
 if ejaNumber(tibula['ejaOwner']) < 1 then 
  tibula['ejaModuleId']=tibulaSqlRun("SELECT ejaId FROM ejaModules WHERE name='ejaLogin'");
  tibula['ejaModuleName']="ejaLogin";
  tibula['ejaLanguage']=tibula['ejaDefaultLanguage'];
  tibula['ejaSession']="";
  tibulaInfo("ejaNotAuthorized");
  
 else 	-- authorized
 
  --Module selection 
  if ejaCheck(tibula['ejaAction'],"query") then tibula['ejaModuleChange']=tibula['ejaModuleId']; end
  if ejaCheck(tibula['ejaModuleChange']) then      --if changing module reset sql order,limit,query..
   if ejaCheck(tibula['ejaLinkHistory']) and ejaCheck(tibula['ejaModuleChange'],35248) then tibulaLinkHistory(0,0) end --force ejaLinkHistory reset if on root module
   tibula['ejaModuleId']=tibula['ejaModuleChange'];
   tibulaReset();   
  end
 
  --Linking managment
  if ejaCheck(tibula['ejaModuleLink']) and ejaCheck(tibula['ejaModuleChange']) then	--link begin
   tibula['ejaModuleId']=tibula['ejaModuleChange'];
   tibulaLinkHistory(string.match(tibula['ejaModuleLink'],"(%d+)%."), string.match(tibula['ejaModuleLink'],"%.(%d+)"));	--add to ejaLinkHistory
   tibula['ejaAction']="searchLink";
   table.insert(tibula['ejaCommandsArray'],"searchLink");
  end
  --linking back
  if ejaCheck(tibula['ejaModuleLinkBack']) then	--link back
   tibulaReset();
   tibula['ejaId']=tibula['ejaLinkHistory'][tibula['ejaModuleLinkBack']];
   tibula['ejaModuleId']=tibula['ejaModuleLinkBack'];
   tibula['ejaAction']="edit";
   tibulaLinkHistory(tibula['ejaModuleId'],0);	--reset this ejaLinkHistory
  end
  --linking history
  if ejaCheck(tibula['ejaLinkHistoryOrder']) then	--if linking check link type 
   table.sort(tibula['ejaLinkHistoryOrder']);
   for k,v in pairs(tibula['ejaLinkHistoryOrder']) do
    if ejaCheck(v) then
     tibula['ejaLinkModuleId']=v
     tibula['ejaLinkFieldId']=tibula['ejaLinkHistory'][v]
    end
   end
   if not ejaCheck(tibula['ejaId']) then tibula['ejaLinking']=1; end
   if ejaCheck(tibula['ejaLinkModuleId']) then tibula['ejaLinkingField']=tibulaSqlRun('SELECT srcFieldName FROM ejaModuleLinks WHERE dstModuleId=%d AND srcModuleId=%d',tibula['ejaLinkModuleId'],tibula['ejaModuleId']); end
   if not ejaCheck(tibula['ejaLinkingField']) then tibula['ejaLinkingField']=""; end
  end   

  --Fill or update ejaModuleName
  if ejaNumber(tibula['ejaModuleId']) > 0 then tibula['ejaModuleName']=tibulaSqlRun('SELECT name FROM ejaModules WHERE ejaId=%d;',tibula['ejaModuleId']) or 'eja'; end
   
  --Fill ejaCommands
  tibula['ejaCommands']={}
  for k,v in pairs ( tibulaSqlCommandArray(tibula['ejaOwner'],tibula['ejaModuleId'],"") ) do tibula['ejaCommands'][v]=k; end

  --run lua script for this ejaModuleId and save tibula into ejaSessions
  tibulaModuleLua(0,web);
  tibulaSessionWrite(tibula['ejaOwner'],tibula);

  --Actions engine, runs only if ejaAction is in ejaSqlCommandList
  if ejaCheck(tibula['ejaAction']) and ejaCheck(tibula['ejaCommands'][tibula['ejaAction']]) then

   --update matrix
   if ejaCheck(tibula['ejaAction'],"update") then
    tibula['ejaMatrix']=1;
    tibula['ejaAction']="search"; 
    if ejaCheck(tibula['ejaId']) then 
     local validFields={}
     for k,v in pairs(tibulaSqlFieldsMatrix(tibula['ejaModuleId'], "Matrix")) do
      if ejaCheck(v['type'],"matrix") then 
       for kk,vv in pairs(tibula['ejaIdArray']) do
        if tibula['ejaValues'][v['name'].."."..vv] then
         tibulaSqlRun("UPDATE %s SET %s='%s' WHERE ejaId=%d AND ejaOwner IN (%s)",tibula['ejaModuleName'],v['name'],tibula['ejaValues'][v['name'].."."..vv],vv,tibula['ejaOwnerList'])
        end
       end
      end
     end
    end 
   end
 
   --link and unlink
   if (ejaCheck(tibula['ejaAction'],"link") or ejaCheck(tibula['ejaAction'],"unlink")) and ejaCheck(tibula['ejaIdArray']) then
    for k,v in pairs(tibula['ejaIdArray']) do
     local linkPower=0;
     local linkId=0;
     if ejaCheck(v) and tibula['ejaLinkPower'][v] then
      linkId=string.match(tibula['ejaLinkPower'][v],"(%d+)%.");
      linkPower=string.match(tibula['ejaLinkPower'][v],"%.(%d+)");
      if ejaCheck(tibula['ejaAction'],"link") then 
       if not ejaCheck(linkPower) then linkPower=1 end
       if ejaCheck(linkId) then
        tibulaSqlRun('UPDATE ejaLinks SET power=%d WHERE ejaId=%d AND ejaOwner IN (%s);',linkPower,linkId,tibula['ejaOwnerList']); 
       else 
        tibulaSqlRun("INSERT INTO ejaLinks (ejaOwner,ejaLog,srcModuleId,srcFieldId,dstModuleId,dstFieldId,power) VALUES (%d,'%s',%d,%d,%d,%d,%d);",tibula['ejaOwner'],tibulaSqlNow(),tibula['ejaModuleId'],v,tibula['ejaLinkModuleId'],tibula['ejaLinkFieldId'],linkPower);     
       end
      end
     if ejaCheck(tibula['ejaAction'],"unlink") then tibulaSqlRun('DELETE FROM ejaLinks WHERE ejaId=%d AND ejaOwner IN (%s);',linkId,tibula['ejaOwnerList']); end
     end
    end 
    tibula['ejaAction']="searchLink";  
    tibula['ejaLinking']=2; 
   end 

   --edit and view
   if ejaCheck(tibula['ejaId']) and (ejaCheck(tibula['ejaAction'],"edit") or ejaCheck(tibula['ejaAction'],"view")) then 
    tibula['ejaValues']=tibulaSqlArray('SELECT * FROM %s WHERE ejaId=%d;',tibula['ejaModuleName'],tibula['ejaId']);
   end
  
   --file upload
   if ejaCheck(tibula['ejaFile']) then
    tibula['ejaValues']['fileName']=tibula['ejaFile']['fileName']
    tibula['ejaValues']['fileType']=tibula['ejaFile']['fileType']
    tibula['ejaValues']['fileSize']=tibula['ejaFile']['fileSize']
    tibula['ejaValues']['fileData']=ejaBase64Encode(tibula['ejaFile']['fileData']);
    if ejaCheck(tibula['ejaLinkModuleId']) then 
     tibula['ejaValues']['ejaModuleId']=tibula['ejaLinkModuleId']; 
     tibula['ejaValues']['ejaFieldId']=tibula['ejaLinkFieldId']; 
    else
     tibula['ejaValues']['ejaFieldId']=tibula['ejaFieldId']; 
     tibula['ejaValues']['ejaModuleId']=tibula['ejaModuleId']; 
    end
    tibula['ejaFile']={}  
   end

   --new and copy
   if ejaCheck(tibula['ejaAction'],"new") or ejaCheck(tibula['ejaAction'],"copy") then
    tibula['ejaValues']['ejaLog']=tibulaSqlNow();
    tibula['ejaValues']['ejaOwner']=tibula['ejaOwner'];
    tibulaSqlRun("INSERT INTO %s (ejaId,ejaOwner,ejaLog) VALUES (NULL,'%d','%s');",tibula['ejaModuleName'],tibula['ejaValues']['ejaOwner'],tibula['ejaValues']['ejaLog']);
    tibula['ejaIdCopied']=tibula['ejaId'];
    tibula['ejaId']=tibulaSqlLastId();
    if ejaCheck(tibula['ejaAction'],"copy") then --copy ejaLinks and ejaFiles
     tibulaSqlRun("INSERT INTO ejaLinks (ejaId,ejaOwner,ejaLog,srcModuleId,srcFieldId,dstModuleId,dstFieldId,power) SELECT NULL,%d,'%s',srcModuleId,srcFieldId,dstModuleId,%d,power FROM ejaLinks WHERE dstModuleId=%d AND dstFieldId=%d;",tibula['ejaOwner'],tibulaSqlNow(),tibula['ejaId'],tibula['ejaModuleId'],tibula['ejaIdCopied']);
     tibulaSqlRun("INSERT INTO ejaFiles (ejaId,ejaOwner,ejaLog,ejaModuleId,ejaFieldId,fileName,fileSize,fileData) SELECT NULL,%d,'%s',ejaModuleId,%d,fileName,fileSize,fileData FROM ejaFiles WHERE ejaModuleId=%d AND ejaFieldId=%d;",tibula['ejaOwner'],tibulaSqlNow(),tibula['ejaId'],tibula['ejaModuleId'],tibula['ejaIdCopied'])
     tibula['ejaLinkFieldId']=tibula['ejaId'];
    end 
   end

   --save and copy (must be after "new" for "copy" to work). update data also if ejaAction=new and we are in batch mode (xml) 
   if ejaCheck(tibula['ejaValues']) and ( ( ejaCheck(tibula['ejaAction'],"save") or ejaCheck(tibula['ejaAction'],"copy") ) or ( ejaCheck(tibula['ejaOutSession'],0) and ejaCheck(tibula['ejaAction'],"new") ) or ( ejaCheck(tibula['ejaAction'],"searchLink") and ejaCheck(tibula['ejaId']) ) ) then
    if ejaCheck(tibula['ejaModuleName'],"ejaModules") and ejaCheck(tibula['ejaAction'],"save") then	-- create table on database and add permissions
     if ejaCheck(tibula['ejaValues']['sqlCreated']) then
      local tableCreate=tibulaSqlTableCreate(tibula['ejaValues']['name']);  
      if ejaNumber(tableCreate) > 0 then tibulaInfo("ejaSqlModuleCreated"); end
      if ejaNumber(tableCreate) < 0 then tibulaInfo("ejaSqlModuleNotCreated"); end
     end
     if not ejaCheck(tibulaSqlRun('SELECT COUNT(*) FROM ejaPermissions WHERE ejaModuleId=%d;',tibula['ejaId'])) then
      if ejaCheck(tibula['ejaValues']['sqlCreated']) then
       tibulaInfo("ejaModuleSqlPermissionsCreated");
       tibulaSqlRun("INSERT INTO ejaPermissions SELECT NULL,%d,'%s',%d,ejaId FROM ejaCommands WHERE defaultCommand>0",tibula['ejaOwner'],tibulaSqlNow(),tibula['ejaId']);
       tibulaSqlRun("INSERT INTO ejaLinks (ejaId,ejaOwner,ejaLog,srcModuleId,srcFieldId,dstModuleId,dstFieldId,power) SELECT NULL,1,'%s',(SELECT ejaId FROM ejaModules WHERE name='ejaPermissions'),ejaId,(SELECT ejaId FROM ejaModules WHERE name='ejaUsers'),%d,2 from ejaPermissions where ejaModuleId=%d;",tibulaSqlNow(),tibula['ejaOwner'],tibula['ejaId']);
      else
       tibulaInfo("ejaModuleContainerPermissionsCreated");
       tibulaSqlRun("INSERT INTO ejaPermissions SELECT NULL,%d,'%s',%d,ejaId FROM ejaCommands WHERE name='logout'",tibula['ejaOwner'],tibulaSqlNow(),tibula['ejaId']);
       tibulaSqlRun("INSERT INTO ejaLinks (ejaId,ejaOwner,ejaLog,srcModuleId,srcFieldId,dstModuleId,dstFieldId,power) SELECT NULL,1,'%s',(SELECT ejaId FROM ejaModules WHERE name='ejaPermissions'),ejaId,(SELECT ejaId FROM ejaModules WHERE name='ejaUsers'),%d,2 from ejaPermissions where ejaModuleId=%d;",tibulaSqlNow(),tibula['ejaOwner'],tibula['ejaId']);
      end
     end
    end
    if not ejaCheck(tibula['ejaId']) then 
     tibulaSqlRun("INSERT INTO %s (ejaId,ejaOwner,ejaLog) VALUES (NULL,'%d','%s');",tibula['ejaModuleName'],tibula['ejaOwner'],tibulaSqlNow());
     tibula['ejaId']=tibulaSqlLastId();
    else    
     if not tibulaSqlRun("SELECT ejaId FROM %s WHERE ejaId=%d;",tibula['ejaModuleName'],tibula['ejaId']) then
      tibulaSqlRun("INSERT INTO %s (ejaId,ejaOwner,ejaLog) VALUES (%d,%d,'%s');",tibula['ejaModuleName'],tibula['ejaId'],tibula['ejaOwner'],tibulaSqlNow());
     end 
    end
    for k,v in pairs(tibula['ejaValues']) do
     local t=tibulaSqlRun("SELECT type FROM ejaFields WHERE ejaModuleId=%d AND name='%s';",tibula['ejaModuleId'],k);
     if t then 
      if (string.find("#date#dateRange#time#timeRange#datetime#datetimeRange#",t)) then v=tibulaDateSet(v,t); end
      if ejaCheck(t,"password") and string.len(v) ~= 64 then v=ejaSha256(v) end
     end
     tibulaSqlRun("UPDATE %s SET %s='%s' WHERE ejaId=%d AND ejaOwner IN (%s);",tibula['ejaModuleName'],k,tibulaSqlEscape(v),tibula['ejaId'],tibula['ejaOwnerList']);
    end
    tibula['ejaValues']=tibulaSqlArray('SELECT * FROM %s WHERE ejaId=%d;',tibula['ejaModuleName'],tibula['ejaId']);
    
    --create table column
    if ejaCheck(tibula['ejaModuleName'],"ejaFields") and ejaCheck(tibula['ejaValues']['name']) and ejaCheck(tibula['ejaValues']['type']) and ejaCheck(tibula['ejaValues']['ejaModuleId']) then
     local fieldCreate=tibulaSqlTableColumnCreate(tibulaSqlRun('SELECT name FROM ejaModules WHERE ejaId=%d;',tibula['ejaValues']['ejaModuleId']), tibula['ejaValues']['name'], tibula['ejaValues']['type'])
     if ejaNumber(fieldCreate) > 0 then tibulaInfo("ejaSqlFieldCreated"); end
     if ejaNumber(fieldCreate) < 0 then tibulaInfo("ejaSqlFieldNotCreated"); end
    end
    
   end

   --delete
   if ejaCheck(tibula['ejaAction'],"delete") and ejaCheck(tibula['ejaIdArray']) then
    for k,v in pairs(tibula['ejaIdArray']) do 
     if ejaCheck(tibula['ejaModuleName'],"ejaModules") then	
      local tableName=tibulaSqlRun('SELECT name FROM ejaModules WHERE ejaId=%d AND ejaOwner IN (%s);',v,tibula['ejaOwnerList']);
      if ejaCheck(tableName) then
       tibulaSqlRun('DROP TABLE %s;',tableName);
       tibulaSqlRun('DELETE FROM ejaFields WHERE ejaModuleId=%d;',v);
       tibulaSqlRun('DELETE FROM ejaPermissions WHERE ejaModuleId=%d;',v);
       tibulaSqlRun('DELETE FROM ejaHelps WHERE ejaModuleId=%d;',v);
       tibulaSqlRun('DELETE FROM ejaTranslations WHERE ejaModuleId=%d;',v);
       tibulaSqlRun('DELETE FROM ejaModuleLinks WHERE dstModuleId=%d;',v);
       tibulaInfo("ejaSqlModuleDeleted");
      end
     end
     tibulaSqlRun('DELETE FROM %s WHERE ejaId=%d AND ejaOwner IN (%s);',tibula['ejaModuleName'],v,tibula['ejaOwnerList']); 
     tibulaSqlRun('DELETE FROM ejaLinks WHERE (dstModuleId=%d AND dstFieldId=%d) OR (srcModuleId=%d AND srcFieldId=%d) AND ejaOwner IN (%s);',tibula['ejaModuleId'],v,tibula['ejaModuleId'],v,tibula['ejaOwnerList']);
     tibulaSqlRun('DELETE FROM ejaFiles WHERE ejaModuleId=%d AND ejaFieldId=%d AND ejaOwner IN (%s);',tibula['ejaModuleId'],v,tibula['ejaOwnerList']);
    end
    tibula['ejaAction']="search";
   end 

   --search engine
   if ejaCheck(tibula['ejaAction'],"searchLink") then tibulaReset(); end
   if ejaCheck(tibula['ejaAction'],"search") or ejaCheck(tibula['ejaAction'],"previous") or ejaCheck(tibula['ejaAction'],"next") or ejaCheck(tibula['ejaAction'],"list") or ejaCheck(tibula['ejaAction'],"searchLink") or ejaCheck(tibula['ejaAction'],"csvExport") or ejaCheck(tibula['ejaAction'],"xmlExport") then
    local sql="";
    local sqlType={};
    tibula['ejaActionType']="List";
    --check ejaSearchStep (how many rows per page) and ejaSearchLimit (row limit begin)
    if not ejaCheck(tibula['ejaSearchStep']) then tibula['ejaSearchStep']=tibulaSqlRun('SELECT searchLimit FROM ejaModules WHERE ejaId=%d;',tibula['ejaModuleId']); end
    if not ejaCheck(tibula['ejaSearchStep']) then tibula['ejaSearchStep']=tibula['ejaDefaultSearchStep']; end
    if ejaCheck(tibula['ejaSearchLimit']) then tibula['ejaSqlLimit']=tibula['ejaSearchLimit']; end
    if not ejaCheck(tibula['ejaSqlLimit']) then tibula['ejaSqlLimit']=0 end
    --previous and next
    if ejaCheck(tibula['ejaAction'],"previous") then tibula['ejaSqlLimit']=tibula['ejaSqlLimit']-tibula['ejaSearchStep']; end
    if ejaCheck(tibula['ejaAction'],"next") then tibula['ejaSqlLimit']=tibula['ejaSqlLimit']+tibula['ejaSearchStep']; end
    --query construction
    if ejaCheck(tibula['ejaSqlQuery64']) then 
     sql=ejaBase64Decode(tibula['ejaSqlQuery64']);
    else
     sql='SELECT ejaId';
     for k,v in pairs(tibulaSqlMatrix("SELECT name,type FROM ejaFields WHERE ejaModuleId=%d AND powerList>0 AND powerList !='' ORDER BY powerList;",tibula['ejaModuleId'])) do
      sql=sql..','..v['name'];
     end
     for k,v in pairs(tibulaSqlMatrix('SELECT name,type FROM ejaFields WHERE ejaModuleId=%d;',tibula['ejaModuleId'])) do   
      sqlType[v['name']]=v['type'];
     end
     sql=sql..ejaSprintf(' FROM %s WHERE ejaOwner IN (%s)',tibula['ejaModuleName'],tibula['ejaOwnerList']);
     if ejaCheck(tibula['ejaValues']) then
      for k,v in pairs (tibula['ejaValues']) do
       if ejaCheck(v) and not string.find(k,"%.") then 
        local sqlAnd="";
        v=string.gsub(v,"*","%%");
        v=string.gsub(v,"%%","%%%%");
        if ejaCheck(sqlType[k],"boolean") or ejaCheck(sqlType[k],"integer") then 
         sqlAnd=ejaSprintf(' AND %s = %d ',k,v); 
        end
        if ejaCheck(sqlType[k],"date") or ejaCheck(sqlType[k],"time") or ejaCheck(sqlType[k],"datetime") then 
         sqlAnd=ejaSprintf(" AND %s='%s' ",k,tibulaDateSet(v,sqlType[k])); 
        end
        if ejaCheck(sqlType[k],"dateRange") or ejaCheck(sqlType[k],"timeRange") or ejaCheck(sqlType[k],"datetimeRange") or ejaCheck(sqlType[k],"integerRange") then
         if ejaCheck(tibula['ejaValues'][k..".begin"]) then sqlAnd=sqlAnd..ejaSprintf(" AND %s > '%s' ",k,tibulaDateSet(tibula['ejaValues'][k..".begin"],"")); end
         if ejaCheck(tibula['ejaValues'][k..".end"]) then sqlAnd=sqlAnd..ejaSprintf(" AND %s < '%s' ",k,tibulaDateSet(tibula['ejaValues'][k..".end"],"")); end
        end
        if not ejaCheck(sqlAnd) then sqlAnd=ejaSprintf(" AND %s LIKE '%s'",k,v); end
        sql=sql..sqlAnd;
       end
      end
     end  
     --if linking restrict search to active links. If srcFieldName is present in ejaModuleLinks use this to restrict search.
     if ejaCheck(tibula['ejaAction'],"searchLink") and not ejaCheck(tibula['ejaModuleName'],"ejaFiles") then
      if ejaCheck(tibula['ejaModuleName'],"ejaFiles") then 
       sql=sql..ejaSprintf(" AND ejaModuleId=%d AND ejaFieldId=%d ",tibula['ejaLinkModuleId'],tibula['ejaLinkFieldId']);
      else
       if ejaCheck(tibula['ejaLinkingField']) then
        sql=sql..ejaSprintf(" AND ejaId IN (SELECT ejaId FROM %s WHERE %s=%d AND ejaOwner IN (%s)) ",tibula['ejaModuleName'],tibula['ejaLinkingField'],tibula['ejaLinkFieldId'],tibula['ejaOwnerList']);
       else
        sql=sql..ejaSprintf(" AND ejaId IN (SELECT srcFieldId FROM ejaLinks WHERE srcModuleId=%d AND dstModuleId=%d AND dstFieldId=%d) ",tibula['ejaModuleId'],tibula['ejaLinkModuleId'],tibula['ejaLinkFieldId']); 
       end
      end
     end
     if ejaCheck(tibula['ejaModuleName'],"ejaFiles") and ejaCheck(tibula['ejaLinking']) then
      sql=sql..ejaSprintf(" AND ejaModuleId=%d AND ejaFieldId=%d ",tibula['ejaLinkModuleId'],tibula['ejaLinkFieldId']);
     end                   
     tibula['ejaSqlQuery64']=ejaBase64Encode(sql);
    end
    --limit and order stuff
    if not ejaCheck(tibula['ejaSqlLimit']) then tibula['ejaSqlLimit']=0; end
    if ejaCheck(tibula['ejaSearchOrder']) then
     tibula['ejaSqlOrder']="";
     for k,v in pairs(tibula['ejaSearchOrder']) do 
      if ejaCheck(v) then tibula['ejaSqlOrder']=tibula['ejaSqlOrder']..", "..k.." "..v; end
     end
     if ejaCheck(tibula['ejaSqlOrder']) then tibula['ejaSqlOrder']=string.sub(tibula['ejaSqlOrder'],2); end
    end 
    if not ejaCheck(tibula['ejaSqlOrder']) then 
     tibula['ejaSqlOrder']=tibulaSqlRun('SELECT sortList FROM ejaModules WHERE ejaId=%d',tibula['ejaModuleId']);
     if not ejaCheck(tibula['ejaSqlOrder']) then tibula['ejaSqlOrder']=tibula['ejaDefaultSearchOrder']; end
    end
    --finish query construction
    tibula['ejaSqlQueryRaw']=sql;
    tibula['ejaSqlQuery']=ejaSprintf('%s ORDER BY %s LIMIT %d,%d;',sql,tibula['ejaSqlOrder'],tibula['ejaSqlLimit'],tibula['ejaSearchStep']);
    tibula['ejaId']=0;
   end

   if ejaCheck(tibula['ejaAction'],"download") then
    local file={}
    if ejaCheck(tibula['ejaId']) then file=tibulaSqlArray('SELECT * FROM ejaFiles WHERE ejaOwner IN (%s) AND ejaId=%d',tibula['ejaOwnerList'],tibula['ejaId']); end
    if ejaCheck(tibula['ejaValues']['ejaFile']) then file=tibulaSqlArray("SELECT * FROM ejaFiles WHERE ejaOwner IN (%s) AND fileName='%s' AND filePath='%s' LIMIT 1",tibula['ejaOwnerList'],tibula['ejaValues']['ejaFile'],tibula['ejaValues']['ejaPath']); end
    if (file) then
     tibula['ejaFileName']=file['fileName'];
     tibula['ejaFileData']=ejaBase64Decode(file['fileData']);
    end
    tibula['ejaActionType']="Download" 
   end

  end 
 end 


 --Define ejaActionType and populate fields/result matrix
 if ejaCheck(tibula['ejaActionType'],"List") then 
  tibula['ejaSearchList']=tibulaSqlSearchMatrix(tibula['ejaSqlQuery'],tibula['ejaModuleId']); 
 else
  if not ejaCheck(tibula['ejaActionType'],"Download") then
   if ejaCheck(tibula['ejaId']) then tibula['ejaActionType']="Edit" else tibula['ejaActionType']="Search" end
   tibula['ejaFields']=tibulaSqlFieldsMatrix(tibula['ejaModuleId'], tibula['ejaActionType']);
  end
 end
  
 -- lua module script last call.
 tibulaModuleLua(1,web);
end


function tibulaTableExport()
 local data=""
  
 --Print page
 if ejaCheck(tibula['ejaOut'],"xhtml") then data=tibulaXhtmlExport(tibula['ejaModuleId']); end
 if ejaCheck(tibula['ejaOut'],"json") then data=tibulaJsonExport(tibula['ejaModuleId']); end

 return data;
end 

function tibulaTableStop()
 if not ejaCheck(tibula['ejaOutSession'],1) then
  tibulaSessionWrite(tibula['ejaOwner'],{});
 else
  --Update ejaSession
  local ejaBkp={}
  ejaBkp['ejaSqlQuery64']=tibula['ejaSqlQuery64'];
  ejaBkp['ejaLinkHistory']=tibula['ejaLinkHistory'];
  ejaBkp['ejaLinkHistoryOrder']=tibula['ejaLinkHistoryOrder'];
  ejaBkp['ejaSqlLimit']=tibula['ejaSqlLimit'];
  ejaBkp['ejaSqlOrder']=tibula['ejaSqlOrder']; 
  tibulaSessionWrite(tibula['ejaOwner'],ejaBkp);
  ejaBkp="";
 end
 tibula={}
end


