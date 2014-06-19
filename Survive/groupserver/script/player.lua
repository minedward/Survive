local Que = require "queue"
local Cjson = require "cjson"
local Dbmgr = require "dbmgr"

local attr = {
	attr,
}

local function attr:new(o)
  o = o or {}   
  setmetatable(o, self)
  self.__index = self
  return o
end

local function attr:init(attr)
	self.attr = {}	
	for k,v in pairs(attr) do
		self.attr[k] = {v=v,dirty=false}
	end	
end

local function attr:pack(wpk)
	wpk_write_uint16(#self.attr)
	for k,v in pairs(self.attr) do
		wpk_write_uint16(k)
		wpk_write_uint32(v.v)
	end		
end

local function attr:updata2client(ply)
	local tmp
	local c
	for k,v in pairs(self.attr) do
		if v.dirty then
			c = c + 1
			tmp[k] = v.v
			v.dirty = false
		end
	end		
	if c > 0 then
		local wpk = new_wpk()
		wpk_write_uint16(wpk,CMD_GC_UPDATEATTR)	
		wpk_write_uint16(#tmp)
		for k,v in pairs(tmp) do
			wpk_write_uint16(k)
			wpk_write_uint32(v)
		end
		ply:send2gate(wpk)			
	end	
end

local function attr::save2db(ply)
	
end

local function attr:get(idx)
	return self.attr[idx]
end

local function attr:set(idx,v)
	local attr = self.attr[idx]
	if attr and attr.v ~= v then
		attr.dirty = true
		attr.v = v
	end
end


local skillmgr = {
	skills,
}

local function skillmgr:new(o)
  o = o or {}   
  setmetatable(o, self)
  self.__index = self
  return o
end

local function skillmgr:init(skills)
	
end

local function skillmgr:pack(wpk)

end

local function skillmgr::save2db(ply)
	
end

local bag = {
	bag,
}

local function bag:new(o)
  o = o or {}   
  setmetatable(o, self)
  self.__index = self
  return o
end

local function bag:init(bag)
	
end

local function bag:pack(wpk)

end

local function bag::save2db(ply)
	
end


local player = {
	groupid,    --��group�������е�player��������
	gate,       --����gateserver����������
	game,       --����gameserver����������(�����)
	actname,    --�ʺ���
	chaname,    --��ɫ��
	attr,       --��ɫ����
	skill,      --��ɫ����
	bag,        --��ɫ����
}

local function player:new(o)
  o = o or {}   
  setmetatable(o, self)
  self.__index = self
  self.groupid = 0
  self.game = nil
  self.gate = nil
  self.actname = nil
  self.chaname = nil
  self.attr = attr:new()
  self.skill = skillmgr:new()
  self.bag = bag:new()
  return o
end

local function player:pack(wpk)
	self.attr:pack(wpk)
	self.skill:pack(wpk)
	self.bag:pack(wpk)
end

local function player:send2gate(wpk)
	wpk_write_uint32(wpk,self.gate.id.high)
	wpk_write_uint32(wpk,self.gate.low)
	wpk_write_uint32(1)
	C.send(ply.gate.conn,wpk)	
end


local function initfreeidx()
	local que = Que.Queue()
	for i=1,65536 do
		que:push({v=i,__next=nil})
	end
	return que
end 

--player��������
local playermgr = {
	freeidx = initfreeidx(),
	players = {},
	actname2player ={},
}

local function playermgr:new_player(actname)
	if not actname or actname = '' then
		return nil
	end
	if self.freeidx:is_empty() then
		return nil
	else
		local newply = player:new()
		newply.actname = actname
		newply.groupid = self.freeidx:pop().v
		self.players[newply.groupid] = newply
		self.actname2player[actname] = newply
		return newply
	end
end

local function playermgr:release_player(ply)
	if ply.groupid and ply.groupid >= 1 and ply.groupid <= 65536 then
		self.freeidx:push({v=ply.groupid,__next=nil})
		self.players[ply.groupid] = nil
		self.actname2player[ply.actname] = nil
		ply.groupid = nil
	end
end

local function playermgr:getplybyid(groupid)
	return self.players[groupid]
end

local function playermgr:getplybyactname(actname)
	if not actname or actname = '' then
		return nil
	end
	return self.actname2player[actname]
end


function load_chainfo_callback(self,error,result)
	local ply = self.ply	
	ply.attr =  Cjson.decode(result[1])
	ply.skill = Cjson.decode(result[2])
	local wpk = new_wpk()
	local gateid = ply.gate.id
	wpk_write_uint16(wpk,CMD_GC_BEGINPLY)
	ply:pack(wpk)
	ply:send2gate(wpk)
end


local function AG_PLYLOGIN(rpk,conn)
	local actname = rpk_read_string(rpk)
	local chaname = rpk_read_string(rpk)
	local gateid = {}
	gateid.high = rpk_read_uint32(rpk)
	gateid.low = rpk_read_uint32(rpk)
	
	local ply = playermgr:getplybyactname(actname)
	if ply then
		if ply.gate then
			--���������Ϸ��,��ֹ��һ����½����
			local wpk = new_wpk()
			wpk_write_uint16(wpk,CMD_GA_PLY_INVAILD)
			wpk_write_uint32(wpk,gateid.high)
			wpk_write_uint32(wpk,gateid.low)
			C.send(conn,wpk)	
		else
			--���û�����߻�����Ϸ��,����������������������ӣ����������߼�
		return
	end
	
	ply = playermgr:new_player(actname)
	if not ply then
		--֪ͨgate��æ������gate�Ͽ��ͻ�������
		local wpk = new_wpk()
		wpk_write_uint16(wpk,CMD_GA_BUSY)
		wpk_write_uint32(wpk,gateid.high)
		wpk_write_uint32(wpk,gateid.low)
		C.send(conn,wpk)
	else
		ply.gate = {id=gateid,conn = conn}
		if chaname == "" then
			--֪ͨ�ͻ��˴����û�
			local wpk = new_wpk()
			wpk_write_uint16(wpk,CMD_GC_CREATE)
			ply:send2gate(wpk)
		else
			ply.chaname = chaname
			--�����ݿ������ɫ����
			local cmd = "hmget" .. chaname .. " attr skill bag"
			local err = Dbmgr.DBCmd(chaname,cmd,{callback = load_chainfo_callback,ply=ply})
			if err then
				local wpk = new_wpk()
				wpk_write_uint16(wpk,CMD_GA_BUSY)
				ply:send2gate(wpk)
			end
		end
	end
end

local function CG_CREATE(rpk,conn)
	local chaname = rpk_read_string(rpk)
	local groupid = rpk_read_uint32(rpk)
	local gateid = {}
	gateid.high = rpk_read_uint32(rpk)
	gateid.low = rpk_read_uint32(rpk)	
	local ply = playermgr:getplybyid(groupid)
	if not ply then
		local wpk = new_wpk()
		wpk_write_uint16(wpk,CMD_GA_BUSY)
		wpk_write_uint32(wpk,gateid.high)
		wpk_write_uint32(wpk,gateid.low)
		C.send(conn,wpk)		
	else
	
		--ִ�д�������
		--local wpk = new_wpk()
		--wpk_write_uint16(wpk,CMD_GC_BEGINPLY)
		--wpk_write_uint32(wpk,gateid.high)
		--wpk_write_uint32(wpk,gateid.low)
		--C.send(conn,wpk)
	end
end


local function reg_cmd_handler()
	GroupApp.reg_cmd_handler(CMD_AG_PLYLOGIN,{handle=AG_PLYLOGIN})
	GroupApp.reg_cmd_handler(CMD_CG_CREATE,{handle=CG_CREATE})
end

return {
	RegHandler = reg_cmd_handler,
}